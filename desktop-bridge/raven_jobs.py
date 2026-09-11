from __future__ import annotations

"""RAH Raven queued Job Executor v1.0.

Adds a small asynchronous queue on top of the existing Agent Runner allowlist.
It deliberately does NOT accept shell strings, arbitrary commands, arbitrary
paths, or capability arguments. Every submitted job must reference an existing
Agent Runner capability and include confirm=true.

On Windows the executor requires an elevated Administrator process by default.
The canonical launcher self-elevates before starting the Python bridge, so the
agent and its fixed child processes inherit that elevated token.
"""

import ctypes
import json
import os
import pathlib
import queue
import secrets
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from typing import Any

from flask import jsonify, request

import agent_runner
from server_v17 import app

JOB_EXECUTOR_VERSION = "1.0.0"
MAX_JOBS_IN_MEMORY = 100
MAX_AUDIT_TEXT_CHARS = 4000
REQUIRE_ADMIN = os.getenv("RAH_JOB_REQUIRE_ADMIN", "1").strip() not in {"0", "false", "False"}


def _default_job_dir() -> pathlib.Path:
    configured = os.getenv("RAH_JOB_DIR", "").strip()
    if configured:
        return pathlib.Path(configured).expanduser()
    if os.name == "nt":
        return pathlib.Path(r"C:\RAH\AgentJobs")
    return pathlib.Path.home() / ".rah-raven" / "jobs"


JOB_DIR = _default_job_dir()
AUDIT_FILE = JOB_DIR / "jobs.jsonl"
_JOB_LOCK = threading.RLock()
_JOB_QUEUE: queue.Queue[str] = queue.Queue(maxsize=MAX_JOBS_IN_MEMORY)
_JOBS: dict[str, dict[str, Any]] = {}
_JOB_ORDER: list[str] = []


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _is_admin() -> bool:
    if os.name != "nt":
        try:
            return os.geteuid() == 0
        except AttributeError:
            return False
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def _executor_status() -> dict[str, Any]:
    admin = _is_admin()
    return {
        "version": JOB_EXECUTOR_VERSION,
        "platform": sys.platform,
        "pid": os.getpid(),
        "elevated": admin,
        "requires_admin": bool(REQUIRE_ADMIN and os.name == "nt"),
        "ready": not (REQUIRE_ADMIN and os.name == "nt" and not admin),
        "queue_depth": _JOB_QUEUE.qsize(),
        "job_dir": str(JOB_DIR),
        "mode": "queued-read-only-allowlist",
        "arbitrary_commands": False,
        "arbitrary_paths": False,
        "arguments_allowed": False,
    }


def _audit(event: str, job: dict[str, Any], **extra: Any) -> None:
    """Append bounded, non-secret operational metadata to a JSONL audit file."""
    try:
        JOB_DIR.mkdir(parents=True, exist_ok=True)
        result = job.get("result") if isinstance(job.get("result"), dict) else {}
        record = {
            "timestamp": _utc_now(),
            "event": event,
            "job_id": job.get("id"),
            "capability": job.get("capability"),
            "status": job.get("status"),
            "ok": result.get("ok") if result else None,
            "exit_code": result.get("exit_code") if result else None,
            "duration_ms": result.get("duration_ms") if result else None,
            "stdout_preview": str(result.get("stdout") or "")[:MAX_AUDIT_TEXT_CHARS] if result else "",
            "stderr_preview": str(result.get("stderr") or "")[:MAX_AUDIT_TEXT_CHARS] if result else "",
            **extra,
        }
        with AUDIT_FILE.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
    except OSError:
        # Audit failure must be visible in executor health but must not execute a
        # different action or fall back to an unsafe location.
        pass


def _execute_capability(capability: agent_runner.Capability) -> dict[str, Any]:
    started_at = time.time()
    if capability.id == "system-inventory":
        result = agent_runner._system_inventory()
    elif capability.id == "hovedpc-local-status":
        result = agent_runner._hovedpc_local_status()
    elif capability.id == "rah-file-index":
        result = agent_runner._rah_file_index()
    elif capability.id == "project-files":
        files = agent_runner._project_files()
        result = {
            "ok": True,
            "files": files,
            "count": len(files),
            "stdout": "\n".join(files),
            "stderr": "",
            "duration_ms": round((time.time() - started_at) * 1000),
            "command": None,
            "cwd": str(agent_runner.PROJECT_ROOT),
        }
    else:
        result = agent_runner._run_command(capability)

    return {
        **result,
        "capability": agent_runner._capability_dict(capability),
        "read_only": True,
        "files_modified": False,
        "tools_executed": [capability.id],
        "execution_mode": "queued-after-explicit-confirm",
        "arbitrary_commands": False,
    }


def _trim_jobs_locked() -> None:
    while len(_JOB_ORDER) > MAX_JOBS_IN_MEMORY:
        candidate = _JOB_ORDER[0]
        job = _JOBS.get(candidate)
        if job and job.get("status") in {"queued", "running"}:
            break
        _JOB_ORDER.pop(0)
        _JOBS.pop(candidate, None)


def _worker() -> None:
    while True:
        job_id = _JOB_QUEUE.get()
        try:
            with _JOB_LOCK:
                job = _JOBS.get(job_id)
                if not job:
                    continue
                job["status"] = "running"
                job["started_at"] = _utc_now()
                _audit("running", job)
                capability_id = str(job["capability"])

            capability = agent_runner.CAPABILITIES.get(capability_id)
            if capability is None:
                raise RuntimeError("Capability disappeared from the fixed allowlist.")

            result = _execute_capability(capability)
            with _JOB_LOCK:
                job = _JOBS[job_id]
                job["result"] = result
                job["status"] = "succeeded" if result.get("ok") else "failed"
                job["finished_at"] = _utc_now()
                _audit("finished", job)
        except subprocess.TimeoutExpired as exc:
            with _JOB_LOCK:
                job = _JOBS.get(job_id)
                if job:
                    job["status"] = "failed"
                    job["finished_at"] = _utc_now()
                    job["result"] = {
                        "ok": False,
                        "error": f"Kjøringen passerte tidsgrensen på {exc.timeout} sekunder.",
                        "read_only": True,
                        "files_modified": False,
                        "arbitrary_commands": False,
                    }
                    _audit("timeout", job)
        except Exception as exc:
            with _JOB_LOCK:
                job = _JOBS.get(job_id)
                if job:
                    job["status"] = "failed"
                    job["finished_at"] = _utc_now()
                    job["result"] = {
                        "ok": False,
                        "error": str(exc)[:1000],
                        "read_only": True,
                        "files_modified": False,
                        "arbitrary_commands": False,
                    }
                    _audit("error", job)
        finally:
            _JOB_QUEUE.task_done()


_WORKER_THREAD = threading.Thread(target=_worker, name="rah-raven-job-worker", daemon=True)
_WORKER_THREAD.start()


@app.get("/agent/jobs/health")
def agent_jobs_health():
    status = _executor_status()
    status["ok"] = status["ready"]
    status["audit_file"] = str(AUDIT_FILE)
    return jsonify(status), (200 if status["ready"] else 503)


@app.get("/agent/jobs")
def agent_jobs_list():
    try:
        limit = max(1, min(50, int(request.args.get("limit", "20"))))
    except ValueError:
        return jsonify({"ok": False, "error": "limit må være et heltall."}), 400

    with _JOB_LOCK:
        ids = list(reversed(_JOB_ORDER[-limit:]))
        jobs = [dict(_JOBS[item]) for item in ids if item in _JOBS]
    return jsonify({
        "ok": True,
        "jobs": jobs,
        "count": len(jobs),
        "executor": _executor_status(),
    })


@app.get("/agent/jobs/<job_id>")
def agent_job_get(job_id: str):
    with _JOB_LOCK:
        job = _JOBS.get(job_id)
        if not job:
            return jsonify({"ok": False, "error": "Jobben finnes ikke i aktiv historikk."}), 404
        return jsonify({"ok": True, "job": dict(job), "executor": _executor_status()})


@app.post("/agent/jobs")
def agent_job_submit():
    status = _executor_status()
    if not status["ready"]:
        return jsonify({
            "ok": False,
            "error": "Raven Job Executor kjører ikke elevated. Start RAH-launcheren med Administrator/UAC.",
            "executor": status,
        }), 503

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "Forespørselen må være et JSON-objekt."}), 400

    allowed_keys = {"capability", "confirm", "client_request_id"}
    unexpected = sorted(set(payload) - allowed_keys)
    if unexpected:
        return jsonify({
            "ok": False,
            "error": "Job Executor v1 godtar ikke ekstra parametre eller kommandoargumenter.",
            "unexpected": unexpected,
            "arguments_allowed": False,
        }), 400

    if payload.get("confirm") is not True:
        return jsonify({"ok": False, "error": "Eksplisitt confirm=true kreves for hver jobb."}), 400

    capability_id = str(payload.get("capability") or "").strip()
    capability = agent_runner.CAPABILITIES.get(capability_id)
    if capability is None:
        return jsonify({
            "ok": False,
            "error": "Capability er ikke i Raven sin faste allowlist.",
            "arbitrary_commands": False,
        }), 403

    client_request_id = str(payload.get("client_request_id") or "").strip()[:80]
    job_id = secrets.token_hex(12)
    job = {
        "id": job_id,
        "capability": capability_id,
        "title": capability.title,
        "status": "queued",
        "created_at": _utc_now(),
        "started_at": None,
        "finished_at": None,
        "client_request_id": client_request_id or None,
        "result": None,
        "read_only": True,
        "confirmed": True,
    }

    with _JOB_LOCK:
        if _JOB_QUEUE.full():
            return jsonify({"ok": False, "error": "Raven jobbkø er full. Prøv igjen etter at en jobb er ferdig."}), 429
        _JOBS[job_id] = job
        _JOB_ORDER.append(job_id)
        _trim_jobs_locked()
        _audit("queued", job)
        _JOB_QUEUE.put_nowait(job_id)

    return jsonify({
        "ok": True,
        "accepted": True,
        "job": job,
        "executor": status,
        "poll": f"/agent/jobs/{job_id}",
        "arbitrary_commands": False,
        "arguments_allowed": False,
    }), 202


# Extend the existing canonical health endpoint without replacing Bridge logic.
_current_health = app.view_functions.get("health")
if _current_health and not getattr(_current_health, "_rah_jobs_wrapped", False):
    def health_with_job_executor():
        response = _current_health()
        data = response.get_json() if hasattr(response, "get_json") else {}
        executor = _executor_status()
        data.update({
            "job_executor": True,
            "job_executor_version": JOB_EXECUTOR_VERSION,
            "job_executor_ready": executor["ready"],
            "job_executor_elevated": executor["elevated"],
            "job_executor_mode": executor["mode"],
        })
        return jsonify(data)

    health_with_job_executor._rah_jobs_wrapped = True
    app.view_functions["health"] = health_with_job_executor

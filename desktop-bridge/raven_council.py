from __future__ import annotations

"""RAH Raven Council v1.0.

Autonomous local-AI coordination on top of Raven AI Fabric.

Goals:
- keep LM Studio local-only and start it automatically when available,
- load an already-downloaded local LLM when the server has no model,
- prefer AnythingLLM for project/document knowledge when authenticated,
- keep machine actions behind Raven's audited capability allowlist,
- expose a small status/ask surface for Raven UI and local agents.

The Council deliberately does NOT download large models automatically and does
NOT scrape AnythingLLM or other application credentials from disk.
"""

import json
import os
import pathlib
import shutil
import subprocess
import threading
import time
from dataclasses import dataclass
from typing import Any

from flask import jsonify, request

from server_v17 import app
import raven_ai_fabric

COUNCIL_VERSION = "1.0.0"
STATE_DIR = pathlib.Path(os.getenv("RAH_COUNCIL_STATE_DIR", r"C:\RAH\Council") if os.name == "nt" else "~/.rah-council").expanduser()
STATE_FILE = STATE_DIR / "status.json"
LOCK = threading.Lock()


def _lms_path() -> str | None:
    found = shutil.which("lms") or shutil.which("lms.exe")
    if found:
        return found
    if os.name != "nt":
        return None
    candidates = [
        pathlib.Path(os.getenv("USERPROFILE", "")) / ".lmstudio" / "bin" / "lms.exe",
        pathlib.Path(os.getenv("LOCALAPPDATA", "")) / "LM Studio" / "bin" / "lms.exe",
        pathlib.Path(os.getenv("LOCALAPPDATA", "")) / "Programs" / "LM Studio" / "resources" / "app" / ".webpack" / "lms.exe",
    ]
    for path in candidates:
        if path.is_file():
            return str(path)
    return None


def _run(args: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        shell=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        check=False,
    )


def _json_cli(args: list[str], timeout: int = 20) -> Any:
    completed = _run(args, timeout=timeout)
    if completed.returncode != 0:
        raise RuntimeError((completed.stderr or completed.stdout or "CLI failed")[:500])
    raw = (completed.stdout or "").strip()
    return json.loads(raw) if raw else None


def _model_key(item: dict[str, Any]) -> str:
    for key in ("modelKey", "model_key", "key", "id", "path"):
        value = item.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def _is_llm(item: dict[str, Any]) -> bool:
    kind = str(item.get("type") or item.get("kind") or "").lower()
    return kind in {"", "llm", "language-model", "language_model"}


def _choose_local_model(models: list[dict[str, Any]]) -> str:
    preferred = (os.getenv("RAH_LMSTUDIO_MODEL") or "").strip()
    if preferred:
        return preferred

    llms = [item for item in models if isinstance(item, dict) and _is_llm(item) and _model_key(item)]
    if not llms:
        return ""

    # Prefer instruct/chat/tool-use style models; otherwise the first downloaded LLM.
    def score(item: dict[str, Any]) -> tuple[int, int]:
        hay = " ".join(str(item.get(k) or "") for k in ("modelKey", "displayName", "path", "architecture")).lower()
        bonus = 0
        for term, points in (("instruct", 6), ("chat", 5), ("qwen", 4), ("gemma", 4), ("llama", 3), ("mistral", 3), ("gpt-oss", 5)):
            if term in hay:
                bonus += points
        if item.get("trainedForToolUse") is True:
            bonus += 8
        size = int(item.get("sizeBytes") or 0)
        return bonus, -size

    chosen = max(llms, key=score)
    return _model_key(chosen)


def ensure_lmstudio() -> dict[str, Any]:
    """Start local LM server and load one already-downloaded model if needed."""
    with LOCK:
        status = raven_ai_fabric._lm_status(start_if_needed=False)
        if status.ready:
            return {"ok": True, "state": "ready", "model": status.model, "detail": status.detail}

        lms = _lms_path()
        if not lms:
            return {"ok": False, "state": "cli-missing", "model": "", "detail": "LM Studio/lms CLI not found"}

        # Server stays on loopback. Do not enable CORS or wildcard binding.
        _run([lms, "server", "start", "--port", "1234", "--bind", "127.0.0.1"], timeout=25)

        # Give the local server a short moment to become responsive.
        for _ in range(12):
            time.sleep(0.5)
            status = raven_ai_fabric._lm_status(start_if_needed=False)
            if status.ready:
                return {"ok": True, "state": "ready", "model": status.model, "detail": status.detail}
            if status.online:
                break

        try:
            models_raw = _json_cli([lms, "ls", "--llm", "--json"], timeout=20)
            models = models_raw if isinstance(models_raw, list) else []
        except Exception as exc:
            return {"ok": False, "state": "list-failed", "model": "", "detail": str(exc)[:300]}

        chosen = _choose_local_model(models)
        if not chosen:
            return {
                "ok": False,
                "state": "no-local-model",
                "model": "",
                "detail": "LM Studio is available but no downloaded LLM was found; Council will not auto-download a large model.",
            }

        loaded = _run([lms, "load", chosen, "--identifier", "rah-default"], timeout=180)
        if loaded.returncode != 0:
            return {
                "ok": False,
                "state": "load-failed",
                "model": chosen,
                "detail": (loaded.stderr or loaded.stdout or "model load failed")[:500],
            }

        for _ in range(30):
            time.sleep(0.5)
            status = raven_ai_fabric._lm_status(start_if_needed=False)
            if status.ready:
                return {"ok": True, "state": "ready", "model": status.model or "rah-default", "detail": "auto-loaded local model"}

        return {"ok": False, "state": "load-timeout", "model": chosen, "detail": "model load did not become API-ready in time"}


def council_status(start: bool = False) -> dict[str, Any]:
    lm = ensure_lmstudio() if start else raven_ai_fabric._lm_status(start_if_needed=False).as_dict()
    providers = [p.as_dict() for p in raven_ai_fabric.provider_statuses(start_if_needed=start)]
    anything = next((p for p in providers if p.get("id") == "anythingllm"), {})
    raven = next((p for p in providers if p.get("id") == "raven"), {})

    result = {
        "ok": True,
        "version": COUNCIL_VERSION,
        "mode": "local-first-multi-provider",
        "lmstudio": lm,
        "anythingllm": anything,
        "raven": raven,
        "automatic_model_download": False,
        "credential_scraping": False,
        "arbitrary_shell": False,
        "routing": {
            "project_knowledge": "anythingllm when authenticated, otherwise lmstudio",
            "general_reasoning": "lmstudio, then anythingllm, then configured compatible provider",
            "machine_actions": "raven audited allowlist only",
        },
    }
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass
    return result


def _payload() -> dict[str, Any]:
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


@app.get("/ai/council/status")
def api_council_status():
    return jsonify(council_status(start=True))


@app.post("/ai/council/ask")
def api_council_ask():
    data = _payload()
    message = data.get("message")
    if not isinstance(message, str) or not message.strip():
        return jsonify({"ok": False, "error": "message must be a non-empty string"}), 400

    ensure_lmstudio()
    try:
        answer = raven_ai_fabric._auto_chat(
            message.strip(),
            str(data.get("system") or ""),
            str(data.get("workspace") or ""),
            str(data.get("model") or ""),
        )
        return jsonify({"ok": True, "council": COUNCIL_VERSION, "answer": answer})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)[:1000]}), 503


@app.post("/ai/council/plan")
def api_council_plan():
    data = _payload()
    task = data.get("task")
    if not isinstance(task, str) or not task.strip():
        return jsonify({"ok": False, "error": "task must be a non-empty string"}), 400

    providers = [p.as_dict() for p in raven_ai_fabric.provider_statuses(start_if_needed=True)]
    lower = task.lower()
    knowledge = any(term in lower for term in ("project", "prosjekt", "repo", "document", "dokument", "memory", "minne", "tidligere"))
    machine = any(term in lower for term in ("pc", "windows", "system", "inventory", "status", "test", "file", "fil"))

    route: list[dict[str, str]] = []
    if knowledge:
        route.append({"role": "project-memory", "provider": "anythingllm", "fallback": "lmstudio"})
    else:
        route.append({"role": "reasoning", "provider": "lmstudio", "fallback": "anythingllm/openai-compatible"})
    if machine:
        route.append({"role": "machine-action", "provider": "raven", "fallback": "none; audited allowlist only"})

    return jsonify({
        "ok": True,
        "task": task.strip(),
        "route": route,
        "providers": providers,
        "automatic_execution": "only fixed Raven capabilities; no arbitrary shell",
    })

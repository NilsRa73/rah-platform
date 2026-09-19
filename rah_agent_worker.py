#!/usr/bin/env python3
"""RAH Agent Worker v1.

Claims structured jobs from RAH Agent Bridge and routes them only to:
- Raven fixed audited capabilities
- RAH AI Fabric chat providers (AnythingLLM / LM Studio / configured cloud provider)

No shell execution, subprocesses, arbitrary filesystem operations, or public network binding.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import socket
import time
import urllib.error
import urllib.request
from typing import Any

VERSION = "1.0.0"
SCHEMA = "rah-agent-worker"
DEFAULT_BRIDGE = "http://127.0.0.1:18781"
DEFAULT_FABRIC = "http://127.0.0.1:18765"

ALLOWED_KINDS = {
    "system.inventory",
    "code.review",
    "project.review",
    "text.task",
    "test.request",
    "agent.message",
}

RAVEN_CAPABILITY_MAP = {
    "system.inventory": "system-inventory",
}

ALLOWED_TEST_CAPABILITIES = {
    "test-council",
    "test-vision-core",
    "test-core-demo",
    "test-mission-engine",
    "test-bridge-security",
    "git-status",
    "project-files",
    "rah-file-index",
    "hovedpc-local-status",
}


def _json_request(
    url: str,
    *,
    method: str = "GET",
    body: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
    timeout: float = 15.0,
) -> tuple[int, Any]:
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
    merged = {"Accept": "application/json"}
    if body is not None:
        merged["Content-Type"] = "application/json"
    if headers:
        merged.update(headers)
    req = urllib.request.Request(url, data=data, headers=merged, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read().decode("utf-8", errors="replace")
            payload = json.loads(raw) if raw.strip() else {}
            return int(response.status), payload
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw) if raw.strip() else {}
        except json.JSONDecodeError:
            payload = {"error": raw[:1000]}
        return int(exc.code), payload


def _load_token(path: Path) -> str:
    value = path.read_text(encoding="utf-8").strip()
    if len(value) < 24:
        raise RuntimeError("Agent Bridge token is missing or invalid.")
    return value


def _bridge_post(base: str, token: str, path: str, body: dict[str, Any], timeout: float = 15.0) -> Any:
    status, payload = _json_request(
        base.rstrip("/") + path,
        method="POST",
        headers={"Authorization": f"Bearer {token}"},
        body=body,
        timeout=timeout,
    )
    if status not in {200, 201, 202}:
        raise RuntimeError(f"Agent Bridge HTTP {status}: {str(payload)[:700]}")
    return payload


def _claim(base: str, token: str, worker_id: str) -> dict[str, Any] | None:
    payload = _bridge_post(base, token, "/v1/jobs/claim", {"worker": worker_id})
    job = payload.get("job") if isinstance(payload, dict) else None
    return job if isinstance(job, dict) else None


def _complete(base: str, token: str, job_id: str, worker_id: str, result: Any) -> None:
    _bridge_post(
        base,
        token,
        f"/v1/jobs/{job_id}/complete",
        {"worker": worker_id, "result": result},
    )


def _fail(base: str, token: str, job_id: str, worker_id: str, message: str, detail: Any = None) -> None:
    payload: dict[str, Any] = {"message": str(message)[:1200]}
    if detail is not None:
        payload["detail"] = detail
    _bridge_post(
        base,
        token,
        f"/v1/jobs/{job_id}/fail",
        {"worker": worker_id, "error": payload},
    )


def _poll_raven_job(fabric_base: str, job_id: str, timeout_seconds: int = 90) -> dict[str, Any]:
    end = time.time() + max(5, min(timeout_seconds, 300))
    while time.time() < end:
        status, payload = _json_request(
            fabric_base.rstrip("/") + f"/agent/jobs/{job_id}",
            timeout=5.0,
        )
        if status == 200 and isinstance(payload, dict):
            job = payload.get("job") or {}
            state = str(job.get("status") or "")
            if state in {"completed", "failed", "timeout"}:
                return payload
        time.sleep(0.5)
    raise RuntimeError("Raven job timed out while waiting for completion.")


def _run_raven_capability(fabric_base: str, capability: str, client_request_id: str) -> dict[str, Any]:
    if capability not in (set(RAVEN_CAPABILITY_MAP.values()) | ALLOWED_TEST_CAPABILITIES):
        raise RuntimeError("Capability is not allowed by RAH Agent Worker v1.")
    status, payload = _json_request(
        fabric_base.rstrip("/") + "/agent/jobs",
        method="POST",
        body={
            "capability": capability,
            "confirm": True,
            "client_request_id": client_request_id[:80],
        },
        timeout=8.0,
    )
    if status != 202 or not isinstance(payload, dict) or not payload.get("accepted"):
        raise RuntimeError(f"Raven rejected capability (HTTP {status}): {str(payload)[:700]}")
    job = payload.get("job") or {}
    raven_job_id = str(job.get("id") or "")
    if not raven_job_id:
        raise RuntimeError("Raven accepted job without an id.")
    completed = _poll_raven_job(fabric_base, raven_job_id)
    final_job = completed.get("job") or {}
    if str(final_job.get("status") or "") != "completed":
        raise RuntimeError(f"Raven capability failed: {str(final_job.get('result'))[:900]}")
    return {
        "route": "raven",
        "capability": capability,
        "ravenJobId": raven_job_id,
        "result": final_job.get("result"),
        "readOnly": bool(final_job.get("read_only", True)),
    }


def _payload_text(kind: str, payload: Any) -> tuple[str, str, str]:
    if not isinstance(payload, dict):
        payload = {"value": payload}

    direct = payload.get("message") or payload.get("text") or payload.get("prompt")
    if direct is None:
        direct = json.dumps(payload, ensure_ascii=False, indent=2)
    message = str(direct).strip()
    if not message:
        raise RuntimeError("AI job payload contains no message/text/prompt.")

    workspace = str(payload.get("workspace") or "").strip()[:120]
    provider = str(payload.get("provider") or "").strip().lower()

    if provider and provider not in {"auto", "anythingllm", "lmstudio"}:
        raise RuntimeError("Requested provider is not allowed by Agent Worker.")

    if not provider:
        if kind == "project.review":
            provider = "anythingllm"
        else:
            provider = "auto"

    system_map = {
        "code.review": (
            "Review the provided code or code-change description. Focus on correctness, "
            "safety, regressions, tests, and the smallest concrete fix. Do not invent unseen files."
        ),
        "project.review": (
            "Review this RAH project request using the available project knowledge. "
            "Preserve stated requirements, identify concrete blockers, and propose focused next actions."
        ),
        "text.task": "Complete the requested text or reasoning task concisely and accurately.",
        "agent.message": (
            "You are one RAH agent collaborating with Raven and other local agents. "
            "Respond with a concrete result suitable for another agent to consume."
        ),
    }
    return message, provider, workspace, system_map.get(kind, "")


def _ai_chat(fabric_base: str, kind: str, payload: Any) -> dict[str, Any]:
    message, provider, workspace, system = _payload_text(kind, payload)
    body = {
        "message": message,
        "provider": provider,
        "system": system,
    }
    if workspace:
        body["workspace"] = workspace
    status, response = _json_request(
        fabric_base.rstrip("/") + "/ai/chat",
        method="POST",
        body=body,
        timeout=120.0,
    )

    # Project review explicitly prefers AnythingLLM, but falls back to auto if the
    # local AnythingLLM API is online without a configured Developer API token.
    if status != 200 and provider == "anythingllm":
        body["provider"] = "auto"
        status, response = _json_request(
            fabric_base.rstrip("/") + "/ai/chat",
            method="POST",
            body=body,
            timeout=120.0,
        )

    if status != 200 or not isinstance(response, dict) or not response.get("ok"):
        raise RuntimeError(f"AI Fabric chat failed (HTTP {status}): {str(response)[:900]}")
    return {
        "route": "ai-fabric",
        "provider": response.get("provider"),
        "model": response.get("model"),
        "workspace": response.get("workspace"),
        "text": response.get("text", ""),
    }


def _handle_job(fabric_base: str, job: dict[str, Any]) -> dict[str, Any]:
    kind = str(job.get("kind") or "")
    if kind not in ALLOWED_KINDS:
        raise RuntimeError("Job kind is not allowed by Agent Worker.")
    job_id = str(job.get("id") or "")
    payload = job.get("payload")

    if kind in RAVEN_CAPABILITY_MAP:
        return _run_raven_capability(fabric_base, RAVEN_CAPABILITY_MAP[kind], job_id)

    if kind == "test.request":
        if not isinstance(payload, dict):
            raise RuntimeError("test.request payload must be an object.")
        capability = str(payload.get("capability") or "").strip()
        if capability not in ALLOWED_TEST_CAPABILITIES:
            raise RuntimeError("Requested test capability is not in the fixed allowlist.")
        return _run_raven_capability(fabric_base, capability, job_id)

    return _ai_chat(fabric_base, kind, payload)


def _write_state(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def self_test() -> None:
    assert RAVEN_CAPABILITY_MAP == {"system.inventory": "system-inventory"}
    assert "test-bridge-security" in ALLOWED_TEST_CAPABILITIES
    assert "shell" not in ALLOWED_KINDS
    msg, provider, workspace, system = _payload_text(
        "project.review",
        {"message": "review repo", "workspace": "rah-platform"},
    )
    assert msg == "review repo"
    assert provider == "anythingllm"
    assert workspace == "rah-platform"
    assert "project" in system.lower()
    try:
        _payload_text("text.task", {"provider": "unknown", "text": "x"})
        raise AssertionError("invalid provider accepted")
    except RuntimeError:
        pass
    print("PASS: RAH Agent Worker v1 self-test")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bridge", default=DEFAULT_BRIDGE)
    parser.add_argument("--fabric", default=DEFAULT_FABRIC)
    parser.add_argument("--token-file", default=r"C:\RAH\AgentBridge\token.txt")
    parser.add_argument("--state-file", default=r"C:\RAH\AgentWorker\worker-state.json")
    parser.add_argument("--poll-seconds", type=float, default=2.0)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    if args.bridge.rstrip("/") != DEFAULT_BRIDGE or args.fabric.rstrip("/") != DEFAULT_FABRIC:
        # Alternate localhost ports are permitted for CI, but never non-loopback hosts.
        for value in (args.bridge, args.fabric):
            if not (
                value.startswith("http://127.0.0.1:")
                or value.startswith("http://localhost:")
                or value.startswith("http://[::1]:")
            ):
                raise SystemExit("RAH Agent Worker permits localhost endpoints only.")

    token = _load_token(Path(args.token_file))
    worker_id = f"{socket.gethostname()}-rah-agent-worker-v{VERSION}"
    state_path = Path(args.state_file)
    poll = max(0.2, min(float(args.poll_seconds), 60.0))
    processed = 0

    while True:
        state = {
            "schema": SCHEMA,
            "version": VERSION,
            "workerId": worker_id,
            "bridge": args.bridge,
            "fabric": args.fabric,
            "status": "idle",
            "processed": processed,
            "pid": os.getpid(),
            "execCapability": False,
        }
        _write_state(state_path, state)

        try:
            job = _claim(args.bridge, token, worker_id)
        except Exception as exc:
            state.update({"status": "bridge-error", "error": str(exc)[:1000]})
            _write_state(state_path, state)
            if args.once:
                return 3
            time.sleep(min(10.0, poll * 2))
            continue

        if not job:
            if args.once:
                return 0
            time.sleep(poll)
            continue

        job_id = str(job.get("id") or "")
        state.update({"status": "running", "jobId": job_id, "kind": job.get("kind")})
        _write_state(state_path, state)

        try:
            result = _handle_job(args.fabric, job)
            _complete(args.bridge, token, job_id, worker_id, result)
            processed += 1
            state.update({"status": "completed", "processed": processed, "lastJobId": job_id})
            _write_state(state_path, state)
        except Exception as exc:
            try:
                _fail(args.bridge, token, job_id, worker_id, str(exc))
            except Exception:
                pass
            state.update({"status": "failed", "error": str(exc)[:1000], "lastJobId": job_id})
            _write_state(state_path, state)

        if args.once:
            return 0


if __name__ == "__main__":
    raise SystemExit(main())

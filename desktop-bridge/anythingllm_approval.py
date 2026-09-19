from __future__ import annotations

"""RAH Raven AnythingLLM approval gate v0.1.

This module lets Raven ask a local AnythingLLM workspace to review an already
allowlisted, read-only capability. An APPROVE decision creates a short-lived,
single-use approval token. The token does not authorize arbitrary commands,
file writes, or capabilities outside Raven Agent Runner's allowlist.
"""

import json
import os
import re
import secrets
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from flask import jsonify, request

from server_v17 import app


APPROVAL_GATE_VERSION = "0.1.0"
DEFAULT_BASE_URL = "http://127.0.0.1:3001"
DEFAULT_TIMEOUT_SECONDS = 20
DEFAULT_APPROVAL_TTL_SECONDS = 300
LOOPBACK_HOSTS = frozenset({"127.0.0.1", "localhost", "::1"})
CAPABILITY_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,79}$")
_APPROVAL_LOCK = threading.Lock()
_APPROVALS: dict[str, dict[str, Any]] = {}


class ApprovalConfigError(ValueError):
    pass


def _normalize_base_url(value: str) -> str:
    raw = str(value or "").strip() or DEFAULT_BASE_URL
    try:
        parsed = urllib.parse.urlsplit(raw)
        port = parsed.port
    except (TypeError, ValueError) as exc:
        raise ApprovalConfigError("AnythingLLM base URL is invalid.") from exc

    if parsed.scheme.lower() not in {"http", "https"}:
        raise ApprovalConfigError("AnythingLLM must use http or https.")
    host = (parsed.hostname or "").lower()
    if host not in LOOPBACK_HOSTS:
        raise ApprovalConfigError(
            "AnythingLLM approval is local-only; use 127.0.0.1, localhost or ::1."
        )
    if parsed.username is not None or parsed.password is not None:
        raise ApprovalConfigError("AnythingLLM URL must not contain credentials.")
    if parsed.query or parsed.fragment:
        raise ApprovalConfigError("AnythingLLM URL must not contain query or fragment data.")
    if parsed.path not in {"", "/"}:
        raise ApprovalConfigError("AnythingLLM base URL must not include an API path.")

    host_text = f"[{host}]" if ":" in host else host
    port_text = f":{port}" if port is not None else ""
    return f"{parsed.scheme.lower()}://{host_text}{port_text}"


def _config() -> dict[str, Any]:
    base_url = _normalize_base_url(os.environ.get("RAH_ANYTHINGLLM_BASE_URL", DEFAULT_BASE_URL))
    workspace = str(os.environ.get("RAH_ANYTHINGLLM_WORKSPACE", "")).strip()
    api_key = str(os.environ.get("RAH_ANYTHINGLLM_API_KEY", "")).strip()
    try:
        timeout = max(3, min(60, int(os.environ.get("RAH_ANYTHINGLLM_TIMEOUT", DEFAULT_TIMEOUT_SECONDS))))
    except (TypeError, ValueError):
        timeout = DEFAULT_TIMEOUT_SECONDS
    try:
        ttl = max(30, min(1800, int(os.environ.get("RAH_ANYTHINGLLM_APPROVAL_TTL", DEFAULT_APPROVAL_TTL_SECONDS))))
    except (TypeError, ValueError):
        ttl = DEFAULT_APPROVAL_TTL_SECONDS
    return {
        "base_url": base_url,
        "workspace": workspace,
        "api_key": api_key,
        "timeout": timeout,
        "ttl": ttl,
        "configured": bool(workspace and api_key),
    }


def _safe_status() -> dict[str, Any]:
    try:
        config = _config()
        return {
            "ok": True,
            "version": APPROVAL_GATE_VERSION,
            "mode": "anythingllm-read-only-gate",
            "configured": config["configured"],
            "base_url": config["base_url"],
            "workspace": config["workspace"] or None,
            "api_key_present": bool(config["api_key"]),
            "approval_ttl_seconds": config["ttl"],
            "local_only": True,
            "arbitrary_commands": False,
            "file_writes": False,
            "high_impact_approval": False,
        }
    except ApprovalConfigError as exc:
        return {
            "ok": False,
            "version": APPROVAL_GATE_VERSION,
            "mode": "anythingllm-read-only-gate",
            "configured": False,
            "error": str(exc),
            "local_only": True,
            "arbitrary_commands": False,
            "file_writes": False,
            "high_impact_approval": False,
        }


def _post_json(url: str, *, api_key: str, payload: dict[str, Any], timeout: int) -> dict[str, Any]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        raw = response.read().decode("utf-8", errors="replace")
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise RuntimeError("AnythingLLM returned a non-object JSON response.")
    return data


def _extract_response_text(data: dict[str, Any]) -> str:
    error = data.get("error")
    if error:
        raise RuntimeError(f"AnythingLLM error: {error}")

    for key in ("textResponse", "response", "answer", "text"):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    raise RuntimeError("AnythingLLM returned no usable text response.")


def _parse_json_object(text: str) -> dict[str, Any]:
    candidate = text.strip()
    if candidate.startswith("```"):
        candidate = re.sub(r"^```(?:json)?\s*", "", candidate, flags=re.IGNORECASE)
        candidate = re.sub(r"\s*```$", "", candidate)

    try:
        value = json.loads(candidate)
    except json.JSONDecodeError:
        start = candidate.find("{")
        end = candidate.rfind("}")
        if start < 0 or end <= start:
            raise RuntimeError("AnythingLLM approval reply was not valid JSON.")
        try:
            value = json.loads(candidate[start : end + 1])
        except json.JSONDecodeError as exc:
            raise RuntimeError("AnythingLLM approval reply was not valid JSON.") from exc

    if not isinstance(value, dict):
        raise RuntimeError("AnythingLLM approval reply must be a JSON object.")
    return value


def _decision_from_reply(text: str) -> dict[str, Any]:
    value = _parse_json_object(text)
    decision = str(value.get("decision") or "").strip().upper()
    if decision not in {"APPROVE", "REVISE", "BLOCK"}:
        raise RuntimeError("AnythingLLM decision must be APPROVE, REVISE or BLOCK.")

    reasons = value.get("reasons")
    if not isinstance(reasons, list):
        reasons = []
    clean_reasons = [str(item).strip()[:500] for item in reasons if str(item).strip()][:8]
    summary = str(value.get("summary") or "").strip()[:1000]
    risk = str(value.get("risk") or "unknown").strip().lower()[:40]
    return {
        "decision": decision,
        "summary": summary,
        "risk": risk,
        "reasons": clean_reasons,
    }


def _approval_prompt(capability: str, proposal: dict[str, Any]) -> str:
    envelope = {
        "capability": capability,
        "proposal": proposal,
        "security_boundary": {
            "read_only_allowlist_only": True,
            "arbitrary_shell": False,
            "file_writes": False,
            "deletion": False,
            "installation": False,
            "credential_changes": False,
            "network_exposure": False,
            "high_impact_changes": False,
        },
    }
    return (
        "You are the RAH local approval arbiter. Review this proposed Raven action. "
        "APPROVE only when it is clearly read-only, allowlisted, local, reversible/no-change, "
        "and consistent with the stated task. Use REVISE for a safe proposal that needs a "
        "small correction. Use BLOCK for ambiguous, write-capable, destructive, credential, "
        "external-network, arbitrary-shell, or high-impact actions.\n\n"
        "Return ONLY one JSON object with exactly these fields:\n"
        '{"decision":"APPROVE|REVISE|BLOCK","summary":"...","risk":"low|medium|high","reasons":["..."]}\n\n'
        "PROPOSAL:\n"
        + json.dumps(envelope, ensure_ascii=False, sort_keys=True)
    )


def _cleanup_expired(now: float | None = None) -> None:
    current = time.time() if now is None else now
    expired = [
        approval_id
        for approval_id, item in _APPROVALS.items()
        if float(item.get("expires_at") or 0) <= current
    ]
    for approval_id in expired:
        _APPROVALS.pop(approval_id, None)


def issue_approval(capability: str, proposal: dict[str, Any]) -> dict[str, Any]:
    capability = str(capability or "").strip()
    if not CAPABILITY_RE.fullmatch(capability):
        raise ValueError("Invalid Raven capability id.")
    if not isinstance(proposal, dict):
        raise ValueError("Proposal must be a JSON object.")

    config = _config()
    if not config["configured"]:
        raise ApprovalConfigError(
            "AnythingLLM approval is not configured. Set RAH_ANYTHINGLLM_WORKSPACE and "
            "RAH_ANYTHINGLLM_API_KEY."
        )

    workspace_path = urllib.parse.quote(config["workspace"], safe="")
    url = f"{config['base_url']}/api/v1/workspace/{workspace_path}/chat"
    session_id = "rah-approval-" + secrets.token_hex(10)
    response = _post_json(
        url,
        api_key=config["api_key"],
        payload={
            "message": _approval_prompt(capability, proposal),
            "mode": "chat",
            "sessionId": session_id,
            "enable_thinking": False,
        },
        timeout=config["timeout"],
    )
    parsed = _decision_from_reply(_extract_response_text(response))
    result: dict[str, Any] = {
        "ok": True,
        **parsed,
        "capability": capability,
        "reviewer": "anythingllm",
        "workspace": config["workspace"],
        "approval_id": None,
        "expires_at": None,
    }

    if parsed["decision"] == "APPROVE":
        now = time.time()
        approval_id = secrets.token_urlsafe(24)
        item = {
            "approval_id": approval_id,
            "capability": capability,
            "created_at": now,
            "expires_at": now + config["ttl"],
            "decision": "APPROVE",
            "reviewer": "anythingllm",
        }
        with _APPROVAL_LOCK:
            _cleanup_expired(now)
            _APPROVALS[approval_id] = item
        result["approval_id"] = approval_id
        result["expires_at"] = item["expires_at"]

    return result


def consume_approval(approval_id: str, capability: str) -> bool:
    token = str(approval_id or "").strip()
    requested = str(capability or "").strip()
    if not token or not requested:
        return False

    now = time.time()
    with _APPROVAL_LOCK:
        _cleanup_expired(now)
        item = _APPROVALS.get(token)
        if not item:
            return False
        if item.get("decision") != "APPROVE" or item.get("capability") != requested:
            return False
        if float(item.get("expires_at") or 0) <= now:
            _APPROVALS.pop(token, None)
            return False
        _APPROVALS.pop(token, None)
        return True


@app.get("/agent/approval/status")
def agent_approval_status():
    return jsonify(_safe_status())


@app.post("/agent/approval/review")
def agent_approval_review():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "Request must be a JSON object."}), 400

    capability = str(payload.get("capability") or "").strip()
    proposal = payload.get("proposal")
    if not capability or not isinstance(proposal, dict):
        return jsonify({
            "ok": False,
            "error": "capability and proposal object are required.",
        }), 400

    try:
        result = issue_approval(capability, proposal)
        return jsonify(result), 200
    except ApprovalConfigError as exc:
        return jsonify({"ok": False, "error": str(exc), "configured": False}), 503
    except urllib.error.HTTPError as exc:
        return jsonify({
            "ok": False,
            "error": f"AnythingLLM HTTP {exc.code}",
            "configured": True,
        }), 502
    except urllib.error.URLError as exc:
        return jsonify({
            "ok": False,
            "error": f"AnythingLLM connection failed: {getattr(exc, 'reason', exc)}",
            "configured": True,
        }), 502
    except (ValueError, RuntimeError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 422
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500

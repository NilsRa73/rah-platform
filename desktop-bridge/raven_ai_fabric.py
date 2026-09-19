from __future__ import annotations

"""RAH Raven AI Fabric v1.0.

Local-first orchestration layer for Raven Bridge.

The fabric does three things:
1. discovers/starts local AI providers such as LM Studio and AnythingLLM,
2. routes chat/knowledge requests to an available provider,
3. delegates machine work only to Raven's existing fixed, audited job allowlist.

It deliberately does not scrape credentials from local applications and never
accepts arbitrary shell commands.
"""

import json
import os
import pathlib
import shutil
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any

from flask import jsonify, request

from server_v17 import app

AI_FABRIC_VERSION = "1.2.0"
LM_BASE = os.getenv("RAH_LMSTUDIO_BASE_URL", "http://127.0.0.1:1234").rstrip("/")
ANYTHING_BASE = os.getenv("RAH_ANYTHINGLLM_BASE_URL", "http://127.0.0.1:3001").rstrip("/")
ANYTHING_WORKSPACE = os.getenv("RAH_ANYTHINGLLM_WORKSPACE", "rah-platform").strip() or "rah-platform"
OPENAI_BASE = os.getenv("RAH_AI_OPENAI_BASE_URL", "").rstrip("/")
OPENAI_MODEL = os.getenv("RAH_AI_OPENAI_MODEL", "").strip()
REQUEST_TIMEOUT = float(os.getenv("RAH_AI_TIMEOUT_SECONDS", "12"))
AUTO_START_LM = os.getenv("RAH_AI_AUTO_START_LMSTUDIO", "1").lower() not in {"0", "false", "no"}
AUTO_START_ANYTHING = os.getenv("RAH_AI_AUTO_START_ANYTHINGLLM", "1").lower() not in {"0", "false", "no"}

STATE_DIR = pathlib.Path(os.getenv("RAH_AI_STATE_DIR", r"C:\RAH\AI-Fabric") if os.name == "nt" else "~/.rah-ai-fabric").expanduser()
STATE_FILE = STATE_DIR / "providers.json"
LM_MODEL_FILE = STATE_DIR / "lmstudio-model.txt"
_START_LOCK = threading.Lock()
_START_ATTEMPTED: set[str] = set()
_LM_FAIL_LOCK = threading.Lock()
_LM_FAILED_UNTIL: dict[str, float] = {}
LM_FAILURE_QUARANTINE_SECONDS = max(30, min(int(os.getenv("RAH_LM_FAILURE_QUARANTINE_SECONDS", "300")), 3600))
LM_FALLBACK_LIMIT = max(1, min(int(os.getenv("RAH_LM_FALLBACK_LIMIT", "3")), 5))


@dataclass(frozen=True)
class ProviderStatus:
    id: str
    role: str
    online: bool
    ready: bool
    detail: str
    base_url: str = ""
    model: str = ""

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "role": self.role,
            "online": self.online,
            "ready": self.ready,
            "detail": self.detail,
            "base_url": self.base_url,
            "model": self.model,
        }


def _project_memory_config() -> dict[str, Any]:
    path = pathlib.Path(
        os.getenv("RAH_PROJECT_MEMORY_CONFIG", str(STATE_DIR / "project-memory.json"))
    ).expanduser()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        return raw if isinstance(raw, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def _anything_key() -> str:
    env_key = (
        os.getenv("RAH_ANYTHINGLLM_API_KEY")
        or os.getenv("ANYTHINGLLM_API_KEY")
        or ""
    ).strip()
    if env_key:
        return env_key

    config = _project_memory_config()
    token_file = (
        os.getenv("RAH_PROJECT_MEMORY_TOKEN_FILE")
        or str(config.get("token_file") or "")
        or str(STATE_DIR / "Secrets" / "anythingllm-token.txt")
    )
    try:
        value = pathlib.Path(token_file).expanduser().read_text(encoding="utf-8").strip()
        return value[:8192]
    except OSError:
        return ""


def _anything_base() -> str:
    config = _project_memory_config()
    return (
        os.getenv("RAH_ANYTHINGLLM_BASE_URL")
        or str(config.get("base_url") or "")
        or ANYTHING_BASE
    ).rstrip("/")


def _anything_workspace() -> str:
    config = _project_memory_config()
    return (
        os.getenv("RAH_ANYTHINGLLM_WORKSPACE")
        or str(config.get("workspace") or "")
        or ANYTHING_WORKSPACE
    ).strip()


def _openai_key() -> str:
    return (os.getenv("RAH_AI_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY") or "").strip()


def _json_request(
    url: str,
    *,
    method: str = "GET",
    body: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
    timeout: float = REQUEST_TIMEOUT,
) -> tuple[int, Any]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    merged = {"Accept": "application/json"}
    if body is not None:
        merged["Content-Type"] = "application/json"
    if headers:
        merged.update(headers)
    req = urllib.request.Request(url, data=data, headers=merged, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read().decode("utf-8", errors="replace")
            return int(response.status), json.loads(raw) if raw.strip() else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw) if raw.strip() else {}
        except json.JSONDecodeError:
            payload = {"error": raw[:1000]}
        return int(exc.code), payload


def _background_start_once(provider: str, command: list[str], cwd: str | None = None) -> None:
    with _START_LOCK:
        if provider in _START_ATTEMPTED:
            return
        _START_ATTEMPTED.add(provider)
    try:
        kwargs: dict[str, Any] = {
            "cwd": cwd,
            "stdin": subprocess.DEVNULL,
            "stdout": subprocess.DEVNULL,
            "stderr": subprocess.DEVNULL,
            "shell": False,
        }
        if os.name == "nt":
            kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
        subprocess.Popen(command, **kwargs)
    except OSError:
        pass


def _lm_preferred_model() -> str:
    env_model = os.getenv("RAH_LMSTUDIO_MODEL", "").strip()
    if env_model:
        return env_model
    try:
        return LM_MODEL_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _lm_is_quarantined(model: str) -> bool:
    now = time.time()
    with _LM_FAIL_LOCK:
        expired = [name for name, until in _LM_FAILED_UNTIL.items() if until <= now]
        for name in expired:
            _LM_FAILED_UNTIL.pop(name, None)
        return bool(model and _LM_FAILED_UNTIL.get(model, 0) > now)


def _lm_quarantine(model: str) -> None:
    if not model:
        return
    with _LM_FAIL_LOCK:
        _LM_FAILED_UNTIL[model] = time.time() + LM_FAILURE_QUARANTINE_SECONDS


def _lm_clear_quarantine(model: str) -> None:
    if not model:
        return
    with _LM_FAIL_LOCK:
        _LM_FAILED_UNTIL.pop(model, None)


def _lm_model_candidates(requested: str = "") -> list[str]:
    requested = requested.strip()
    models = _lm_models()
    if requested:
        return [requested]

    if not models:
        return []

    try:
        loaded = _lm_loaded_models()
    except Exception:
        loaded = []

    preferred = _lm_preferred_model()
    ordered: list[str] = []

    def add(name: str) -> None:
        if name and name in models and name not in ordered and not _lm_is_quarantined(name):
            ordered.append(name)

    add(preferred)
    for name in loaded:
        add(name)
    for name in models:
        add(name)

    return ordered[:LM_FALLBACK_LIMIT]


def _lm_models() -> list[str]:
    status, payload = _json_request(f"{LM_BASE}/v1/models", timeout=2.5)
    if status != 200 or not isinstance(payload, dict):
        return []
    models = []
    for item in payload.get("data") or []:
        if isinstance(item, dict) and item.get("id"):
            models.append(str(item["id"]))
    return models


def _lm_loaded_models() -> list[str]:
    status, payload = _json_request(f"{LM_BASE}/api/v1/models", timeout=2.5)
    if status != 200 or not isinstance(payload, dict):
        return []
    loaded: list[str] = []
    for item in payload.get("models") or []:
        if not isinstance(item, dict) or str(item.get("type") or "") != "llm":
            continue
        key = str(item.get("key") or "")
        instances = item.get("loaded_instances") or []
        if key and isinstance(instances, list) and instances:
            loaded.append(key)
    return loaded


def _lm_status(start_if_needed: bool = False) -> ProviderStatus:
    try:
        models = _lm_models()
        loaded = _lm_loaded_models()
        usable_loaded = [name for name in loaded if not _lm_is_quarantined(name)]
        chosen = _lm_preferred_model() if _lm_preferred_model() in models else (models[0] if models else "")
        if usable_loaded:
            if _lm_preferred_model() and _lm_preferred_model() in usable_loaded:
                chosen = _lm_preferred_model()
            elif chosen not in usable_loaded:
                chosen = usable_loaded[0]
        elif chosen and _lm_is_quarantined(chosen):
            fallback = [name for name in models if not _lm_is_quarantined(name)]
            chosen = fallback[0] if fallback else ""
        if usable_loaded:
            detail = "loaded and ready"
        elif loaded:
            detail = "loaded model(s) temporarily quarantined after runtime failure"
        elif models:
            detail = "server online; models exist but no loaded LLM instance"
        else:
            detail = "server online; no model exposed through /v1/models"
        return ProviderStatus(
            "lmstudio",
            "local inference, reasoning and tool-capable model",
            True,
            bool(usable_loaded),
            detail,
            LM_BASE,
            chosen,
        )
    except Exception as exc:
        if start_if_needed and AUTO_START_LM:
            lms = shutil.which("lms") or shutil.which("lms.exe")
            if lms:
                _background_start_once("lmstudio", [lms, "server", "start"])
                return ProviderStatus("lmstudio", "local inference, reasoning and tool-capable model", False, False, "start requested via lms server start", LM_BASE)
        return ProviderStatus("lmstudio", "local inference, reasoning and tool-capable model", False, False, str(exc)[:240], LM_BASE)


def _anything_executable() -> str | None:
    found = shutil.which("AnythingLLM.exe") or shutil.which("anythingllm")
    if found:
        return found
    if os.name != "nt":
        return None
    local = pathlib.Path(os.getenv("LOCALAPPDATA", ""))
    pf = pathlib.Path(os.getenv("ProgramFiles", r"C:\Program Files"))
    candidates = [
        local / "Programs" / "AnythingLLM" / "AnythingLLM.exe",
        local / "Programs" / "anythingllm-desktop" / "AnythingLLM.exe",
        local / "Programs" / "AnythingLLM Desktop" / "AnythingLLM.exe",
        pf / "AnythingLLM" / "AnythingLLM.exe",
    ]
    for path in candidates:
        if path.is_file():
            return str(path)
    return None


def _anything_status(start_if_needed: bool = False) -> ProviderStatus:
    key = _anything_key()
    base = _anything_base()
    try:
        if key:
            status, payload = _json_request(
                f"{base}/api/v1/auth",
                headers={"Authorization": f"Bearer {key}"},
                timeout=2.5,
            )
            authenticated = status == 200 and bool((payload or {}).get("authenticated"))
            return ProviderStatus(
                "anythingllm",
                "project knowledge, RAG, workspace memory and document chat",
                True,
                authenticated,
                "authenticated" if authenticated else f"API online; token rejected (HTTP {status})",
                base,
            )
        status, _ = _json_request(f"{base}/api/docs", timeout=2.5)
        if status in {200, 301, 302, 401, 403}:
            return ProviderStatus(
                "anythingllm",
                "project knowledge, RAG, workspace memory and document chat",
                True,
                False,
                "online; Developer API token not configured",
                base,
            )
    except Exception as exc:
        if start_if_needed and AUTO_START_ANYTHING:
            exe = _anything_executable()
            if exe:
                _background_start_once("anythingllm", [exe])
                return ProviderStatus("anythingllm", "project knowledge, RAG, workspace memory and document chat", False, False, "desktop start requested", base)
        return ProviderStatus("anythingllm", "project knowledge, RAG, workspace memory and document chat", False, False, str(exc)[:240], base)
    return ProviderStatus("anythingllm", "project knowledge, RAG, workspace memory and document chat", False, False, "offline", base)


def _openai_status() -> ProviderStatus:
    if not OPENAI_BASE:
        return ProviderStatus("openai-compatible", "optional cloud/API reasoning provider", False, False, "not configured")
    key = _openai_key()
    if not key:
        return ProviderStatus("openai-compatible", "optional cloud/API reasoning provider", True, False, "base URL configured; API key missing", OPENAI_BASE, OPENAI_MODEL)
    try:
        status, payload = _json_request(
            f"{OPENAI_BASE}/models",
            headers={"Authorization": f"Bearer {key}"},
            timeout=3,
        )
        return ProviderStatus("openai-compatible", "optional cloud/API reasoning provider", status == 200, status == 200, "configured", OPENAI_BASE, OPENAI_MODEL)
    except Exception as exc:
        return ProviderStatus("openai-compatible", "optional cloud/API reasoning provider", False, False, str(exc)[:240], OPENAI_BASE, OPENAI_MODEL)


def _raven_status() -> ProviderStatus:
    try:
        status, payload = _json_request("http://127.0.0.1:18765/agent/jobs/health", timeout=2.5)
        ready = status == 200 and bool((payload or {}).get("ready"))
        elevated = bool((payload or {}).get("elevated"))
        return ProviderStatus(
            "raven",
            "audited local machine actions through fixed capabilities",
            status == 200,
            ready,
            f"ready={ready}, elevated={elevated}, mode={(payload or {}).get('mode', 'unknown')}",
            "http://127.0.0.1:18765",
        )
    except Exception as exc:
        return ProviderStatus("raven", "audited local machine actions through fixed capabilities", False, False, str(exc)[:240], "http://127.0.0.1:18765")


def provider_statuses(start_if_needed: bool = False) -> list[ProviderStatus]:
    providers = [
        _raven_status(),
        _lm_status(start_if_needed=start_if_needed),
        _anything_status(start_if_needed=start_if_needed),
        _openai_status(),
    ]
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(json.dumps({"version": AI_FABRIC_VERSION, "providers": [p.as_dict() for p in providers]}, indent=2, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass
    return providers


def _lm_chat(message: str, system: str = "", model: str = "") -> dict[str, Any]:
    candidates = _lm_model_candidates(model)
    if not candidates:
        raise RuntimeError("LM Studio er online, men ingen brukbar modell er tilgjengelig.")
    messages: list[dict[str, str]] = []
    if system.strip():
        messages.append({"role": "system", "content": system.strip()})
    messages.append({"role": "user", "content": message})

    failures: list[str] = []
    for chosen in candidates:
        status, payload = _json_request(
            f"{LM_BASE}/v1/chat/completions",
            method="POST",
            body={"model": chosen, "messages": messages, "temperature": 0.3, "stream": False},
            timeout=max(REQUEST_TIMEOUT, 90),
        )
        if status == 200:
            _lm_clear_quarantine(chosen)
            try:
                STATE_DIR.mkdir(parents=True, exist_ok=True)
                LM_MODEL_FILE.write_text(chosen + "\n", encoding="utf-8")
            except OSError:
                pass
            choices = payload.get("choices") if isinstance(payload, dict) else None
            text = ""
            if choices and isinstance(choices, list) and isinstance(choices[0], dict):
                text = str(((choices[0].get("message") or {}).get("content")) or "")
            return {"provider": "lmstudio", "model": chosen, "text": text, "raw": payload}

        _lm_quarantine(chosen)
        failures.append(f"{chosen}: HTTP {status}: {str(payload)[:260]}")
        if model.strip():
            break

    raise RuntimeError("LM Studio model fallback exhausted: " + " | ".join(failures[:LM_FALLBACK_LIMIT]))


def _anything_chat(message: str, workspace: str = "") -> dict[str, Any]:
    key = _anything_key()
    if not key:
        raise RuntimeError("AnythingLLM er funnet, men Developer API token er ikke konfigurert.")
    base = _anything_base()
    slug = workspace.strip() or _anything_workspace()
    status, payload = _json_request(
        f"{base}/api/v1/workspace/{urllib.parse.quote(slug, safe='')}/chat",
        method="POST",
        headers={"Authorization": f"Bearer {key}"},
        body={"message": message, "mode": "chat", "sessionId": "rah-raven-ai-fabric"},
        timeout=max(REQUEST_TIMEOUT, 90),
    )
    if status != 200:
        raise RuntimeError(f"AnythingLLM svarte HTTP {status}: {str(payload)[:500]}")
    text = ""
    if isinstance(payload, dict):
        response = payload.get("textResponse")
        if isinstance(response, str):
            text = response
        elif response is not None:
            text = json.dumps(response, ensure_ascii=False)
    return {"provider": "anythingllm", "workspace": slug, "text": text, "raw": payload}


def _openai_chat(message: str, system: str = "", model: str = "") -> dict[str, Any]:
    key = _openai_key()
    chosen = model.strip() or OPENAI_MODEL
    if not OPENAI_BASE or not key or not chosen:
        raise RuntimeError("OpenAI-compatible provider mangler base URL, API key eller modell.")
    messages: list[dict[str, str]] = []
    if system.strip():
        messages.append({"role": "system", "content": system.strip()})
    messages.append({"role": "user", "content": message})
    status, payload = _json_request(
        f"{OPENAI_BASE}/chat/completions",
        method="POST",
        headers={"Authorization": f"Bearer {key}"},
        body={"model": chosen, "messages": messages, "temperature": 0.3, "stream": False},
        timeout=max(REQUEST_TIMEOUT, 90),
    )
    if status != 200:
        raise RuntimeError(f"Cloud provider svarte HTTP {status}: {str(payload)[:500]}")
    text = ""
    choices = payload.get("choices") if isinstance(payload, dict) else None
    if choices and isinstance(choices, list) and isinstance(choices[0], dict):
        text = str(((choices[0].get("message") or {}).get("content")) or "")
    return {"provider": "openai-compatible", "model": chosen, "text": text, "raw": payload}


def _auto_chat(message: str, system: str, workspace: str, model: str) -> dict[str, Any]:
    anything = _anything_status(start_if_needed=True)
    lm = _lm_status(start_if_needed=True)
    cloud = _openai_status()

    failures: list[str] = []
    attempted: set[str] = set()

    # Project/document questions prefer the knowledge workspace when it is authenticated.
    project_terms = {"project", "prosjekt", "repo", "raven", "rah", "dokument", "document", "tidligere", "memory", "minne"}
    lower = message.lower()
    if anything.ready and any(term in lower for term in project_terms):
        attempted.add("anythingllm")
        try:
            return _anything_chat(message, workspace)
        except Exception as exc:
            failures.append(f"anythingllm: {str(exc)[:420]}")

    if lm.ready:
        attempted.add("lmstudio")
        try:
            return _lm_chat(message, system, model)
        except Exception as exc:
            failures.append(f"lmstudio: {str(exc)[:620]}")

    if anything.ready and "anythingllm" not in attempted:
        attempted.add("anythingllm")
        try:
            return _anything_chat(message, workspace)
        except Exception as exc:
            failures.append(f"anythingllm: {str(exc)[:420]}")

    if cloud.ready:
        attempted.add("openai-compatible")
        try:
            return _openai_chat(message, system, model)
        except Exception as exc:
            failures.append(f"openai-compatible: {str(exc)[:420]}")

    if failures:
        raise RuntimeError("Ingen AI-provider fullførte forespørselen. " + " | ".join(failures))
    raise RuntimeError("Ingen AI-provider er ready. Se /ai/providers for konkret status.")


def _run_raven_capability(capability: str) -> dict[str, Any]:
    allowed = {
        "system-inventory",
        "hovedpc-local-status",
        "rah-file-index",
        "project-files",
        "git-status",
        "test-council",
        "test-vision-core",
        "test-core-demo",
        "test-mission-engine",
        "test-bridge-security",
    }
    if capability not in allowed:
        raise RuntimeError("Capability er ikke tillatt av AI Fabric v1.")
    status, payload = _json_request(
        "http://127.0.0.1:18765/agent/jobs",
        method="POST",
        body={"capability": capability, "confirm": True, "client_request_id": "ai-fabric"},
        timeout=5,
    )
    if status != 202 or not isinstance(payload, dict) or not payload.get("accepted"):
        raise RuntimeError(f"Raven avviste jobben (HTTP {status}): {str(payload)[:500]}")
    return payload


@app.get("/ai/providers")
def ai_providers():
    providers = provider_statuses(start_if_needed=True)
    return jsonify({
        "ok": True,
        "version": AI_FABRIC_VERSION,
        "mode": "local-first-orchestration",
        "providers": [p.as_dict() for p in providers],
        "credential_policy": "environment/config only; no secret scraping",
        "machine_actions": "Raven fixed audited allowlist only",
    })


@app.get("/ai/health")
def ai_health():
    providers = provider_statuses(start_if_needed=True)
    ready = [p.id for p in providers if p.id != "raven" and p.ready]
    return jsonify({
        "ok": bool(ready),
        "version": AI_FABRIC_VERSION,
        "ready_providers": ready,
        "provider_count": len(providers),
    }), (200 if ready else 503)


@app.post("/ai/chat")
def ai_chat():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "JSON body kreves."}), 400
    message = str(payload.get("message") or "").strip()
    if not message:
        return jsonify({"ok": False, "error": "message mangler."}), 400
    provider = str(payload.get("provider") or "auto").strip().lower()
    system = str(payload.get("system") or "").strip()
    workspace = str(payload.get("workspace") or "").strip()
    model = str(payload.get("model") or "").strip()
    try:
        if provider == "auto":
            result = _auto_chat(message, system, workspace, model)
        elif provider == "lmstudio":
            result = _lm_chat(message, system, model)
        elif provider == "anythingllm":
            result = _anything_chat(message, workspace)
        elif provider in {"openai", "openai-compatible", "cloud"}:
            result = _openai_chat(message, system, model)
        else:
            return jsonify({"ok": False, "error": "Ukjent provider."}), 400
        return jsonify({"ok": True, **result})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)[:1000], "provider": provider}), 503


@app.post("/ai/raven/job")
def ai_raven_job():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"ok": False, "error": "JSON body kreves."}), 400
    capability = str(payload.get("capability") or "").strip()
    try:
        result = _run_raven_capability(capability)
        return jsonify({"ok": True, "raven": result}), 202
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)[:1000]}), 403


@app.get("/ai/plan")
def ai_plan():
    providers = provider_statuses(start_if_needed=True)
    return jsonify({
        "ok": True,
        "version": AI_FABRIC_VERSION,
        "roles": {
            "raven": "local machine observation/tests/actions via fixed audited capabilities",
            "lmstudio": "private local inference and model/tool calls",
            "anythingllm": "project knowledge, RAG and durable workspace context",
            "openai-compatible": "optional cloud/API reasoning when explicitly configured",
        },
        "routing": "project/document questions prefer AnythingLLM; otherwise LM Studio; configured cloud is fallback",
        "providers": [p.as_dict() for p in providers],
    })


# Extend canonical health without replacing Raven Jobs' health wrapper.
_current_health = app.view_functions.get("health")
if _current_health and not getattr(_current_health, "_rah_ai_fabric_wrapped", False):
    def health_with_ai_fabric():
        response = _current_health()
        data = response.get_json() if hasattr(response, "get_json") else {}
        data.update({
            "ai_fabric": True,
            "ai_fabric_version": AI_FABRIC_VERSION,
            "ai_fabric_route": "/ai/health",
        })
        return jsonify(data)

    health_with_ai_fabric._rah_ai_fabric_wrapped = True
    app.view_functions["health"] = health_with_ai_fabric


# Discovery/start is deliberately background-only so Bridge startup is never blocked.
def _startup_probe() -> None:
    time.sleep(1.0)
    try:
        provider_statuses(start_if_needed=True)
    except Exception:
        pass


threading.Thread(target=_startup_probe, name="rah-ai-fabric-startup", daemon=True).start()

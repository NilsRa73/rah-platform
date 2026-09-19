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

AI_FABRIC_VERSION = "1.3.0"
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
MODEL_HEALTH_FILE = STATE_DIR / "model-health.json"
_START_LOCK = threading.Lock()
_START_ATTEMPTED: set[str] = set()
_MODEL_HEALTH_LOCK = threading.Lock()
LM_FALLBACK_LIMIT = max(1, min(int(os.getenv("RAH_LM_FALLBACK_LIMIT", "3")), 5))
MODEL_HEALTH_SCHEMA_VERSION = 1
MODEL_FAILURE_BACKOFF_SECONDS = (300, 1800, 7200)


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


class ProviderRouteError(RuntimeError):
    def __init__(self, message: str, attempts: list[dict[str, Any]] | None = None):
        super().__init__(message)
        self.attempts = list(attempts or [])


def _utc_iso(epoch: float | None = None) -> str:
    value = time.time() if epoch is None else float(epoch)
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(value))


def _load_model_health() -> dict[str, Any]:
    with _MODEL_HEALTH_LOCK:
        try:
            raw = json.loads(MODEL_HEALTH_FILE.read_text(encoding="utf-8"))
            if isinstance(raw, dict) and isinstance(raw.get("models"), dict):
                return raw
        except (OSError, json.JSONDecodeError):
            pass
    return {"schema": "rah-ai-model-health", "version": MODEL_HEALTH_SCHEMA_VERSION, "models": {}}


def _save_model_health(doc: dict[str, Any]) -> None:
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        doc["schema"] = "rah-ai-model-health"
        doc["version"] = MODEL_HEALTH_SCHEMA_VERSION
        doc["updatedAt"] = _utc_iso()
        raw = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
        tmp = MODEL_HEALTH_FILE.with_suffix(MODEL_HEALTH_FILE.suffix + ".tmp")
        with _MODEL_HEALTH_LOCK:
            tmp.write_text(raw, encoding="utf-8")
            os.replace(tmp, MODEL_HEALTH_FILE)
    except OSError:
        pass


def _model_health_entry(model: str) -> dict[str, Any]:
    doc = _load_model_health()
    value = (doc.get("models") or {}).get(model)
    return dict(value) if isinstance(value, dict) else {}


def _model_effective_state(model: str) -> str:
    entry = _model_health_entry(model)
    state = str(entry.get("state") or "UNKNOWN").upper()
    if state == "QUARANTINED":
        retry_epoch = float(entry.get("retryAfterEpoch") or 0)
        if retry_epoch and retry_epoch <= time.time():
            return "UNKNOWN"
    return state


def _lm_is_quarantined(model: str) -> bool:
    return _model_effective_state(model) in {"QUARANTINED", "RETEST_REQUIRED"}


def _lm_record_failure(model: str, reason: str, latency_ms: int | None = None) -> dict[str, Any]:
    if not model:
        return {}
    doc = _load_model_health()
    models = doc.setdefault("models", {})
    entry = dict(models.get(model) or {})
    fail_count = max(0, int(entry.get("failCount") or 0)) + 1
    now = time.time()
    if fail_count >= 4:
        state = "RETEST_REQUIRED"
        retry_epoch = None
        retry_after = None
    else:
        delay = MODEL_FAILURE_BACKOFF_SECONDS[min(fail_count - 1, len(MODEL_FAILURE_BACKOFF_SECONDS) - 1)]
        state = "QUARANTINED"
        retry_epoch = now + delay
        retry_after = _utc_iso(retry_epoch)
    entry.update({
        "state": state,
        "failCount": fail_count,
        "lastFailure": _utc_iso(now),
        "reason": str(reason)[:700],
        "retryAfter": retry_after,
        "retryAfterEpoch": retry_epoch,
    })
    if latency_ms is not None:
        entry["lastLatencyMs"] = max(0, int(latency_ms))
    models[model] = entry
    _save_model_health(doc)
    return dict(entry)


def _lm_record_success(model: str, latency_ms: int | None = None) -> dict[str, Any]:
    if not model:
        return {}
    doc = _load_model_health()
    models = doc.setdefault("models", {})
    previous = dict(models.get(model) or {})
    entry = {
        "state": "HEALTHY",
        "failCount": 0,
        "lastSuccess": _utc_iso(),
        "lastFailure": previous.get("lastFailure"),
        "reason": "",
        "retryAfter": None,
        "retryAfterEpoch": None,
    }
    if latency_ms is not None:
        entry["latencyMs"] = max(0, int(latency_ms))
    models[model] = entry
    _save_model_health(doc)
    return dict(entry)


def _model_health_snapshot() -> dict[str, Any]:
    doc = _load_model_health()
    models = {}
    for name, raw in (doc.get("models") or {}).items():
        if not isinstance(raw, dict):
            continue
        item = dict(raw)
        item["effectiveState"] = _model_effective_state(str(name))
        models[str(name)] = item
    return {
        "schema": "rah-ai-model-health",
        "version": MODEL_HEALTH_SCHEMA_VERSION,
        "updatedAt": doc.get("updatedAt"),
        "models": models,
    }


def _with_trace(result: dict[str, Any], attempts: list[dict[str, Any]]) -> dict[str, Any]:
    merged = dict(result)
    merged["traceVersion"] = 1
    merged["attempts"] = list(attempts)
    merged["attemptCount"] = len(attempts)
    merged["fallbackUsed"] = len(attempts) > 1
    merged["handledBy"] = merged.get("provider") or "unknown"
    return merged


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


def _lm_model_candidates(requested: str = "") -> list[str]:
    requested = requested.strip()
    models = _lm_models()
    if requested:
        # Explicit model requests are treated as a manual retest and never silently switch.
        return [requested]

    if not models:
        return []

    try:
        loaded = _lm_loaded_models()
    except Exception:
        loaded = []

    preferred = _lm_preferred_model()
    model_order = {name: index for index, name in enumerate(models)}

    def score(name: str) -> tuple[int, int, int, int]:
        state = _model_effective_state(name)
        health_rank = 0 if state == "HEALTHY" else 1
        preferred_rank = 0 if name == preferred else 1
        loaded_rank = 0 if name in loaded else 1
        return (health_rank, preferred_rank, loaded_rank, model_order.get(name, 9999))

    usable = [name for name in models if not _lm_is_quarantined(name)]
    usable.sort(key=score)
    return usable[:LM_FALLBACK_LIMIT]


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
        candidates = _lm_model_candidates()
        chosen = candidates[0] if candidates else ""
        if usable_loaded and chosen in usable_loaded:
            detail = "healthy/usable loaded model available"
        elif candidates:
            detail = "usable local fallback candidate available; load on demand"
        elif loaded:
            detail = "loaded model(s) quarantined or require explicit retest"
        elif models:
            detail = "all exposed models quarantined or require explicit retest"
        else:
            detail = "server online; no model exposed through /v1/models"
        return ProviderStatus(
            "lmstudio",
            "local inference, reasoning and tool-capable model",
            True,
            bool(candidates),
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
        raise ProviderRouteError("LM Studio er online, men ingen brukbar modell er tilgjengelig.", [])
    messages: list[dict[str, str]] = []
    if system.strip():
        messages.append({"role": "system", "content": system.strip()})
    messages.append({"role": "user", "content": message})

    attempts: list[dict[str, Any]] = []
    failures: list[str] = []
    explicit = bool(model.strip())
    for chosen in candidates:
        started = time.perf_counter()
        status, payload = _json_request(
            f"{LM_BASE}/v1/chat/completions",
            method="POST",
            body={"model": chosen, "messages": messages, "temperature": 0.3, "stream": False},
            timeout=max(REQUEST_TIMEOUT, 90),
        )
        duration_ms = max(0, int((time.perf_counter() - started) * 1000))
        if status == 200:
            health = _lm_record_success(chosen, duration_ms)
            try:
                STATE_DIR.mkdir(parents=True, exist_ok=True)
                LM_MODEL_FILE.write_text(chosen + "\n", encoding="utf-8")
            except OSError:
                pass
            choices = payload.get("choices") if isinstance(payload, dict) else None
            text = ""
            if choices and isinstance(choices, list) and isinstance(choices[0], dict):
                text = str(((choices[0].get("message") or {}).get("content")) or "")
            attempts.append({
                "provider": "lmstudio",
                "model": chosen,
                "result": "PASS",
                "reason": "",
                "quarantined": False,
                "healthState": health.get("state", "HEALTHY"),
                "durationMs": duration_ms,
            })
            return _with_trace(
                {"provider": "lmstudio", "model": chosen, "text": text, "raw": payload},
                attempts,
            )

        reason = f"HTTP {status}: {str(payload)[:500]}"
        health = _lm_record_failure(chosen, reason, duration_ms)
        attempts.append({
            "provider": "lmstudio",
            "model": chosen,
            "result": "FAILED",
            "reason": reason,
            "quarantined": True,
            "healthState": health.get("state", "QUARANTINED"),
            "retryAfter": health.get("retryAfter"),
            "durationMs": duration_ms,
        })
        failures.append(f"{chosen}: {reason}")
        if explicit:
            break

    raise ProviderRouteError(
        "LM Studio model fallback exhausted: " + " | ".join(failures[:LM_FALLBACK_LIMIT]),
        attempts,
    )


def _anything_chat(message: str, workspace: str = "") -> dict[str, Any]:
    key = _anything_key()
    slug = workspace.strip() or _anything_workspace()
    if not key:
        attempt = {
            "provider": "anythingllm",
            "workspace": slug,
            "result": "FAILED",
            "reason": "Developer API token er ikke konfigurert.",
            "quarantined": False,
            "durationMs": 0,
        }
        raise ProviderRouteError("AnythingLLM er funnet, men Developer API token er ikke konfigurert.", [attempt])
    base = _anything_base()
    started = time.perf_counter()
    status, payload = _json_request(
        f"{base}/api/v1/workspace/{urllib.parse.quote(slug, safe='')}/chat",
        method="POST",
        headers={"Authorization": f"Bearer {key}"},
        body={"message": message, "mode": "chat", "sessionId": "rah-raven-ai-fabric"},
        timeout=max(REQUEST_TIMEOUT, 90),
    )
    duration_ms = max(0, int((time.perf_counter() - started) * 1000))
    if status != 200:
        reason = f"HTTP {status}: {str(payload)[:500]}"
        raise ProviderRouteError(
            f"AnythingLLM svarte {reason}",
            [{
                "provider": "anythingllm",
                "workspace": slug,
                "result": "FAILED",
                "reason": reason,
                "quarantined": False,
                "durationMs": duration_ms,
            }],
        )
    text = ""
    if isinstance(payload, dict):
        response = payload.get("textResponse")
        if isinstance(response, str):
            text = response
        elif response is not None:
            text = json.dumps(response, ensure_ascii=False)
    return _with_trace(
        {
            "provider": "anythingllm",
            "workspace": slug,
            "backend": f"anythingllm-workspace:{slug}",
            "text": text,
            "raw": payload,
        },
        [{
            "provider": "anythingllm",
            "workspace": slug,
            "result": "PASS",
            "reason": "",
            "quarantined": False,
            "durationMs": duration_ms,
        }],
    )


def _openai_chat(message: str, system: str = "", model: str = "") -> dict[str, Any]:
    key = _openai_key()
    chosen = model.strip() or OPENAI_MODEL
    if not OPENAI_BASE or not key or not chosen:
        attempt = {
            "provider": "openai-compatible",
            "model": chosen,
            "result": "FAILED",
            "reason": "base URL, API key eller modell mangler.",
            "quarantined": False,
            "durationMs": 0,
        }
        raise ProviderRouteError("OpenAI-compatible provider mangler base URL, API key eller modell.", [attempt])
    messages: list[dict[str, str]] = []
    if system.strip():
        messages.append({"role": "system", "content": system.strip()})
    messages.append({"role": "user", "content": message})
    started = time.perf_counter()
    status, payload = _json_request(
        f"{OPENAI_BASE}/chat/completions",
        method="POST",
        headers={"Authorization": f"Bearer {key}"},
        body={"model": chosen, "messages": messages, "temperature": 0.3, "stream": False},
        timeout=max(REQUEST_TIMEOUT, 90),
    )
    duration_ms = max(0, int((time.perf_counter() - started) * 1000))
    if status != 200:
        reason = f"HTTP {status}: {str(payload)[:500]}"
        raise ProviderRouteError(
            f"Cloud provider svarte {reason}",
            [{
                "provider": "openai-compatible",
                "model": chosen,
                "result": "FAILED",
                "reason": reason,
                "quarantined": False,
                "durationMs": duration_ms,
            }],
        )
    text = ""
    choices = payload.get("choices") if isinstance(payload, dict) else None
    if choices and isinstance(choices, list) and isinstance(choices[0], dict):
        text = str(((choices[0].get("message") or {}).get("content")) or "")
    return _with_trace(
        {"provider": "openai-compatible", "model": chosen, "text": text, "raw": payload},
        [{
            "provider": "openai-compatible",
            "model": chosen,
            "result": "PASS",
            "reason": "",
            "quarantined": False,
            "durationMs": duration_ms,
        }],
    )


def _auto_chat(message: str, system: str, workspace: str, model: str) -> dict[str, Any]:
    anything = _anything_status(start_if_needed=True)
    lm = _lm_status(start_if_needed=True)
    cloud = _openai_status()

    failures: list[str] = []
    attempts: list[dict[str, Any]] = []
    attempted: set[str] = set()

    def run_provider(name: str, fn) -> dict[str, Any] | None:
        attempted.add(name)
        try:
            result = fn()
            combined = attempts + list(result.get("attempts") or [])
            return _with_trace(result, combined)
        except ProviderRouteError as exc:
            attempts.extend(exc.attempts)
            failures.append(f"{name}: {str(exc)[:620]}")
            return None
        except Exception as exc:
            attempts.append({
                "provider": name,
                "result": "FAILED",
                "reason": str(exc)[:500],
                "quarantined": False,
                "durationMs": 0,
            })
            failures.append(f"{name}: {str(exc)[:620]}")
            return None

    # Project/document questions prefer the authenticated knowledge workspace.
    project_terms = {"project", "prosjekt", "repo", "raven", "rah", "dokument", "document", "tidligere", "memory", "minne"}
    lower = message.lower()
    if anything.ready and any(term in lower for term in project_terms):
        result = run_provider("anythingllm", lambda: _anything_chat(message, workspace))
        if result is not None:
            return result

    if lm.ready:
        result = run_provider("lmstudio", lambda: _lm_chat(message, system, model))
        if result is not None:
            return result

    if anything.ready and "anythingllm" not in attempted:
        result = run_provider("anythingllm", lambda: _anything_chat(message, workspace))
        if result is not None:
            return result

    if cloud.ready:
        result = run_provider("openai-compatible", lambda: _openai_chat(message, system, model))
        if result is not None:
            return result

    if failures:
        raise ProviderRouteError(
            "Ingen AI-provider fullførte forespørselen. " + " | ".join(failures),
            attempts,
        )
    raise ProviderRouteError("Ingen AI-provider er ready. Se /ai/providers for konkret status.", attempts)


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


@app.get("/ai/model-health")
def ai_model_health():
    snapshot = _model_health_snapshot()
    snapshot["ok"] = True
    snapshot["fabricVersion"] = AI_FABRIC_VERSION
    snapshot["policy"] = {
        "priority": "HEALTHY local models first, then UNKNOWN local models; active quarantine excluded",
        "quarantine": ["5m", "30m", "2h", "explicit retest required after fourth failure"],
        "explicitModel": "explicit model requests may retest a quarantined model and never silently switch",
    }
    return jsonify(snapshot)


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
    except ProviderRouteError as exc:
        return jsonify({
            "ok": False,
            "error": str(exc)[:1000],
            "provider": provider,
            "traceVersion": 1,
            "attempts": exc.attempts,
            "attemptCount": len(exc.attempts),
            "fallbackUsed": len(exc.attempts) > 1,
        }), 503
    except Exception as exc:
        return jsonify({
            "ok": False,
            "error": str(exc)[:1000],
            "provider": provider,
            "traceVersion": 1,
            "attempts": [],
            "attemptCount": 0,
            "fallbackUsed": False,
        }), 503


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
        "routing": "project/document questions prefer authenticated AnythingLLM; otherwise HEALTHY local LM Studio models first, then UNKNOWN local models; configured cloud is final fallback",
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

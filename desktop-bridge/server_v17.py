from __future__ import annotations

"""RAH Raven Desktop Bridge v1.7.

Adds Chronicle activity memory to the existing v1.6 Case Center/Vision bridge.
The observer records only the foreground application and a redacted window title.
It never records keystrokes, clipboard content, passwords, form fields, audio or camera.
"""

import ctypes
import json
import os
import pathlib
import platform
import threading
import time
import uuid
from ctypes import wintypes
from datetime import datetime, timezone
from typing import Any

from flask import jsonify, request

from server_v16 import HOST, LOCAL_BROWSER_ORIGINS, PORT, app

APP_VERSION = "1.7.1"
CHRONICLE_VERSION = "1.7.1"


def _default_data_dir() -> pathlib.Path:
    configured = os.getenv("RAH_CHRONICLE_DIR", "").strip()
    if configured:
        return pathlib.Path(configured).expanduser().resolve()
    if os.name == "nt" and os.getenv("LOCALAPPDATA"):
        return pathlib.Path(os.environ["LOCALAPPDATA"]) / "RAH-Raven" / "Chronicle"
    return pathlib.Path.home() / ".rah-raven" / "chronicle"


DATA_DIR = _default_data_dir()
EVENTS_FILE = DATA_DIR / "events.jsonl"
STATE_FILE = DATA_DIR / "state.json"
CONFIG_FILE = DATA_DIR / "config.json"
DATA_LOCK = threading.RLock()
OBSERVER_STOP = threading.Event()
OBSERVER_THREAD: threading.Thread | None = None

DEFAULT_EXCLUDED_KEYWORDS = [
    "password", "passord", "engangskode", "one-time code", "2fa",
    "authenticator", "bitwarden", "1password", "keepass", "bank",
    "nettbank", "betaling", "payment", "kortnummer", "card number",
    "vipps", "helsenorge",
]

DEFAULT_CONFIG: dict[str, Any] = {
    "poll_seconds": 8,
    "record_window_titles": True,
    "excluded_keywords": DEFAULT_EXCLUDED_KEYWORDS,
    "max_title_chars": 180,
}

DEFAULT_STATE: dict[str, Any] = {
    "recording": False,
    "paused": False,
    "session": None,
    "last_window_key": None,
    "last_window_seen_at": None,
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _ensure_storage() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not CONFIG_FILE.exists():
        _write_json(CONFIG_FILE, DEFAULT_CONFIG)
    if not STATE_FILE.exists():
        _write_json(STATE_FILE, DEFAULT_STATE)
    EVENTS_FILE.touch(exist_ok=True)


def _read_json(path: pathlib.Path, fallback: dict[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else dict(fallback)
    except (OSError, json.JSONDecodeError):
        return dict(fallback)


def _write_json(path: pathlib.Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    temp.replace(path)


def _load_state() -> dict[str, Any]:
    _ensure_storage()
    state = _read_json(STATE_FILE, DEFAULT_STATE)
    for key, value in DEFAULT_STATE.items():
        state.setdefault(key, value)
    return state


def _save_state(state: dict[str, Any]) -> None:
    with DATA_LOCK:
        _write_json(STATE_FILE, state)


def _load_config() -> dict[str, Any]:
    _ensure_storage()
    config = _read_json(CONFIG_FILE, DEFAULT_CONFIG)
    for key, value in DEFAULT_CONFIG.items():
        config.setdefault(key, value)
    return config


def _save_config(config: dict[str, Any]) -> None:
    with DATA_LOCK:
        _write_json(CONFIG_FILE, config)


def _append_event(event_type: str, **fields: Any) -> dict[str, Any]:
    _ensure_storage()
    event = {
        "id": uuid.uuid4().hex,
        "timestamp": _utc_now(),
        "type": event_type,
        "source": "desktop-bridge",
        **fields,
    }
    line = json.dumps(event, ensure_ascii=False, separators=(",", ":"))
    with DATA_LOCK:
        with EVENTS_FILE.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")
    return event


def _read_events(limit: int = 200) -> list[dict[str, Any]]:
    _ensure_storage()
    limit = max(1, min(2000, int(limit)))
    try:
        lines = EVENTS_FILE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    output: list[dict[str, Any]] = []
    for line in reversed(lines[-limit:]):
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            output.append(item)
    return output


def _event_count() -> int:
    _ensure_storage()
    try:
        with EVENTS_FILE.open("r", encoding="utf-8") as handle:
            return sum(1 for line in handle if line.strip())
    except OSError:
        return 0


def _foreground_window_raw() -> dict[str, Any]:
    if platform.system() != "Windows":
        return {
            "available": False,
            "platform": platform.system(),
            "app": None,
            "title": None,
            "pid": None,
            "reason": "Aktivt vindu støttes foreløpig bare på Windows.",
        }

    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    hwnd = user32.GetForegroundWindow()
    if not hwnd:
        return {"available": False, "platform": "Windows", "reason": "Ingen aktivt vindu."}

    length = user32.GetWindowTextLengthW(hwnd)
    buffer = ctypes.create_unicode_buffer(max(1, length + 1))
    user32.GetWindowTextW(hwnd, buffer, len(buffer))
    title = buffer.value.strip()

    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    process_id = int(pid.value)
    executable = ""
    process_query_limited_information = 0x1000
    handle = kernel32.OpenProcess(process_query_limited_information, False, process_id)
    if handle:
        try:
            size = wintypes.DWORD(32768)
            path_buffer = ctypes.create_unicode_buffer(size.value)
            query = getattr(kernel32, "QueryFullProcessImageNameW", None)
            if query and query(handle, 0, path_buffer, ctypes.byref(size)):
                executable = path_buffer.value
        finally:
            kernel32.CloseHandle(handle)

    app_name = pathlib.Path(executable).name if executable else f"PID {process_id}"
    return {
        "available": True,
        "platform": "Windows",
        "app": app_name,
        "executable": executable,
        "title": title,
        "pid": process_id,
        "hwnd": int(hwnd),
    }


def _privacy_filter(window: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    if not window.get("available"):
        return window
    title = str(window.get("title") or "")
    app_name = str(window.get("app") or "")
    haystack = f"{app_name} {title}".casefold()
    keywords = [str(value).strip() for value in config.get("excluded_keywords", []) if str(value).strip()]
    matched = next((word for word in keywords if word.casefold() in haystack), None)
    titles_enabled = bool(config.get("record_window_titles", True))
    redacted = bool(matched) or not titles_enabled
    max_chars = max(40, min(500, int(config.get("max_title_chars", 180))))
    if not titles_enabled:
        safe_title = "[VINDUSTITTEL AVSLÅTT]"
    elif matched:
        safe_title = "[PRIVAT VINDU – TITTEL IKKE LAGRET]"
    else:
        safe_title = title[:max_chars]
    return {
        "available": True,
        "platform": window.get("platform"),
        "app": app_name,
        "title": safe_title,
        "pid": window.get("pid"),
        "redacted": redacted,
        "redaction_rule": matched if matched else None,
    }


def _foreground_window_safe() -> dict[str, Any]:
    return _privacy_filter(_foreground_window_raw(), _load_config())


def _observation_window_for_state(state: dict[str, Any]) -> dict[str, Any]:
    """Read the foreground window only inside an active, unpaused session."""
    if not state.get("recording") or not state.get("session"):
        return {
            "available": False,
            "reason": "Chronicle-observasjon er stoppet. Start en synlig økt for å lese aktivt vindu.",
            "observation_allowed": False,
        }
    if state.get("paused"):
        return {
            "available": False,
            "reason": "Chronicle-observasjon er pauset.",
            "observation_allowed": False,
        }
    window = _foreground_window_safe()
    window["observation_allowed"] = True
    return window


def _observer_loop() -> None:
    while not OBSERVER_STOP.is_set():
        state = _load_state()
        config = _load_config()
        delay = max(2, min(120, int(config.get("poll_seconds", 8))))
        if state.get("recording") and not state.get("paused") and state.get("session"):
            window = _foreground_window_safe()
            if window.get("available"):
                key = f"{window.get('app')}|{window.get('title')}|{window.get('redacted')}"
                if key != state.get("last_window_key"):
                    event = _append_event(
                        "focus",
                        session_id=state["session"].get("id"),
                        project=state["session"].get("project"),
                        mode=state["session"].get("mode"),
                        app=window.get("app"),
                        title=window.get("title"),
                        redacted=bool(window.get("redacted")),
                    )
                    state["last_window_key"] = key
                    state["last_window_seen_at"] = event["timestamp"]
                    _save_state(state)
        OBSERVER_STOP.wait(delay)


def _ensure_observer_thread() -> None:
    global OBSERVER_THREAD
    if OBSERVER_THREAD and OBSERVER_THREAD.is_alive():
        return
    OBSERVER_STOP.clear()
    OBSERVER_THREAD = threading.Thread(target=_observer_loop, name="raven-chronicle", daemon=True)
    OBSERVER_THREAD.start()


CHRONICLE_PROTECTED_PREFIX = "/chronicle"


@app.before_request
def protect_chronicle_local_apis():
    path = request.path
    if path != CHRONICLE_PROTECTED_PREFIX and not path.startswith(CHRONICLE_PROTECTED_PREFIX + "/"):
        return None
    origin = (request.headers.get("Origin") or "").rstrip("/")
    if origin and origin not in LOCAL_BROWSER_ORIGINS:
        return jsonify({
            "ok": False,
            "error": "Dette lokale Chronicle-endepunktet er ikke tilgjengelig fra fremmede nettsteder.",
        }), 403
    return None


@app.get("/chronicle/status")
def chronicle_status():
    state = _load_state()
    return jsonify({
        "ok": True,
        "version": CHRONICLE_VERSION,
        "bridge_version": APP_VERSION,
        "recording": bool(state.get("recording")),
        "paused": bool(state.get("paused")),
        "session": state.get("session"),
        "active_window": _observation_window_for_state(state),
        "event_count": _event_count(),
        "storage_path": str(DATA_DIR),
        "safeguards": {
            "keystrokes": False,
            "clipboard": False,
            "audio": False,
            "camera": False,
            "automatic_sending": False,
            "window_titles": True,
            "privacy_redaction": True,
            "foreground_read_requires_active_session": True,
            "paused_blocks_foreground_read": True,
        },
    })


@app.get("/chronicle/active-window")
def chronicle_active_window():
    state = _load_state()
    return jsonify({"ok": True, "window": _observation_window_for_state(state)})


@app.post("/chronicle/session/start")
def chronicle_session_start():
    payload = request.get_json(silent=True) or {}
    project = str(payload.get("project") or "RAH Raven").strip()[:160]
    mode = str(payload.get("mode") or "work").strip()[:40]
    state = _load_state()
    if state.get("recording") and state.get("session"):
        return jsonify({"ok": False, "error": "En Chronicle-økt kjører allerede.", "session": state["session"]}), 409
    session = {"id": uuid.uuid4().hex, "project": project, "mode": mode, "started_at": _utc_now()}
    state.update({
        "recording": True,
        "paused": False,
        "session": session,
        "last_window_key": None,
        "last_window_seen_at": None,
    })
    _save_state(state)
    event = _append_event("session-start", session_id=session["id"], project=project, mode=mode)
    _ensure_observer_thread()
    return jsonify({"ok": True, "session": session, "event": event})


@app.post("/chronicle/session/stop")
def chronicle_session_stop():
    state = _load_state()
    session = state.get("session")
    if not state.get("recording") or not session:
        return jsonify({"ok": False, "error": "Ingen Chronicle-økt kjører."}), 409
    stopped_at = _utc_now()
    event = _append_event(
        "session-stop",
        session_id=session.get("id"),
        project=session.get("project"),
        mode=session.get("mode"),
        started_at=session.get("started_at"),
        stopped_at=stopped_at,
    )
    state.update({
        "recording": False,
        "paused": False,
        "session": None,
        "last_window_key": None,
        "last_window_seen_at": None,
    })
    _save_state(state)
    return jsonify({"ok": True, "event": event})


@app.post("/chronicle/pause")
def chronicle_pause():
    state = _load_state()
    if not state.get("recording") or not state.get("session"):
        return jsonify({"ok": False, "error": "Ingen Chronicle-økt kjører."}), 409
    state["paused"] = True
    state["last_window_key"] = None
    _save_state(state)
    event = _append_event("pause", session_id=state["session"].get("id"), project=state["session"].get("project"))
    return jsonify({"ok": True, "event": event})


@app.post("/chronicle/resume")
def chronicle_resume():
    state = _load_state()
    if not state.get("recording") or not state.get("session"):
        return jsonify({"ok": False, "error": "Ingen Chronicle-økt kjører."}), 409
    state["paused"] = False
    state["last_window_key"] = None
    _save_state(state)
    event = _append_event("resume", session_id=state["session"].get("id"), project=state["session"].get("project"))
    _ensure_observer_thread()
    return jsonify({"ok": True, "event": event})


@app.post("/chronicle/event")
def chronicle_event():
    payload = request.get_json(silent=True) or {}
    title = str(payload.get("title") or "").strip()[:220]
    if not title:
        return jsonify({"ok": False, "error": "Tittel mangler."}), 400
    state = _load_state()
    event = _append_event(
        "manual",
        session_id=(state.get("session") or {}).get("id"),
        project=str(payload.get("project") or (state.get("session") or {}).get("project") or "").strip()[:160],
        category=str(payload.get("category") or "note").strip()[:60],
        privacy=str(payload.get("privacy") or "private").strip()[:40],
        title=title,
        note=str(payload.get("note") or "").strip()[:4000],
    )
    return jsonify({"ok": True, "event": event})


@app.get("/chronicle/events")
def chronicle_events():
    try:
        limit = int(request.args.get("limit", "200"))
    except ValueError:
        limit = 200
    return jsonify({"ok": True, "events": _read_events(limit), "count": _event_count()})


@app.get("/chronicle/config")
def chronicle_config_get():
    return jsonify({"ok": True, "config": _load_config()})


@app.post("/chronicle/config")
def chronicle_config_set():
    payload = request.get_json(silent=True) or {}
    current = _load_config()
    if "poll_seconds" in payload:
        current["poll_seconds"] = max(2, min(120, int(payload["poll_seconds"])))
    if "record_window_titles" in payload:
        current["record_window_titles"] = bool(payload["record_window_titles"])
    if "excluded_keywords" in payload:
        values = payload["excluded_keywords"]
        if not isinstance(values, list):
            return jsonify({"ok": False, "error": "excluded_keywords må være en liste."}), 400
        current["excluded_keywords"] = [str(value).strip()[:100] for value in values if str(value).strip()][:200]
    _save_config(current)
    _append_event("config-change", changed=list(payload.keys()))
    return jsonify({"ok": True, "config": current})


@app.get("/chronicle/export")
def chronicle_export():
    return jsonify({
        "ok": True,
        "exported_at": _utc_now(),
        "state": _load_state(),
        "config": _load_config(),
        "events": list(reversed(_read_events(2000))),
    })


@app.get("/chronicle")
def chronicle_info():
    return jsonify({
        "service": "RAH Raven Chronicle",
        "version": CHRONICLE_VERSION,
        "status": "/chronicle/status",
        "active_window": "/chronicle/active-window",
        "events": "/chronicle/events",
        "start": "/chronicle/session/start",
        "stop": "/chronicle/session/stop",
        "pause": "/chronicle/pause",
        "resume": "/chronicle/resume",
        "manual_event": "/chronicle/event",
        "config": "/chronicle/config",
        "export": "/chronicle/export",
    })


_old_health = app.view_functions.get("health")
if _old_health:
    def health_v17():
        response = _old_health()
        data = response.get_json() if hasattr(response, "get_json") else {}
        data.update({"version": APP_VERSION, "chronicle": True, "chronicle_version": CHRONICLE_VERSION})
        return jsonify(data)

    app.view_functions["health"] = health_v17


_ensure_storage()
_ensure_observer_thread()


if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge v{APP_VERSION}")
    print(f"Chronicle storage: {DATA_DIR}")
    print(f"Listening on http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)

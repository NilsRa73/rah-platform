from __future__ import annotations

"""Fixed-allowlist local app launcher for RAH Raven Studio.

Only predefined project launchers may be started. No caller-supplied paths,
arguments, shell fragments or environment overrides are accepted.
"""

import os
import pathlib
import subprocess
import threading
from datetime import datetime, timezone
from typing import Any

APP_LAUNCHER_VERSION = "0.2.0"

APP_ALLOWLIST: dict[str, dict[str, str]] = {
    "world-media": {
        "name": "RAH World Media",
        "path": "apps/rah-world-media/START-HER.cmd",
        "kind": "cmd",
        "description": "Global TV/radio/webcam deck.",
    },
    "rah-os": {
        "name": "RAH OS",
        "path": "START-HER-RAH-OS.cmd",
        "kind": "cmd",
        "description": "RAH OS front door and control panel.",
    },
    "raven-browser": {
        "name": "Raven Browser",
        "path": "START-HER-RAH-RAVEN-BROWSER.cmd",
        "kind": "cmd",
        "description": "Stable Raven Browser launcher.",
    },
}

_STATUS_LOCK = threading.RLock()
_LAUNCH_STATUS: dict[str, dict[str, Any]] = {
    app_id: {
        "state": "idle",
        "last_error": None,
        "last_attempt_at": None,
        "last_started_at": None,
        "pid": None,
    }
    for app_id in APP_ALLOWLIST
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _set_status(app_id: str, **changes: Any) -> dict[str, Any]:
    with _STATUS_LOCK:
        current = dict(_LAUNCH_STATUS.get(app_id) or {})
        current.update(changes)
        _LAUNCH_STATUS[app_id] = current
        return dict(current)


def status(app_id: str | None = None) -> dict[str, Any]:
    with _STATUS_LOCK:
        if app_id is not None:
            key = str(app_id or "").strip()
            if key not in APP_ALLOWLIST:
                raise KeyError("Appen er ikke i Raven-launcherens faste allowlist.")
            return {"id": key, **dict(_LAUNCH_STATUS[key])}
        return {
            key: {"id": key, **dict(value)}
            for key, value in _LAUNCH_STATUS.items()
        }


def _target(project_root: pathlib.Path, app_id: str) -> tuple[dict[str, str], pathlib.Path]:
    spec = APP_ALLOWLIST.get(str(app_id or "").strip())
    if spec is None:
        raise KeyError("Appen er ikke i Raven-launcherens faste allowlist.")
    root = pathlib.Path(project_root).resolve()
    target = (root / spec["path"]).resolve()
    try:
        target.relative_to(root)
    except ValueError as exc:
        raise RuntimeError("Launcher-stien peker utenfor RAH-prosjektet.") from exc
    return spec, target


def _is_windows() -> bool:
    return os.name == "nt"


def catalog(project_root: pathlib.Path) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for app_id, spec in APP_ALLOWLIST.items():
        _spec, target = _target(project_root, app_id)
        items.append({
            "id": app_id,
            "name": spec["name"],
            "description": spec["description"],
            "kind": spec["kind"],
            "available": target.is_file(),
            "target": spec["path"],
            "launch": status(app_id),
        })
    return items


def launch(project_root: pathlib.Path, app_id: str) -> dict[str, Any]:
    spec, target = _target(project_root, app_id)
    attempt_at = _utc_now()
    _set_status(
        app_id,
        state="starting",
        last_error=None,
        last_attempt_at=attempt_at,
        pid=None,
    )

    if not target.is_file():
        error = f"{spec['name']} mangler lokal launcher."
        current = _set_status(app_id, state="failed", last_error=error)
        return {
            "ok": False,
            "error": error,
            "id": app_id,
            "available": False,
            "target": spec["path"],
            **current,
        }

    if not _is_windows():
        error = "Raven App Launcher støtter foreløpig bare Windows."
        current = _set_status(app_id, state="failed", last_error=error)
        return {
            "ok": False,
            "error": error,
            "id": app_id,
            "available": True,
            "target": spec["path"],
            **current,
        }

    if spec["kind"] != "cmd":
        error = "Ukjent launcher-type i fast allowlist."
        _set_status(app_id, state="failed", last_error=error)
        raise RuntimeError(error)

    comspec = os.environ.get("COMSPEC") or r"C:\Windows\System32\cmd.exe"
    flags = int(getattr(subprocess, "CREATE_NO_WINDOW", 0))
    flags |= int(getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0))

    try:
        process = subprocess.Popen(
            [comspec, "/d", "/s", "/c", "call", str(target)],
            cwd=str(target.parent),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=flags,
            shell=False,
            close_fds=True,
        )
    except OSError as exc:
        error = str(exc) or exc.__class__.__name__
        current = _set_status(app_id, state="failed", last_error=error, pid=None)
        return {
            "ok": False,
            "error": error,
            "id": app_id,
            "name": spec["name"],
            "available": True,
            "target": spec["path"],
            "shell_window": False,
            "arbitrary_commands": False,
            "caller_arguments": False,
            **current,
        }

    started_at = _utc_now()
    current = _set_status(
        app_id,
        state="started",
        last_error=None,
        last_started_at=started_at,
        pid=process.pid,
    )
    return {
        "ok": True,
        "id": app_id,
        "name": spec["name"],
        "available": True,
        "target": spec["path"],
        "shell_window": False,
        "arbitrary_commands": False,
        "caller_arguments": False,
        **current,
    }

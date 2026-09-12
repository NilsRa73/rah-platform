from __future__ import annotations

"""Read-only discovery and allowlisted launchers for RAH Observer Live Surfaces.

This module does not auto-connect to remote peers, store credentials, or accept
arbitrary executable paths. It only detects known local apps/services and opens
an explicit local UI when the user requests it.
"""

import json
import os
import shutil
import subprocess
from typing import Any

SURFACE_VERSION = "1.0.0"
POWERSHELL = shutil.which("powershell.exe") or shutil.which("pwsh.exe") or "powershell.exe"
ALLOWED_SURFACE_ACTIONS = frozenset({"OPEN_RUSTDESK", "OPEN_SPACEDESK_DISPLAY_SETTINGS"})


def _first_existing(paths: list[str]) -> str:
    for path in paths:
        if path and os.path.isfile(path):
            return path
    return ""


def _run(args: list[str], timeout: float = 4.0) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            args,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,
            creationflags=(getattr(subprocess, "CREATE_NO_WINDOW", 0) if os.name == "nt" else 0),
        )
    except (OSError, subprocess.TimeoutExpired):
        return None


def _ps_json(script: str, timeout: float = 5.0) -> list[dict[str, Any]]:
    if os.name != "nt":
        return []
    result = _run([
        POWERSHELL,
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        script,
    ], timeout=timeout)
    if not result or result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    if isinstance(data, dict):
        return [data]
    return [item for item in data if isinstance(item, dict)] if isinstance(data, list) else []


def _rustdesk_path() -> str:
    program_files = os.environ.get("ProgramFiles", r"C:\Program Files")
    local_app = os.environ.get("LOCALAPPDATA", "")
    return _first_existing([
        shutil.which("rustdesk.exe") or "",
        os.path.join(program_files, "RustDesk", "rustdesk.exe"),
        os.path.join(local_app, "RustDesk", "rustdesk.exe") if local_app else "",
    ])


def _rustdesk_id(exe: str) -> str:
    if not exe:
        return ""
    result = _run([exe, "--get-id"], timeout=4.0)
    if not result or result.returncode != 0:
        return ""
    text = (result.stdout or "").strip().splitlines()
    if not text:
        return ""
    value = text[-1].strip()
    if 1 <= len(value) <= 80 and all(ch.isalnum() or ch in "-_" for ch in value):
        return value
    return ""


def _spacedesk_services() -> list[dict[str, Any]]:
    return _ps_json(
        "Get-Service -ErrorAction SilentlyContinue | "
        "Where-Object {$_.Name -like '*spacedesk*' -or $_.DisplayName -like '*spacedesk*'} | "
        "Select-Object Name,DisplayName,Status,StartType | ConvertTo-Json -Compress",
        timeout=5.0,
    )


def _process_flags() -> dict[str, bool]:
    rows = _ps_json(
        "Get-Process -ErrorAction SilentlyContinue | "
        "Where-Object {$_.ProcessName -like '*rustdesk*' -or $_.ProcessName -like '*spacedesk*'} | "
        "Select-Object ProcessName | ConvertTo-Json -Compress",
        timeout=4.0,
    )
    names = [str(row.get("ProcessName") or "").lower() for row in rows]
    return {
        "rustdesk": any("rustdesk" in name for name in names),
        "spacedesk": any("spacedesk" in name for name in names),
    }


def discover_surface_apps() -> dict[str, Any]:
    rustdesk = _rustdesk_path()
    services = _spacedesk_services()
    flags = _process_flags()
    spacedesk_running = flags["spacedesk"] or any(str(row.get("Status") or "").lower() == "running" for row in services)
    return {
        "ok": True,
        "version": SURFACE_VERSION,
        "rustdesk": {
            "available": bool(rustdesk),
            "running": flags["rustdesk"],
            "local_id": _rustdesk_id(rustdesk),
            "launch_supported": bool(rustdesk),
        },
        "spacedesk": {
            "available": bool(services) or spacedesk_running,
            "running": spacedesk_running,
            "services": [
                {
                    "name": str(row.get("Name") or "")[:100],
                    "display_name": str(row.get("DisplayName") or "")[:140],
                    "status": str(row.get("Status") or "")[:40],
                }
                for row in services[:12]
            ],
            "role": "Windows display server/driver when installed on this PC",
            "viewer_note": "Connected spacedesk viewer devices appear to Windows as displays and therefore become Wall targets.",
        },
        "automatic_remote_connect": False,
        "credentials_stored": False,
        "arbitrary_commands": False,
    }


def execute_surface_action(payload: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(payload, dict):
        return {"ok": False, "error": "Surface action must be JSON."}
    action = str(payload.get("action") or "").strip().upper()
    if action not in ALLOWED_SURFACE_ACTIONS:
        return {"ok": False, "error": "Surface action is not allowlisted.", "allowed": sorted(ALLOWED_SURFACE_ACTIONS)}
    if os.name != "nt":
        return {"ok": False, "error": "Surface actions require Windows."}

    if action == "OPEN_RUSTDESK":
        exe = _rustdesk_path()
        if not exe:
            return {"ok": False, "error": "RustDesk is not installed or not found."}
        try:
            subprocess.Popen([exe], close_fds=True)
            return {"ok": True, "action": action, "mode": "local-app", "app": "RustDesk"}
        except OSError as exc:
            return {"ok": False, "error": str(exc)}

    if action == "OPEN_SPACEDESK_DISPLAY_SETTINGS":
        try:
            os.startfile("ms-settings:display")  # type: ignore[attr-defined]
            return {"ok": True, "action": action, "mode": "windows-settings", "target": "ms-settings:display"}
        except OSError as exc:
            return {"ok": False, "error": str(exc)}

    return {"ok": False, "error": "Surface action did not resolve."}

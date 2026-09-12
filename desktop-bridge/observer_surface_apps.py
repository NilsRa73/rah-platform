from __future__ import annotations

"""Read-only discovery for RAH Observer Live Surfaces.

Detects local RustDesk/spacedesk availability and status without launching apps,
connecting peers, storing credentials, or accepting arbitrary executable paths.
"""

import json
import os
import shutil
import subprocess
from typing import Any

SURFACE_VERSION = "1.0.0"
POWERSHELL = shutil.which("powershell.exe") or shutil.which("pwsh.exe") or "powershell.exe"


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
    lines = (result.stdout or "").strip().splitlines()
    if not lines:
        return ""
    value = lines[-1].strip()
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
            "read_only": True,
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
            "read_only": True,
        },
        "read_only": True,
        "automatic_remote_connect": False,
        "credentials_stored": False,
        "arbitrary_commands": False,
    }

from __future__ import annotations

"""Read-only local display discovery for RAH Observer Screen Router.

Uses the Windows Forms Screen catalog when available. No display settings are
changed and no external device is contacted.
"""

import json
import os
import shutil
import subprocess
from typing import Any

DISPLAY_VERSION = "1.0.0"
POWERSHELL = shutil.which("powershell.exe") or shutil.which("pwsh.exe") or "powershell.exe"


def _run_ps(script: str, timeout: float = 5.0) -> list[dict[str, Any]]:
    if os.name != "nt":
        return []
    try:
        result = subprocess.run(
            [
                POWERSHELL,
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                script,
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    if result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    if isinstance(data, dict):
        return [data]
    return [item for item in data if isinstance(item, dict)] if isinstance(data, list) else []


def discover_displays() -> dict[str, Any]:
    rows = _run_ps(
        "Add-Type -AssemblyName System.Windows.Forms; "
        "[System.Windows.Forms.Screen]::AllScreens | ForEach-Object { "
        "[pscustomobject]@{DeviceName=$_.DeviceName;Primary=$_.Primary;"
        "X=$_.Bounds.X;Y=$_.Bounds.Y;Width=$_.Bounds.Width;Height=$_.Bounds.Height;"
        "WorkingX=$_.WorkingArea.X;WorkingY=$_.WorkingArea.Y;"
        "WorkingWidth=$_.WorkingArea.Width;WorkingHeight=$_.WorkingArea.Height} "
        "} | ConvertTo-Json -Compress"
    )
    displays: list[dict[str, Any]] = []
    for index, row in enumerate(rows, start=1):
        try:
            width = int(row.get("Width") or 0)
            height = int(row.get("Height") or 0)
            x = int(row.get("X") or 0)
            y = int(row.get("Y") or 0)
        except (TypeError, ValueError):
            continue
        if width <= 0 or height <= 0:
            continue
        device_name = str(row.get("DeviceName") or f"DISPLAY{index}")[:120]
        displays.append({
            "id": f"display:{device_name}",
            "index": index,
            "name": f"Screen {index}",
            "device_name": device_name,
            "primary": bool(row.get("Primary")),
            "x": x,
            "y": y,
            "width": width,
            "height": height,
            "resolution": f"{width}x{height}",
            "working_width": int(row.get("WorkingWidth") or width),
            "working_height": int(row.get("WorkingHeight") or height),
        })
    displays.sort(key=lambda item: (not item["primary"], item["x"], item["y"]))
    return {
        "ok": True,
        "version": DISPLAY_VERSION,
        "count": len(displays),
        "displays": displays,
        "read_only": True,
    }

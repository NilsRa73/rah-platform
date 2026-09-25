from __future__ import annotations

"""Fixed-allowlist local app launcher for RAH Raven Studio.

Only predefined project launchers may be started. No caller-supplied paths,
arguments, shell fragments or environment overrides are accepted.
"""

import os
import pathlib
import subprocess
from typing import Any

APP_LAUNCHER_VERSION = "0.1.0"

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
        })
    return items


def launch(project_root: pathlib.Path, app_id: str) -> dict[str, Any]:
    spec, target = _target(project_root, app_id)
    if not target.is_file():
        return {
            "ok": False,
            "error": f"{spec['name']} mangler lokal launcher.",
            "id": app_id,
            "available": False,
            "target": spec["path"],
        }

    if os.name != "nt":
        return {
            "ok": False,
            "error": "Raven App Launcher støtter foreløpig bare Windows.",
            "id": app_id,
            "available": True,
            "target": spec["path"],
        }

    if spec["kind"] != "cmd":
        raise RuntimeError("Ukjent launcher-type i fast allowlist.")

    comspec = os.environ.get("COMSPEC") or r"C:\Windows\System32\cmd.exe"
    flags = int(getattr(subprocess, "CREATE_NO_WINDOW", 0))
    flags |= int(getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0))

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
    return {
        "ok": True,
        "id": app_id,
        "name": spec["name"],
        "pid": process.pid,
        "available": True,
        "target": spec["path"],
        "shell_window": False,
        "arbitrary_commands": False,
        "caller_arguments": False,
    }

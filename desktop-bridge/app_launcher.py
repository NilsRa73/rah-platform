from __future__ import annotations

"""Explicit local launcher for a tiny allowlist of RAH desktop apps.

This module intentionally has no arbitrary command, path, argument, or shell
interface. A caller may only launch an app ID defined in APP_DEFINITIONS.
"""

import os
import pathlib
import subprocess
from typing import Any, Callable, Mapping

APP_LAUNCHER_VERSION = "0.1.0"
APP_LAUNCHER_MODE = "local-explicit-allowlist"

APP_DEFINITIONS: dict[str, dict[str, Any]] = {
    "world-media": {
        "name": "RAH World Media",
        "version": "14.0",
        "kind": "windows-cmd",
        "installed_candidates": [
            r"C:\RAH\WorldMedia\14.0\START-HER.cmd",
        ],
        "repo_candidates": [
            "apps/rah-world-media/START-HER.cmd",
        ],
    },
}


def _candidate_paths(definition: Mapping[str, Any], project_root: pathlib.Path) -> list[pathlib.Path]:
    paths: list[pathlib.Path] = []
    for raw in definition.get("installed_candidates", []):
        paths.append(pathlib.Path(str(raw)))
    for raw in definition.get("repo_candidates", []):
        paths.append(project_root / str(raw))
    return paths


def _resolve_target(definition: Mapping[str, Any], project_root: pathlib.Path) -> pathlib.Path | None:
    for path in _candidate_paths(definition, project_root):
        if path.is_file():
            return path.resolve()
    return None


def catalog(project_root: pathlib.Path | str) -> dict[str, Any]:
    root = pathlib.Path(project_root).resolve()
    rows: list[dict[str, Any]] = []
    for app_id, definition in sorted(APP_DEFINITIONS.items()):
        target = _resolve_target(definition, root)
        rows.append(
            {
                "id": app_id,
                "name": definition["name"],
                "version": definition["version"],
                "kind": definition["kind"],
                "installed": target is not None,
                "source": (
                    "installed"
                    if target and str(target).lower().startswith("c:\\rah\\")
                    else ("repo" if target else None)
                ),
            }
        )
    return {
        "ok": True,
        "version": APP_LAUNCHER_VERSION,
        "mode": APP_LAUNCHER_MODE,
        "explicit_confirmation_required": True,
        "arbitrary_shell": False,
        "apps": rows,
    }


def launch(
    app_id: str,
    project_root: pathlib.Path | str,
    *,
    platform_name: str | None = None,
    popen: Callable[..., Any] = subprocess.Popen,
    environ: Mapping[str, str] | None = None,
) -> dict[str, Any]:
    definition = APP_DEFINITIONS.get(str(app_id or ""))
    if definition is None:
        return {
            "ok": False,
            "code": "unknown-app",
            "error": "Appen finnes ikke i Raven sin faste allowlist.",
        }

    current_platform = os.name if platform_name is None else platform_name
    if current_platform != "nt":
        return {
            "ok": False,
            "code": "windows-only",
            "error": "Denne app-launcheren er foreløpig kun aktiv på Windows.",
        }

    root = pathlib.Path(project_root).resolve()
    target = _resolve_target(definition, root)
    if target is None:
        return {
            "ok": False,
            "code": "not-installed",
            "error": f"{definition['name']} {definition['version']} ble ikke funnet på en godkjent plassering.",
        }

    env = os.environ if environ is None else environ
    command_processor = env.get("COMSPEC") or r"C:\Windows\System32\cmd.exe"
    argv = [command_processor, "/d", "/c", str(target)]
    kwargs: dict[str, Any] = {
        "cwd": str(target.parent),
        "shell": False,
    }
    creation_flag = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    if creation_flag:
        kwargs["creationflags"] = creation_flag

    process = popen(argv, **kwargs)
    return {
        "ok": True,
        "id": app_id,
        "name": definition["name"],
        "version": definition["version"],
        "launched": True,
        "pid": getattr(process, "pid", None),
        "mode": APP_LAUNCHER_MODE,
    }

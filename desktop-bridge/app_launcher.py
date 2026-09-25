from __future__ import annotations

"""Fixed local action launcher for approved RAH desktop apps.

The caller supplies only an app ID and action ID. Executable paths, script
paths and arguments all come from this module's static allowlist. There is no
generic shell, arbitrary path, arbitrary argument, or user command interface.
"""

import os
import pathlib
import subprocess
from typing import Any, Callable, Mapping

APP_LAUNCHER_VERSION = "0.2.0"
APP_LAUNCHER_MODE = "local-explicit-action-allowlist"


def _cmd_action(
    label: str,
    *,
    installed: list[str] | None = None,
    repo: list[str] | None = None,
    args: list[str] | None = None,
    confirm: bool = False,
) -> dict[str, Any]:
    return {
        "label": label,
        "runner": "cmd",
        "installed_candidates": installed or [],
        "repo_candidates": repo or [],
        "args": args or [],
        "requires_confirmation": confirm,
    }


def _powershell_action(
    label: str,
    *,
    installed: list[str] | None = None,
    repo: list[str] | None = None,
    args: list[str] | None = None,
    confirm: bool = False,
) -> dict[str, Any]:
    return {
        "label": label,
        "runner": "powershell",
        "installed_candidates": installed or [],
        "repo_candidates": repo or [],
        "args": args or [],
        "requires_confirmation": confirm,
    }


APP_DEFINITIONS: dict[str, dict[str, Any]] = {
    "world-media": {
        "name": "RAH World Media",
        "version": "14.0",
        "default_action": "start",
        "actions": {
            "start": _cmd_action(
                "START",
                installed=[r"C:\RAH\WorldMedia\14.0\START-HER.cmd"],
                repo=["apps/rah-world-media/START-HER.cmd"],
                confirm=True,
            ),
            "selftest": _cmd_action(
                "SELFTEST",
                installed=[r"C:\RAH\WorldMedia\14.0\SELFTEST.cmd"],
                repo=["apps/rah-world-media/SELFTEST.cmd"],
            ),
            "repair": _cmd_action(
                "REPAIR",
                installed=[r"C:\RAH\WorldMedia\14.0\REPAIR.cmd"],
                repo=["apps/rah-world-media/REPAIR.cmd"],
                confirm=True,
            ),
        },
    },
    "raven-browser": {
        "name": "RAH Raven Browser",
        "version": "1.3.0",
        "default_action": "start",
        "actions": {
            "start": _cmd_action(
                "START",
                installed=[r"C:\RAH\Browser\START-RAH-RAVEN-BROWSER.cmd"],
            ),
            "selftest": _powershell_action(
                "SELFTEST",
                repo=["RAH-RAVEN-BROWSER-FINAL.ps1"],
                args=["-SelfTest"],
            ),
            "setup-repair": _cmd_action(
                "SETUP / REPAIR",
                repo=["START-HER-RAH-RAVEN-BROWSER.cmd"],
                confirm=True,
            ),
        },
    },
    "rah-os": {
        "name": "RAH Raven OS Front Door",
        "version": "0.6",
        "default_action": "start",
        "actions": {
            "start": _cmd_action(
                "OPEN / SAFE REPAIR",
                installed=[r"C:\RAH\RavenOS\START-HER-RAH-OS.cmd"],
                repo=["START-HER-RAH-OS.cmd"],
                confirm=True,
            ),
            "selftest": _powershell_action(
                "SELFTEST",
                installed=[r"C:\RAH\RavenOS\RAH-OS-SELFTEST.ps1"],
                repo=["RAH-OS-SELFTEST.ps1"],
                args=["-Quick"],
            ),
            "repair": _cmd_action(
                "SAFE REPAIR",
                installed=[r"C:\RAH\RavenOS\REPAIR-RAH-OS.cmd"],
                repo=["REPAIR-RAH-OS.cmd"],
                confirm=True,
            ),
        },
    },
    "rah-home": {
        "name": "RAH Home System",
        "version": "1.0 finalize / Control 1.19",
        "default_action": "finalize",
        "actions": {
            "finalize": _cmd_action(
                "FINALIZE / REPAIR",
                repo=["START-HER-RAH-HOME.cmd"],
                confirm=True,
            ),
            "selftest": _cmd_action(
                "SELFTEST",
                repo=["START-HER-RAH-HOME.cmd"],
                args=["--self-test"],
            ),
            "diagnostics": _powershell_action(
                "DIAGNOSTICS",
                installed=[r"C:\RAH\Home\RAH-HOME-DIAGNOSTICS.ps1"],
                repo=["RAH-HOME-DIAGNOSTICS.ps1"],
                args=["-InstallRoot", r"C:\RAH\Home", "-Reason", "raven-studio"],
            ),
        },
    },
}


def _candidate_paths(action: Mapping[str, Any], project_root: pathlib.Path) -> list[tuple[str, pathlib.Path]]:
    paths: list[tuple[str, pathlib.Path]] = []
    for raw in action.get("installed_candidates", []):
        paths.append(("installed", pathlib.Path(str(raw))))
    for raw in action.get("repo_candidates", []):
        paths.append(("repo", project_root / str(raw)))
    return paths


def _resolve_target(
    action: Mapping[str, Any], project_root: pathlib.Path
) -> tuple[str | None, pathlib.Path | None]:
    for source, path in _candidate_paths(action, project_root):
        if path.is_file():
            return source, path.resolve()
    return None, None


def catalog(project_root: pathlib.Path | str) -> dict[str, Any]:
    root = pathlib.Path(project_root).resolve()
    rows: list[dict[str, Any]] = []
    for app_id, definition in sorted(APP_DEFINITIONS.items()):
        actions: list[dict[str, Any]] = []
        for action_id, action in definition["actions"].items():
            source, target = _resolve_target(action, root)
            actions.append(
                {
                    "id": action_id,
                    "label": action["label"],
                    "runner": action["runner"],
                    "available": target is not None,
                    "source": source,
                    "requires_confirmation": bool(action.get("requires_confirmation")),
                }
            )
        default_action = str(definition["default_action"])
        default_row = next((x for x in actions if x["id"] == default_action), None)
        rows.append(
            {
                "id": app_id,
                "name": definition["name"],
                "version": definition["version"],
                "default_action": default_action,
                "available": any(x["available"] for x in actions),
                "default_available": bool(default_row and default_row["available"]),
                "actions": actions,
            }
        )
    return {
        "ok": True,
        "version": APP_LAUNCHER_VERSION,
        "mode": APP_LAUNCHER_MODE,
        "server_confirmation_required": True,
        "arbitrary_shell": False,
        "arbitrary_paths": False,
        "arbitrary_arguments": False,
        "apps": rows,
    }


def _build_argv(
    action: Mapping[str, Any],
    target: pathlib.Path,
    environ: Mapping[str, str],
) -> list[str]:
    fixed_args = [str(x) for x in action.get("args", [])]
    runner = str(action["runner"])
    if runner == "cmd":
        command_processor = environ.get("COMSPEC") or r"C:\Windows\System32\cmd.exe"
        return [command_processor, "/d", "/c", str(target), *fixed_args]
    if runner == "powershell":
        system_root = environ.get("SystemRoot") or r"C:\Windows"
        powershell = pathlib.Path(system_root) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
        return [
            str(powershell),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(target),
            *fixed_args,
        ]
    raise RuntimeError("Ukjent intern Raven runner.")


def run_action(
    app_id: str,
    action_id: str,
    project_root: pathlib.Path | str,
    *,
    platform_name: str | None = None,
    popen: Callable[..., Any] = subprocess.Popen,
    environ: Mapping[str, str] | None = None,
) -> dict[str, Any]:
    definition = APP_DEFINITIONS.get(str(app_id or ""))
    if definition is None:
        return {"ok": False, "code": "unknown-app", "error": "Appen finnes ikke i Raven sin faste allowlist."}

    action = definition["actions"].get(str(action_id or ""))
    if action is None:
        return {"ok": False, "code": "unknown-action", "error": "Handlingen finnes ikke i Raven sin faste allowlist."}

    current_platform = os.name if platform_name is None else platform_name
    if current_platform != "nt":
        return {"ok": False, "code": "windows-only", "error": "Denne app-launcheren er foreløpig kun aktiv på Windows."}

    root = pathlib.Path(project_root).resolve()
    source, target = _resolve_target(action, root)
    if target is None:
        return {
            "ok": False,
            "code": "not-installed",
            "error": f"{definition['name']} / {action['label']} ble ikke funnet på en godkjent plassering.",
        }

    env = os.environ if environ is None else environ
    argv = _build_argv(action, target, env)
    kwargs: dict[str, Any] = {"cwd": str(target.parent), "shell": False}
    creation_flag = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    if creation_flag:
        kwargs["creationflags"] = creation_flag

    process = popen(argv, **kwargs)
    return {
        "ok": True,
        "id": app_id,
        "action": action_id,
        "action_label": action["label"],
        "name": definition["name"],
        "version": definition["version"],
        "source": source,
        "launched": True,
        "pid": getattr(process, "pid", None),
        "mode": APP_LAUNCHER_MODE,
    }


def launch(
    app_id: str,
    project_root: pathlib.Path | str,
    **kwargs: Any,
) -> dict[str, Any]:
    definition = APP_DEFINITIONS.get(str(app_id or ""))
    if definition is None:
        return {"ok": False, "code": "unknown-app", "error": "Appen finnes ikke i Raven sin faste allowlist."}
    return run_action(app_id, str(definition["default_action"]), project_root, **kwargs)

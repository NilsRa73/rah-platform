from __future__ import annotations

"""RAH Raven Agent Runner v0.3.0.

Registers a small read-only allowlist of project inspection and validation
capabilities. It never accepts an arbitrary command, path or shell string.
Every run requires explicit confirm=true from a local Raven page.
"""

import os
import pathlib
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Any

from flask import jsonify, request

from server_v17 import app

AGENT_RUNNER_VERSION = "0.3.0"
PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
BRIDGE_DIR = pathlib.Path(__file__).resolve().parent
MAX_OUTPUT_CHARS = 24000
DEFAULT_TIMEOUT_SECONDS = 90


@dataclass(frozen=True)
class Capability:
    id: str
    title: str
    description: str
    kind: str
    command: tuple[str, ...] | None = None
    cwd: pathlib.Path = PROJECT_ROOT
    timeout: int = DEFAULT_TIMEOUT_SECONDS


CAPABILITIES: dict[str, Capability] = {
    "project-files": Capability(
        id="project-files",
        title="List prosjektfiler",
        description="Viser en begrenset liste over prosjektfiler. Leser ikke filinnhold.",
        kind="python",
    ),
    "git-status": Capability(
        id="git-status",
        title="Les Git-status",
        description="Kjører git status --short --branch i RAH-prosjektet.",
        kind="command",
        command=("git", "status", "--short", "--branch"),
    ),
    "test-council": Capability(
        id="test-council",
        title="Test Raven Council",
        description="Kjører den statiske Node-valideringen for Raven Council.",
        kind="command",
        command=("node", "tests/raven-council.test.mjs"),
    ),
    "test-vision-core": Capability(
        id="test-vision-core",
        title="Test Raven Vision Core",
        description="Kjører den statiske Node-valideringen for Vision Core.",
        kind="command",
        command=("node", "tests/raven-vision-core.test.mjs"),
    ),
    "test-core-demo": Capability(
        id="test-core-demo",
        title="Test Raven Core Demo",
        description="Kjører ende-til-ende-valideringen for Demo Runner.",
        kind="command",
        command=("node", "tests/raven-core-demo.test.mjs"),
    ),
    "test-mission-engine": Capability(
        id="test-mission-engine",
        title="Test Mission Engine",
        description="Kjører den eksisterende Mission Engine-valideringen.",
        kind="command",
        command=("node", "tests/mission-engine.test.mjs"),
    ),
    "test-bridge-security": Capability(
        id="test-bridge-security",
        title="Test Bridge-sikkerhet",
        description="Kjører lokal-origin-, Council-proxy-, Vision-, Case- og Agent-sikkerhetstest.",
        kind="command",
        command=("__PYTHON__", "test_raven_bridge_security.py"),
        cwd=BRIDGE_DIR,
        timeout=120,
    ),
}

EXCLUDED_PARTS = {
    ".git",
    ".venv",
    "node_modules",
    "__pycache__",
    ".pytest_cache",
    "dist",
    "build",
}
ALLOWED_FILE_SUFFIXES = {
    ".html", ".js", ".mjs", ".py", ".md", ".txt", ".yml", ".yaml",
    ".json", ".sql", ".bat", ".ps1", ".vbs", ".toml",
}


def _command_available(capability: Capability) -> tuple[bool, str | None]:
    if capability.kind != "command" or not capability.command:
        return True, None
    executable = capability.command[0]
    if executable == "__PYTHON__":
        return pathlib.Path(sys.executable).exists(), sys.executable
    resolved = shutil.which(executable)
    return bool(resolved), resolved


def _capability_dict(capability: Capability) -> dict[str, Any]:
    available, executable = _command_available(capability)
    return {
        "id": capability.id,
        "title": capability.title,
        "description": capability.description,
        "kind": capability.kind,
        "available": available,
        "executable": executable,
        "read_only": True,
        "requires_confirmation": True,
        "timeout_seconds": capability.timeout,
    }


def _project_files(limit: int = 180) -> list[str]:
    output: list[str] = []
    for path in PROJECT_ROOT.rglob("*"):
        try:
            relative = path.relative_to(PROJECT_ROOT)
        except ValueError:
            continue
        if any(part in EXCLUDED_PARTS for part in relative.parts):
            continue
        if not path.is_file() or path.suffix.lower() not in ALLOWED_FILE_SUFFIXES:
            continue
        output.append(relative.as_posix())
    return sorted(output, key=str.casefold)[: max(1, min(500, int(limit or 180)))]


def _run_command(capability: Capability) -> dict[str, Any]:
    if not capability.command:
        raise RuntimeError("Capability mangler kommando.")
    command = list(capability.command)
    if command[0] == "__PYTHON__":
        command[0] = sys.executable
    else:
        resolved = shutil.which(command[0])
        if not resolved:
            raise FileNotFoundError(f"{command[0]} ble ikke funnet i PATH.")
        command[0] = resolved

    started = time.monotonic()
    completed = subprocess.run(
        command,
        cwd=str(capability.cwd),
        shell=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=capability.timeout,
        env=os.environ.copy(),
        check=False,
    )
    duration_ms = round((time.monotonic() - started) * 1000)
    stdout = (completed.stdout or "")[:MAX_OUTPUT_CHARS]
    stderr = (completed.stderr or "")[:MAX_OUTPUT_CHARS]
    return {
        "ok": completed.returncode == 0,
        "exit_code": completed.returncode,
        "stdout": stdout,
        "stderr": stderr,
        "duration_ms": duration_ms,
        "command": [pathlib.Path(command[0]).name, *command[1:]],
        "cwd": str(capability.cwd),
    }


@app.get("/agent/capabilities")
def agent_capabilities():
    return jsonify(
        {
            "ok": True,
            "version": AGENT_RUNNER_VERSION,
            "mode": "read-only-allowlist",
            "project_root": str(PROJECT_ROOT),
            "capabilities": [_capability_dict(item) for item in CAPABILITIES.values()],
            "arbitrary_commands": False,
            "file_writes": False,
            "automatic_execution": False,
        }
    )


@app.post("/agent/run")
def agent_run():
    payload = request.get_json(silent=True) or {}
    capability_id = str(payload.get("capability") or "").strip()
    if payload.get("confirm") is not True:
        return jsonify(
            {
                "ok": False,
                "error": "Eksplisitt confirm=true kreves for hver Agent Runner-kjøring.",
            }
        ), 400
    capability = CAPABILITIES.get(capability_id)
    if capability is None:
        return jsonify(
            {
                "ok": False,
                "error": "Capability er ikke i den lokale allowlisten.",
                "arbitrary_commands": False,
            }
        ), 403

    started_at = time.time()
    try:
        if capability.id == "project-files":
            files = _project_files()
            result = {
                "ok": True,
                "files": files,
                "count": len(files),
                "stdout": "\n".join(files),
                "stderr": "",
                "duration_ms": round((time.time() - started_at) * 1000),
                "command": None,
                "cwd": str(PROJECT_ROOT),
            }
        else:
            result = _run_command(capability)
        status = 200 if result.get("ok") else 422
        return jsonify(
            {
                **result,
                "capability": _capability_dict(capability),
                "read_only": True,
                "files_modified": False,
                "tools_executed": [capability.id],
                "automatic_actions": False,
            }
        ), status
    except subprocess.TimeoutExpired:
        return jsonify(
            {
                "ok": False,
                "error": f"Kjøringen passerte tidsgrensen på {capability.timeout} sekunder.",
                "capability": _capability_dict(capability),
                "read_only": True,
                "files_modified": False,
                "automatic_actions": False,
            }
        ), 504
    except Exception as exc:
        return jsonify(
            {
                "ok": False,
                "error": str(exc),
                "capability": _capability_dict(capability),
                "read_only": True,
                "files_modified": False,
                "automatic_actions": False,
            }
        ), 500

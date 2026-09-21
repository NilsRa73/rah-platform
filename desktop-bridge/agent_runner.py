from __future__ import annotations

"""RAH Raven Agent Runner v0.3.0.

Registers a small read-only allowlist of project inspection and validation
capabilities. It never accepts an arbitrary command, path or shell string.
Every run requires either explicit confirm=true from a local Raven page or a
short-lived, single-use approval token issued by the local AnythingLLM approval
gate. The approval gate can authorize only capabilities in this read-only
allowlist; it never enables arbitrary shell strings or file writes.
"""

import ctypes
import os
import pathlib
import platform
import secrets
import shutil
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from typing import Any

from flask import jsonify, request

from server_v17 import APP_VERSION as BRIDGE_VERSION, PORT as BRIDGE_PORT, app
import hovedpc_local_status
import rah_file_index
import anythingllm_approval

AGENT_RUNNER_VERSION = "0.3.0"
PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
BRIDGE_DIR = pathlib.Path(__file__).resolve().parent
MAX_OUTPUT_CHARS = 24000
DEFAULT_TIMEOUT_SECONDS = 90
CHATGPT_DRAFT_TTL_SECONDS = 600
CHATGPT_DRAFT_PREFIX = "se på quick check\n\n"
_CHATGPT_DRAFT_LOCK = threading.Lock()
_CHATGPT_PENDING_DRAFT: dict[str, Any] | None = None


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
    "system-inventory": Capability(
        id="system-inventory",
        title="HOVED-PC systeminventar",
        description="Leser trygg lokal maskinstatus og detaljert hardware-profil: system, hovedkort, BIOS, CPU, RAM-moduler/spor, GPU, PCIe-spor, lagring, nettverk og monitorer.",
        kind="python",
        timeout=20,
    ),
    "hardware-registry": Capability(
        id="hardware-registry",
        title="RAH hardware-register",
        description="Leser kun det faste lokale hardware-registeret under C:\\RAH\\HardwareRegistry. Ingen vilkårlig sti eller filskriving.",
        kind="python",
        timeout=20,
    ),
    "hovedpc-local-status": Capability(
        id="hovedpc-local-status",
        title="HOVED-PC lokalstatus",
        description="Samler skrivebeskyttet lokalstatus: disk, lokale nettverksadresser, Raven-prosesser, faste RAH-røtter, Chronicle-status og tilgjengelige Raven-verktøy. Leser ikke filinnhold.",
        kind="python",
        timeout=20,
    ),
    "rah-file-index": Capability(
        id="rah-file-index",
        title="RAH filindeks",
        description="Indekserer kun metadata under faste RAH-røtter. Viser relative navn/type/størrelse/tid, leser ikke filinnhold, følger ikke symlinks og godtar ingen vilkårlig sti.",
        kind="python",
        timeout=20,
    ),
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
        "supports_anythingllm_approval": capability.id in anythingllm_approval.AUTO_APPROVABLE_CAPABILITIES,
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


def _total_memory_bytes() -> int | None:
    if sys.platform == "win32":
        class MemoryStatusEx(ctypes.Structure):
            _fields_ = [
                ("dwLength", ctypes.c_ulong),
                ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong),
                ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong),
                ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
            ]

        status = MemoryStatusEx()
        status.dwLength = ctypes.sizeof(MemoryStatusEx)
        try:
            if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
                return int(status.ullTotalPhys)
        except Exception:
            return None
        return None

    try:
        page_size = int(os.sysconf("SC_PAGE_SIZE"))
        page_count = int(os.sysconf("SC_PHYS_PAGES"))
        return page_size * page_count
    except (AttributeError, OSError, TypeError, ValueError):
        return None


def _gpu_names() -> list[str]:
    if sys.platform != "win32":
        return []
    executable = shutil.which("powershell.exe") or shutil.which("powershell") or shutil.which("pwsh")
    if not executable:
        return []
    fixed_script = "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name"
    try:
        completed = subprocess.run(
            [executable, "-NoProfile", "-NonInteractive", "-Command", fixed_script],
            shell=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=8,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    if completed.returncode != 0:
        return []
    return [line.strip() for line in (completed.stdout or "").splitlines() if line.strip()][:8]


def _monitor_inventory() -> tuple[list[dict[str, int]], str | None]:
    try:
        import mss
        with mss.mss() as sct:
            monitors = [
                {
                    "index": index,
                    "left": int(monitor["left"]),
                    "top": int(monitor["top"]),
                    "width": int(monitor["width"]),
                    "height": int(monitor["height"]),
                }
                for index, monitor in enumerate(sct.monitors[1:], start=1)
            ]
        return monitors, None
    except Exception as exc:
        return [], str(exc)[:240]


def _windows_hardware_profile() -> tuple[dict[str, Any] | None, str | None]:
    if platform.system().lower() != "windows":
        return None, "Detailed hardware profile is currently Windows-only."
    script = PROJECT_ROOT / "RAH-HARDWARE-INVENTORY.ps1"
    if not script.is_file():
        return None, f"Missing fixed hardware inventory script: {script.name}"
    windir = pathlib.Path(os.environ.get("WINDIR") or r"C:\Windows")
    powershell = windir / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
    if not powershell.is_file():
        return None, "Windows PowerShell executable not found."
    try:
        completed = subprocess.run(
            [
                str(powershell),
                "-NoLogo",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(script),
                "-Json",
            ],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            timeout=18,
            check=False,
        )
    except Exception as exc:
        return None, str(exc)[:400]
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "hardware collector failed").strip()
        return None, detail[:500]
    try:
        profile = __import__("json").loads(completed.stdout)
    except Exception as exc:
        return None, f"Hardware profile JSON invalid: {str(exc)[:240]}"
    if not isinstance(profile, dict) or profile.get("schema") != "rah-hardware-profile-v1":
        return None, "Hardware profile schema invalid."
    if (profile.get("dataQuality") or {}).get("serialNumbersStored") is not False:
        return None, "Hardware profile privacy contract failed."
    return profile, None


def _hardware_registry() -> dict[str, Any]:
    started = time.monotonic()
    if platform.system().lower() != "windows":
        registry_path = None
        registry = {"schema": "rah-hardware-registry-v1", "version": 1, "devices": []}
        note = "Hardware registry is currently Windows-only."
    else:
        registry_path = pathlib.Path(r"C:\RAH\HardwareRegistry\registry.json")
        if registry_path.is_file():
            if registry_path.stat().st_size > 2 * 1024 * 1024:
                raise RuntimeError("Hardware registry exceeds the fixed 2 MiB read limit.")
            import json
            registry = json.loads(registry_path.read_text(encoding="utf-8"))
            if not isinstance(registry, dict) or registry.get("schema") != "rah-hardware-registry-v1":
                raise RuntimeError("Hardware registry schema invalid.")
            note = ""
        else:
            registry = {"schema": "rah-hardware-registry-v1", "version": 1, "devices": []}
            note = "Registry file not created yet."

    devices = registry.get("devices") if isinstance(registry.get("devices"), list) else []
    lines = ["RAH HARDWARE REGISTRY", f"DEVICES: {len(devices)}"]
    for device in devices[:50]:
        if isinstance(device, dict):
            summary = device.get("summary") or {}
            lines.append(
                f"- {device.get('hostname') or device.get('id')}: "
                f"{summary.get('model') or 'unknown model'} | "
                f"RAM {summary.get('ramGB')} GB | "
                f"GPU {', '.join(summary.get('gpus') or []) or 'unknown'}"
            )
    if note:
        lines.append(f"NOTE: {note}")
    return {
        "ok": True,
        "registry": registry,
        "device_count": len(devices),
        "stdout": "\n".join(lines),
        "stderr": "",
        "duration_ms": round((time.monotonic() - started) * 1000),
        "command": None,
        "cwd": str(PROJECT_ROOT),
        "read_only": True,
        "fixed_path": str(registry_path) if registry_path else None,
    }


def _system_inventory() -> dict[str, Any]:
    started = time.monotonic()
    memory_bytes = _total_memory_bytes()
    monitors, monitor_error = _monitor_inventory()
    routes = {rule.rule for rule in app.url_map.iter_rules()}
    gpus = _gpu_names()
    hardware_profile, hardware_profile_error = _windows_hardware_profile()
    cpu_name = platform.processor().strip() or os.environ.get("PROCESSOR_IDENTIFIER", "").strip() or platform.machine().strip() or "Ukjent CPU"
    inventory = {
        "hostname": platform.node() or os.environ.get("COMPUTERNAME") or "ukjent",
        "os": {
            "system": platform.system() or "ukjent",
            "release": platform.release() or "",
            "version": platform.version() or "",
            "architecture": platform.machine() or "",
        },
        "cpu": {"name": cpu_name, "logical_cores": os.cpu_count()},
        "ram_gb": round(memory_bytes / (1024 ** 3), 1) if memory_bytes else None,
        "gpus": gpus,
        "monitors": monitors,
        "monitor_count": len(monitors),
        "monitor_probe_error": monitor_error,
        "hardware_profile": hardware_profile,
        "hardware_profile_error": hardware_profile_error,
        "raven_bridge": {
            "version": BRIDGE_VERSION,
            "port": BRIDGE_PORT,
            "health_route": "/health" in routes,
            "agent_route": "/agent/run" in routes,
            "vision_monitor_route": "/capture/monitors" in routes,
        },
        "safety": {
            "mode": "read-only-allowlist",
            "read_only": True,
            "arbitrary_commands": False,
            "file_writes": False,
            "automatic_execution": False,
        },
    }
    lines = [
        "RAH RAVEN - LOCAL SYSTEM INVENTORY",
        f"HOSTNAME : {inventory['hostname']}",
        f"OS       : {inventory['os']['system']} {inventory['os']['release']} ({inventory['os']['architecture']})",
        f"CPU      : {inventory['cpu']['name']}",
        f"CORES    : {inventory['cpu']['logical_cores']} logical",
        f"RAM      : {inventory['ram_gb'] if inventory['ram_gb'] is not None else 'ukjent'} GB",
        f"GPU      : {', '.join(gpus) if gpus else 'ikke rapportert'}",
        f"MONITORS : {len(monitors)}",
        f"HARDWARE : {'DETAILED PROFILE OK' if hardware_profile else 'BASE INVENTORY ONLY'}",
    ]
    for monitor in monitors:
        lines.append(f"  M{monitor['index']}: {monitor['width']}x{monitor['height']} @ {monitor['left']},{monitor['top']}")
    lines.extend([
        f"BRIDGE   : v{BRIDGE_VERSION} port {BRIDGE_PORT} | health={'OK' if inventory['raven_bridge']['health_route'] else 'MISSING'} | vision={'OK' if inventory['raven_bridge']['vision_monitor_route'] else 'MISSING'}",
        "SAFETY   : READ ONLY | arbitrary commands OFF | file writes OFF | auto execution OFF",
    ])
    if monitor_error:
        lines.append(f"MONITOR NOTE: {monitor_error}")
    return {
        "ok": True,
        "inventory": inventory,
        "stdout": "\n".join(lines),
        "stderr": "",
        "duration_ms": round((time.monotonic() - started) * 1000),
        "command": None,
        "cwd": str(PROJECT_ROOT),
    }


def _hovedpc_local_status() -> dict[str, Any]:
    started = time.monotonic()
    result = hovedpc_local_status.collect_status(
        capability_ids=CAPABILITIES.keys(),
        project_root=PROJECT_ROOT,
        bridge_version=BRIDGE_VERSION,
        bridge_port=BRIDGE_PORT,
    )
    result["duration_ms"] = round((time.monotonic() - started) * 1000)
    return result


def _rah_file_index() -> dict[str, Any]:
    return rah_file_index.collect_index()


def _queue_quick_check_draft() -> dict[str, Any]:
    global _CHATGPT_PENDING_DRAFT
    result = _system_inventory()
    now = time.time()
    text = (CHATGPT_DRAFT_PREFIX + str(result.get("stdout") or "")).strip()
    item = {
        "id": secrets.token_hex(12),
        "kind": "quick-check",
        "text": text[:12000],
        "created_at": now,
        "expires_at": now + CHATGPT_DRAFT_TTL_SECONDS,
        "auto_send": False,
    }
    with _CHATGPT_DRAFT_LOCK:
        _CHATGPT_PENDING_DRAFT = item
    return item


def _get_pending_draft() -> dict[str, Any] | None:
    global _CHATGPT_PENDING_DRAFT
    now = time.time()
    with _CHATGPT_DRAFT_LOCK:
        if _CHATGPT_PENDING_DRAFT and float(_CHATGPT_PENDING_DRAFT.get("expires_at") or 0) <= now:
            _CHATGPT_PENDING_DRAFT = None
        return dict(_CHATGPT_PENDING_DRAFT) if _CHATGPT_PENDING_DRAFT else None


def _ack_pending_draft(item_id: str) -> bool:
    global _CHATGPT_PENDING_DRAFT
    with _CHATGPT_DRAFT_LOCK:
        if not _CHATGPT_PENDING_DRAFT or _CHATGPT_PENDING_DRAFT.get("id") != item_id:
            return False
        _CHATGPT_PENDING_DRAFT = None
        return True


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
    return {
        "ok": completed.returncode == 0,
        "exit_code": completed.returncode,
        "stdout": (completed.stdout or "")[:MAX_OUTPUT_CHARS],
        "stderr": (completed.stderr or "")[:MAX_OUTPUT_CHARS],
        "duration_ms": round((time.monotonic() - started) * 1000),
        "command": [pathlib.Path(command[0]).name, *command[1:]],
        "cwd": str(capability.cwd),
    }


@app.get("/agent/capabilities")
def agent_capabilities():
    return jsonify({
        "ok": True,
        "version": AGENT_RUNNER_VERSION,
        "mode": "read-only-allowlist",
        "project_root": str(PROJECT_ROOT),
        "capabilities": [_capability_dict(item) for item in CAPABILITIES.values()],
        "arbitrary_commands": False,
        "file_writes": False,
        "automatic_execution": False,
        "anythingllm_approval": anythingllm_approval._safe_status(),
    })


@app.post("/agent/chatgpt/quick-check")
def agent_chatgpt_quick_check():
    payload = request.get_json(silent=True) or {}
    if payload.get("confirm") is not True:
        return jsonify({"ok": False, "error": "Eksplisitt confirm=true kreves for Quick Check til ChatGPT."}), 400
    item = _queue_quick_check_draft()
    return jsonify({
        "ok": True,
        "queued": True,
        "id": item["id"],
        "expires_at": item["expires_at"],
        "delivery": "composer-draft-only",
        "read_only": True,
        "files_modified": False,
        "automatic_actions": False,
        "auto_send": False,
    })


@app.get("/agent/chatgpt/pending")
def agent_chatgpt_pending():
    item = _get_pending_draft()
    if not item:
        return jsonify({"ok": True, "pending": False})
    return jsonify({"ok": True, "pending": True, "item": item})


@app.post("/agent/chatgpt/ack")
def agent_chatgpt_ack():
    payload = request.get_json(silent=True) or {}
    item_id = str(payload.get("id") or "").strip()
    if not item_id:
        return jsonify({"ok": False, "error": "Mangler Quick Check draft-id."}), 400
    if not _ack_pending_draft(item_id):
        return jsonify({"ok": False, "error": "Quick Check-utkastet finnes ikke eller er allerede kvittert."}), 404
    return jsonify({"ok": True, "acked": True, "id": item_id, "auto_send": False})


@app.post("/agent/run")
def agent_run():
    payload = request.get_json(silent=True) or {}
    capability_id = str(payload.get("capability") or "").strip()
    capability = CAPABILITIES.get(capability_id)
    if capability is None:
        return jsonify({
            "ok": False,
            "error": "Capability er ikke i den lokale allowlisten.",
            "arbitrary_commands": False,
        }), 403

    manual_confirm = payload.get("confirm") is True
    approval_id = str(payload.get("approval_id") or "").strip()
    supports_anythingllm = capability_id in anythingllm_approval.AUTO_APPROVABLE_CAPABILITIES
    approved_by_anythingllm = False
    if not manual_confirm and approval_id and supports_anythingllm:
        approved_by_anythingllm = anythingllm_approval.consume_approval(
            approval_id,
            capability_id,
        )
    if not manual_confirm and not approved_by_anythingllm:
        return jsonify({
            "ok": False,
            "error": (
                "Kjøringen krever enten confirm=true eller en gyldig "
                "AnythingLLM-godkjenning for samme capability."
            ),
            "anythingllm_approval_supported": supports_anythingllm,
            "arbitrary_commands": False,
        }), 400

    approval_source = "manual-confirm" if manual_confirm else "anythingllm"
    started_at = time.time()
    try:
        if capability.id == "system-inventory":
            result = _system_inventory()
        elif capability.id == "hardware-registry":
            result = _hardware_registry()
        elif capability.id == "hovedpc-local-status":
            result = _hovedpc_local_status()
        elif capability.id == "rah-file-index":
            result = _rah_file_index()
        elif capability.id == "project-files":
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
        return jsonify({
            **result,
            "capability": _capability_dict(capability),
            "read_only": True,
            "files_modified": False,
            "tools_executed": [capability.id],
            "automatic_actions": False,
            "approval_source": approval_source,
        }), status
    except subprocess.TimeoutExpired:
        return jsonify({
            "ok": False,
            "error": f"Kjøringen passerte tidsgrensen på {capability.timeout} sekunder.",
            "capability": _capability_dict(capability),
            "read_only": True,
            "files_modified": False,
            "automatic_actions": False,
            "approval_source": approval_source,
        }), 504
    except Exception as exc:
        return jsonify({
            "ok": False,
            "error": str(exc),
            "capability": _capability_dict(capability),
            "read_only": True,
            "files_modified": False,
            "automatic_actions": False,
            "approval_source": approval_source,
        }), 500

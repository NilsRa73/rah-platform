from __future__ import annotations

"""Read-only HOVED-PC local status collector for Raven Agent Runner.

The collector uses only fixed local probes. It accepts no paths, commands, hosts,
or other user-controlled execution input and never reads file contents.
"""

import csv
import os
import pathlib
import platform
import shutil
import socket
import subprocess
from io import StringIO
from typing import Any, Iterable

STATUS_VERSION = "1.0.0"
RAVEN_IMAGE_NAME = "RAH-Raven-Vision.exe"


def _gb(value: int) -> float:
    return round(value / (1024 ** 3), 1)


def _local_addresses() -> list[str]:
    values: set[str] = set()
    hostname = platform.node() or socket.gethostname()
    try:
        for family, _socktype, _proto, _canon, sockaddr in socket.getaddrinfo(hostname, None):
            if family not in {socket.AF_INET, socket.AF_INET6} or not sockaddr:
                continue
            address = str(sockaddr[0]).split("%", 1)[0].strip()
            if address and address not in {"127.0.0.1", "::1"}:
                values.add(address)
    except OSError:
        pass
    return sorted(values, key=lambda value: (":" in value, value.casefold()))[:24]


def _disk_status() -> dict[str, Any]:
    base = pathlib.Path(os.getenv("LOCALAPPDATA") or pathlib.Path.home()).expanduser()
    usage = shutil.disk_usage(base)
    return {
        "path": str(base),
        "total_gb": _gb(usage.total),
        "used_gb": _gb(usage.used),
        "free_gb": _gb(usage.free),
    }


def _root_summary(path: pathlib.Path, label: str) -> dict[str, Any]:
    exists = path.exists()
    files = 0
    directories = 0
    error: str | None = None
    if exists and path.is_dir():
        try:
            for child in path.iterdir():
                try:
                    if child.is_dir():
                        directories += 1
                    elif child.is_file():
                        files += 1
                except OSError:
                    continue
        except OSError as exc:
            error = str(exc)[:180]
    return {
        "label": label,
        "path": str(path),
        "exists": bool(exists),
        "top_level_files": files,
        "top_level_directories": directories,
        "error": error,
        "file_names_returned": False,
        "file_contents_read": False,
    }


def _rah_roots(project_root: pathlib.Path) -> list[dict[str, Any]]:
    roots: list[tuple[pathlib.Path, str]] = []
    if os.name == "nt":
        roots.append((pathlib.Path(r"C:\RAH"), "C:\\RAH"))
    localapp = os.getenv("LOCALAPPDATA")
    if localapp:
        roots.append((pathlib.Path(localapp) / "RAH Raven", "RAH Raven LocalAppData"))
    roots.append((project_root, "RAH project root"))

    output: list[dict[str, Any]] = []
    seen: set[str] = set()
    for path, label in roots:
        key = str(path).casefold()
        if key in seen:
            continue
        seen.add(key)
        output.append(_root_summary(path, label))
    return output


def _raven_processes() -> dict[str, Any]:
    result: dict[str, Any] = {
        "current_pid": os.getpid(),
        "image": RAVEN_IMAGE_NAME,
        "matching_instances": None,
        "probe": "fixed-image-filter",
    }
    if os.name != "nt":
        result["note"] = "Windows tasklist probe not applicable in this test environment."
        return result

    try:
        completed = subprocess.run(
            ["tasklist.exe", "/FI", f"IMAGENAME eq {RAVEN_IMAGE_NAME}", "/FO", "CSV", "/NH"],
            shell=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=6,
            check=False,
        )
        rows: list[list[str]] = []
        if completed.returncode == 0:
            rows = [row for row in csv.reader(StringIO(completed.stdout or "")) if row]
        count = sum(1 for row in rows if row and row[0].strip().casefold() == RAVEN_IMAGE_NAME.casefold())
        result["matching_instances"] = count
        result["exit_code"] = completed.returncode
    except (OSError, subprocess.TimeoutExpired) as exc:
        result["error"] = str(exc)[:180]
    return result


def _chronicle_status() -> dict[str, Any]:
    try:
        import server_v17

        state = server_v17._load_state()
        session = state.get("session") if isinstance(state, dict) else None
        safe_session = None
        if isinstance(session, dict):
            safe_session = {
                "project": str(session.get("project") or "")[:160],
                "mode": str(session.get("mode") or "")[:40],
                "started_at": session.get("started_at"),
            }
        return {
            "available": True,
            "recording": bool(state.get("recording")),
            "paused": bool(state.get("paused")),
            "session": safe_session,
            "event_count": int(server_v17._event_count()),
            "storage_path": str(server_v17.DATA_DIR),
            "foreground_window_read": False,
        }
    except Exception as exc:
        return {
            "available": False,
            "error": str(exc)[:180],
            "foreground_window_read": False,
        }


def collect_status(*, capability_ids: Iterable[str], project_root: pathlib.Path, bridge_version: str, bridge_port: int) -> dict[str, Any]:
    addresses = _local_addresses()
    disk = _disk_status()
    roots = _rah_roots(project_root)
    processes = _raven_processes()
    chronicle = _chronicle_status()
    tools = sorted({str(value) for value in capability_ids if str(value).strip()}, key=str.casefold)

    status = {
        "version": STATUS_VERSION,
        "hostname": platform.node() or os.environ.get("COMPUTERNAME") or "ukjent",
        "local_addresses": addresses,
        "disk": disk,
        "raven_processes": processes,
        "rah_roots": roots,
        "chronicle": chronicle,
        "tools": tools,
        "bridge": {"version": bridge_version, "port": bridge_port},
        "safety": {
            "mode": "read-only-allowlist",
            "read_only": True,
            "arbitrary_paths": False,
            "arbitrary_commands": False,
            "file_names_returned": False,
            "file_contents_read": False,
            "file_writes": False,
            "automatic_execution": False,
            "network_scan": False,
            "external_network_requests": False,
        },
    }

    address_text = ", ".join(addresses) if addresses else "ingen lokale ikke-loopback-adresser rapportert"
    process_count = processes.get("matching_instances")
    process_text = "ikke tilgjengelig" if process_count is None else str(process_count)
    chronicle_text = (
        f"recording={chronicle.get('recording')} | paused={chronicle.get('paused')} | events={chronicle.get('event_count')}"
        if chronicle.get("available")
        else f"utilgjengelig: {chronicle.get('error', 'ukjent')}"
    )

    lines = [
        "RAH RAVEN - HOVED-PC LOCAL STATUS",
        f"HOSTNAME     : {status['hostname']}",
        f"NETWORK      : {address_text}",
        f"DISK         : {disk['free_gb']} GB free / {disk['total_gb']} GB total",
        f"RAVEN PROC   : current pid={processes.get('current_pid')} | {RAVEN_IMAGE_NAME} instances={process_text}",
        "RAH ROOTS    :",
    ]
    for root in roots:
        lines.append(
            f"  {root['label']}: exists={root['exists']} | dirs={root['top_level_directories']} | files={root['top_level_files']} | {root['path']}"
        )
    lines.extend(
        [
            f"CHRONICLE    : {chronicle_text}",
            f"TOOLS        : {', '.join(tools)}",
            f"BRIDGE       : v{bridge_version} port {bridge_port}",
            "SAFETY       : READ ONLY | no file names/content | arbitrary paths OFF | arbitrary commands OFF | file writes OFF | auto execution OFF | network scan OFF",
        ]
    )

    return {
        "ok": True,
        "local_status": status,
        "stdout": "\n".join(lines),
        "stderr": "",
        "command": None,
        "cwd": str(project_root),
    }

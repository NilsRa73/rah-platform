#!/usr/bin/env python3
"""RAH PR #477 HOVED-PC staging preflight. Read-only; stdout JSON only.

No directory creation, file writes, service changes, process termination, EXE
launch, network calls, restore-point changes or deployment.
The optional --candidate points to an existing EXE to SHA-256; the GitHub
Actions ZIP digest is NOT an EXE digest and is never compared to an EXE.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

PORT = 18765
EXPECTED_BRIDGE_VERSION = "1.7.1"
ROOTS = [
    Path(r"C:\RAH\Tools\RavenBridgeKnownGood"),
    Path(r"C:\RAH\_stage"),
    Path(r"C:\rah\_stage"),
]
BACKUP_HINTS = [
    Path(r"C:\RAH\Backups"),
    Path(r"C:\RAH\Backup"),
    Path(r"C:\RAH\Tools\RavenBridgeKnownGood"),
]
KNOWN_ASSETS = [
    "desktop-bridge/raven_bridge.py",
    "RAH-RAVEN-COMMAND-WHEEL.html",
    "RAH-RAVEN-AGENT-RUNNER.html",
    "RAH-RAVEN-DOCTOR.html",
    "RAH-RAVEN-VISION-LOCAL.html",
]


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            sha.update(block)
    return sha.hexdigest()


def metadata(path: Path) -> dict:
    record = {"path": str(path), "exists": False, "is_file": False, "is_dir": False}
    try:
        record["exists"] = path.exists()
        record["is_file"] = path.is_file()
        record["is_dir"] = path.is_dir()
        if record["is_file"]:
            record["size_bytes"] = path.stat().st_size
    except OSError as exc:
        record["error"] = type(exc).__name__
    return record


def powershell_json(command: str):
    """Read-only CIM/TCP queries; command is fixed, never user-supplied."""
    args = [
        "powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive",
        "-Command", "$ErrorActionPreference='Stop'; " + command,
    ]
    try:
        completed = subprocess.run(args, capture_output=True, text=True, timeout=15,
                                   check=False, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        if completed.returncode:
            return None, "powershell_query_failed"
        return json.loads(completed.stdout.strip() or "null"), None
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None, "powershell_query_unavailable"


def inspect_port_and_process() -> dict:
    # Both commands inspect existing state only and never touch the socket.
    ports, port_error = powershell_json(
        "Get-NetTCPConnection -LocalPort 18765 -State Listen -ErrorAction SilentlyContinue "
        "| Select-Object LocalAddress,LocalPort,OwningProcess "
        "| ConvertTo-Json -Compress"
    )
    items = ports if isinstance(ports, list) else ([ports] if isinstance(ports, dict) else [])
    # No PID filter is interpolated into PowerShell. Return only process name/path;
    # do not include full command lines (which can expose secrets).
    processes, process_error = powershell_json(
        "Get-CimInstance Win32_Process "
        "| Where-Object { $_.Name -match 'python|raven|vision|goose' } "
        "| Select-Object ProcessId,Name,ExecutablePath "
        "| ConvertTo-Json -Compress"
    )
    proc_items = processes if isinstance(processes, list) else (
        [processes] if isinstance(processes, dict) else []
    )
    by_pid = {p.get("ProcessId"): p for p in proc_items}
    listeners = [{
        "address": item.get("LocalAddress"),
        "port": item.get("LocalPort"),
        "pid": item.get("OwningProcess"),
        "process": by_pid.get(item.get("OwningProcess")),
    } for item in items]
    return {
        "listeners": listeners,
        "port_18765": "LISTENING" if items else ("UNKNOWN" if port_error else "NOT_LISTENING"),
        "port_query_error": port_error,
        "process_query_error": process_error,
        "matching_process_count": len(proc_items),
        "process_owner_resolved": bool(items) and all(
            item.get("process") is not None for item in listeners
        ),
    }


def collect(candidate: Path | None, project_root: Path | None) -> dict:
    result = {
        "schema": "rah-pr477-staging-preflight-v1",
        "mode": "READ_ONLY",
        "machine": platform.node(),
        "system": platform.system(),
        "files_modified": False,
        "services_modified": False,
        "bridge_stopped": False,
        "candidate_started": False,
        "rollback_ready": False,
        "expected_existing_bridge_version": EXPECTED_BRIDGE_VERSION,
        "port": inspect_port_and_process(),
        "paths": {"known_roots": [metadata(p) for p in ROOTS],
                  "backup_locations": [metadata(p) for p in BACKUP_HINTS],
                  "project_root": metadata(project_root) if project_root else None,
                  "project_assets": [
                      metadata(project_root / item) for item in KNOWN_ASSETS
                  ] if project_root else []},
        "candidate": None,
        "acceptance": {
            "backup_verified": False,
            "active_exe_identified": False,
            "candidate_hash_verified_against_trusted_manifest": False,
            "live_navigation_tested": False,
            "deployment_approved": False,
        },
    }
    if candidate:
        record = metadata(candidate)
        if record["is_file"] and candidate.suffix.lower() == ".exe":
            try:
                record["sha256"] = digest(candidate)
            except OSError as exc:
                record["hash_error"] = type(exc).__name__
        elif record["is_file"]:
            record["hash_error"] = "only_exe_candidate_accepted"
        result["candidate"] = record
    # A directory existing is not proof that its contents are a verified backup.
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Read-only RAH PR477 preflight; JSON to stdout")
    parser.add_argument("--candidate", type=Path, help="existing candidate EXE to hash")
    parser.add_argument("--project-root", type=Path, help="existing RAH project root to inspect")
    args = parser.parse_args(argv)
    if os.name != "nt":
        print(json.dumps({"ok": False, "reason": "WINDOWS_ONLY", "files_modified": False}))
        return 2
    report = collect(args.candidate, args.project_root)
    report["ok"] = True
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

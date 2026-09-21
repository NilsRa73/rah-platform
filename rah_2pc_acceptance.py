#!/usr/bin/env python3
"""RAH Raven 2-PC Grid real-hardware acceptance validator v1."""
from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import socket
import sys
from typing import Any

SCHEMA = "rah-2pc-real-hardware-acceptance-v1"
INPUT_SCHEMA = "rah-2pc-inventory-proof-v1"
EXPECTED_HOST = "DESKTOP-R2HTAGJ"


class AcceptanceError(RuntimeError):
    pass


def default_input() -> Path:
    if os.name == "nt":
        return Path(r"C:\RAH\2PCProof\results\last-inventory.json")
    return Path("last-inventory.json")


def default_output() -> Path:
    if os.name == "nt":
        return Path(r"C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json")
    return Path("REAL-HARDWARE-ACCEPTANCE.json")


def _dict(value: Any, name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise AcceptanceError(f"{name} missing or invalid.")
    return value


def _private_target(host: str) -> bool:
    host = str(host or "").strip()
    if not host:
        return False
    try:
        ip = ipaddress.ip_address(host)
        return bool(ip.is_private or ip.is_loopback)
    except ValueError:
        pass
    # Hostnames are allowed only if they resolve to RFC1918/loopback.
    try:
        infos = socket.getaddrinfo(host, None, family=socket.AF_INET)
    except OSError:
        # A stored hostname may no longer resolve later; the original result is still
        # accepted if it is the fixed expected Lenovo hostname.
        return host.upper() == EXPECTED_HOST
    addrs = {ipaddress.ip_address(item[4][0]) for item in infos}
    return bool(addrs) and all(ip.is_private or ip.is_loopback for ip in addrs)


def validate(payload: Any, expected_host: str = EXPECTED_HOST) -> dict[str, Any]:
    p = _dict(payload, "inventory result")
    if p.get("schema") != INPUT_SCHEMA:
        raise AcceptanceError("Unexpected inventory result schema.")
    if p.get("status") != "PASS":
        raise AcceptanceError("Inventory result is not PASS.")
    if p.get("protocol") != "rah-node-raven-status-v1":
        raise AcceptanceError("Unexpected Node protocol.")
    if p.get("capability") != "system-inventory":
        raise AcceptanceError("Unexpected Raven capability.")

    inventory = _dict(p.get("inventory"), "inventory")
    safety = _dict(p.get("safety"), "safety")
    target = _dict(p.get("target"), "target")
    raven = _dict(inventory.get("raven_bridge"), "inventory.raven_bridge")

    hostname = str(inventory.get("hostname") or "").strip()
    if hostname.upper() != expected_host.upper():
        raise AcceptanceError(f"Expected Lenovo host {expected_host}, got {hostname or 'EMPTY'}.")

    if int(target.get("port") or 0) != 18766:
        raise AcceptanceError("Node target port is not fixed to 18766.")
    if not _private_target(str(target.get("host") or "")):
        raise AcceptanceError("Target is not a private LAN endpoint.")

    expected_safety = {
        "readOnly": True,
        "arbitraryCommands": False,
        "callerArguments": False,
        "tokenPersisted": False,
        "localRavenHopOnly": True,
    }
    for key, value in expected_safety.items():
        if safety.get(key) is not value:
            raise AcceptanceError(f"Safety flag failed: {key}")

    if int(raven.get("port") or 0) != 18765:
        raise AcceptanceError("Raven bridge port is not 18765.")
    if raven.get("health_route") is not True or raven.get("agent_route") is not True:
        raise AcceptanceError("Raven bridge routes did not validate.")

    return {
        "hostname": hostname,
        "targetHost": str(target.get("host") or ""),
        "targetPort": 18766,
        "ravenPort": 18765,
        "readOnly": True,
        "arbitraryCommands": False,
        "callerArguments": False,
        "tokenPersisted": False,
        "localRavenHopOnly": True,
    }


def build_report(input_path: Path, expected_host: str = EXPECTED_HOST) -> dict[str, Any]:
    raw = input_path.read_bytes()
    if len(raw) > 1024 * 1024:
        raise AcceptanceError("Inventory result is unexpectedly large.")
    payload = json.loads(raw.decode("utf-8"))
    evidence = validate(payload, expected_host=expected_host)
    return {
        "schema": SCHEMA,
        "overall": "PASS",
        "milestone": "RAH Raven 2-PC Grid v1 real-hardware acceptance",
        "source": {
            "path": str(input_path),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "schema": INPUT_SCHEMA,
        },
        "evidence": evidence,
        "gates": {
            "inventoryPass": True,
            "expectedLenovoHost": True,
            "privateLanOnly": True,
            "nodePort18766": True,
            "ravenLocalHop18765": True,
            "readOnly": True,
            "noArbitraryCommands": True,
            "noCallerArguments": True,
            "tokenNotPersisted": True,
        },
    }


def self_test() -> None:
    payload = {
        "schema": INPUT_SCHEMA,
        "clientVersion": "1.0.0",
        "status": "PASS",
        "protocol": "rah-node-raven-status-v1",
        "capability": "system-inventory",
        "target": {"host": "192.168.0.49", "port": 18766},
        "inventory": {
            "hostname": EXPECTED_HOST,
            "os": {"system": "Windows", "release": "11", "architecture": "AMD64"},
            "cpu": {"name": "CPU", "logical_cores": 8},
            "ram_gb": 16.0,
            "gpus": ["GPU"],
            "monitor_count": 2,
            "raven_bridge": {
                "version": "2.0.32",
                "port": 18765,
                "health_route": True,
                "agent_route": True,
            },
        },
        "safety": {
            "readOnly": True,
            "arbitraryCommands": False,
            "callerArguments": False,
            "tokenPersisted": False,
            "localRavenHopOnly": True,
        },
        "stdout": "ok",
    }
    evidence = validate(payload)
    assert evidence["hostname"] == EXPECTED_HOST
    assert evidence["readOnly"] is True

    broken = json.loads(json.dumps(payload))
    broken["safety"]["arbitraryCommands"] = True
    try:
        validate(broken)
    except AcceptanceError:
        pass
    else:
        raise AssertionError("Unsafe payload must fail acceptance.")

    print("PASS: RAH 2-PC real-hardware acceptance validator self-test")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default=str(default_input()))
    parser.add_argument("--output", default=str(default_output()))
    parser.add_argument("--expected-host", default=EXPECTED_HOST)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    input_path = Path(args.input)
    output_path = Path(args.output)
    try:
        if not input_path.is_file():
            raise AcceptanceError(f"Inventory result missing: {input_path}")
        report = build_report(input_path, expected_host=args.expected_host)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False))
        return 0
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())

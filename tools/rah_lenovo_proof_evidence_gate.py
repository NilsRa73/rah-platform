"""Offline, non-authoritative assessment of RAH Lenovo proof reports.

Reads only explicitly supplied, already-sanitized JSON; never connects to a
node, reads credentials, or executes local code. Producer reports cannot
cryptographically attest their own origin.
"""
from __future__ import annotations

import argparse
import ipaddress
import json
import re
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = "rah-lenovo-proof-evidence-gate-v1"
RFC1918 = (
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
)
CGNAT = ipaddress.ip_network("100.64.0.0/10")
EXPECTED_HOST = "DESKTOP-R2HTAGJ"
VALID_JOB = re.compile(r"^[A-Za-z0-9_-]{6,128}$")


def _dict(x):
    return x if isinstance(x, dict) else {}


def _target_class(value):
    if not isinstance(value, str) or len(value) > 128 or not value.strip():
        return "INVALID"
    host = value.strip()
    if host.casefold() == EXPECTED_HOST.casefold():
        return "EXPECTED_HOSTNAME_DNS_NOT_CHECKED"
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return "INVALID"
    if any(ip in net for net in RFC1918):
        return "RFC1918"
    if ip in CGNAT:
        return "TAILSCALE_CGNAT_UNSUPPORTED_BY_EXISTING_ACCEPTANCE"
    return "INVALID"


def evaluate(bundle, now=None):
    if not isinstance(bundle, dict):
        raise ValueError("Expected a JSON object")
    bridge = _dict(bundle.get("bridgeReport"))
    proof = _dict(bundle.get("inventoryProof"))
    worker = _dict(bundle.get("workerEvidence"))
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")

    reasons = []
    bridge_ok = (
        bridge.get("schema") == "rah-agent-18781-v1"
        and bridge.get("result") == "PASS_PRODUCTION_18781_AUTHENTICATED"
        and bridge.get("production18781Pass") is True
        and _dict(bridge.get("state")).get("health18781") is True
        and _dict(bridge.get("state")).get("authenticatedStatus") is True
        and _dict(bridge.get("safety")).get("execCapability") is False
    )
    if not bridge_ok:
        reasons.append("PRODUCTION_BRIDGE_18781_PROOF_MISSING")
    bridge_age_hours = None
    try:
        stamp = datetime.fromisoformat(str(bridge.get("timestamp", "")).replace("Z", "+00:00"))
        if stamp.tzinfo is None:
            raise ValueError("naive timestamp")
        bridge_age_hours = round((now - stamp).total_seconds() / 3600, 2)
        if bridge_age_hours < 0 or bridge_age_hours > 24:
            reasons.append("BRIDGE_REPORT_OLDER_THAN_24H_OR_FUTURE")
    except (ValueError, OverflowError):
        reasons.append("BRIDGE_REPORT_TIMESTAMP_UNUSABLE")

    target = _dict(proof.get("target"))
    inventory = _dict(proof.get("inventory"))
    raven = _dict(inventory.get("raven_bridge"))
    safety = _dict(proof.get("safety"))
    target_kind = _target_class(target.get("host"))
    valid_proof = (
        proof.get("schema") == "rah-2pc-inventory-proof-v1"
        and proof.get("status") == "PASS"
        and proof.get("protocol") == "rah-node-raven-status-v1"
        and proof.get("capability") == "system-inventory"
        and isinstance(proof.get("nodeJobId"), str)
        and bool(VALID_JOB.fullmatch(proof["nodeJobId"]))
        and inventory.get("hostname") == EXPECTED_HOST
        and target.get("port") == 18766
        and target_kind in ("RFC1918", "EXPECTED_HOSTNAME_DNS_NOT_CHECKED")
        and raven.get("port") == 18765
        and raven.get("health_route") is True
        and raven.get("agent_route") is True
        and all(safety.get(key) is expected for key, expected in (
            ("readOnly", True), ("arbitraryCommands", False),
            ("callerArguments", False), ("tokenPersisted", False),
            ("localRavenHopOnly", True),
        ))
    )
    if not valid_proof:
        reasons.append("LENOVO_INVENTORY_PROOF_MISSING_OR_CONTRACT_FAIL")
    if target_kind == "TAILSCALE_CGNAT_UNSUPPORTED_BY_EXISTING_ACCEPTANCE":
        reasons.append("EXISTING_2PC_ACCEPTANCE_EXPECTS_RFC1918_OR_HOSTNAME")

    # R3 report only diagnoses missing handoff files. It cannot cancel an
    # otherwise valid independent inventory, nor prove a network failure.
    worker_diag = worker.get("result") == "SAFE_DIAGNOSTIC_EXCEPTION"
    status = (
        "CANDIDATE_REPORTS_CONSISTENT_AUTH_UNVERIFIED"
        if valid_proof and bridge_ok and not reasons
        else "BLOCKED_EVIDENCE"
    )
    return {
        "schema": SCHEMA,
        "candidateStatus": status,
        "globalStableGate": "OPEN",
        "liveLenovoAuthenticatedJob": "NOT_INDEPENDENTLY_VERIFIED",
        "hmacCryptographicVerification": "NOT_PERFORMED",
        "productionModificationAuthorized": False,
        "checks": {
            "reportedBridge18781Pass": bridge_ok,
            "reportedBridgeAgeHours": bridge_age_hours,
            "sanitizedLenovoInventoryContract": valid_proof,
            "targetNetworkClass": target_kind,
            "r3DiagnosticExceptionReported": worker_diag,
        },
        "blockers": reasons + ["INDEPENDENT_HMAC_AND_JOB_ORIGIN_PROOF_REQUIRED"],
        "rawHardwareIncluded": False,
        "credentialIncluded": False,
    }


def main():
    parser = argparse.ArgumentParser(description="Offline RAH Lenovo proof gate")
    parser.add_argument("sanitized_bundle", help="JSON object: bridgeReport, inventoryProof, workerEvidence")
    args = parser.parse_args()
    raw = Path(args.sanitized_bundle).read_bytes()
    if len(raw) > 512_000:
        raise ValueError("Report bundle exceeds bounded input limit")
    payload = json.loads(raw.decode("utf-8-sig"))
    print(json.dumps(evaluate(payload), ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

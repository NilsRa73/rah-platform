"""Offline RAH Agent Bridge evidence gate. No system or network access.

Input is a JSON envelope containing *sanitized* reports, never credentials.
The gate classifies evidence; it cannot repair or validate HOVED-PC.
"""
import argparse
import json
from pathlib import Path

SCHEMA = "rah-agent-bridge-evidence-gate-v1"


def classify(reports):
    safe = reports.get("safeFix") or {}
    health = reports.get("noBrowser") or {}
    context = reports.get("context") or {}
    review = reports.get("grok") or {}
    if not all(isinstance(x, dict) for x in (safe, health, context, review)):
        raise ValueError("each report must be an object")
    agent_health = (health.get("health") or {}).get("agentBridge18781") or {}
    raven_health = (health.get("health") or {}).get("ravenBridge18765") or {}
    gemma_health = (health.get("health") or {}).get("gemma1234") or {}
    latest_tcp = ((context.get("runtime") or {}).get("local_ports") or {})
    token_checked = safe.get("token_state") not in (None, "NOT_CHECKED", "UNKNOWN")
    stage_evidenced = safe.get("first_failure_stage") in (
        "TASK_NOT_STARTED", "JOBBUS_DIRECTORY", "TOKEN_READ",
        "TOKEN_WRITE_ATTEMPT", "STATE_WRITE", "SOCKET_BIND",
    )
    identity_evidenced = safe.get("task_identity_match") in ("MATCH", "MISMATCH")
    evidence = {
        "safeFixReportedBlocked": safe.get("result") == "BLOCKED_SAFE",
        "agentBridgeHttpReachable": agent_health.get("httpResponding") is True,
        "ravenHttpPreviouslyVerified": raven_health.get("httpVerified") is True,
        "gemmaModelApiPreviouslyResponded": gemma_health.get("modelApiResponding") is True,
        "localContextTcpAgentPortReported": latest_tcp.get("18781"),
        "tokenReadableEvidenced": token_checked and safe.get("token_state") == "READABLE",
        "taskIdentityEvidenced": identity_evidenced,
        "firstFailureStageEvidenced": stage_evidenced,
        "grokReviewReported": review.get("result") == "GROK_REVIEW_DELIVERED_LOCAL_STABLE_GATE_OPEN",
    }
    blockers = []
    if not evidence["firstFailureStageEvidenced"]:
        blockers.append("EXACT_STARTUP_STAGE_NOT_OBSERVED")
    if not token_checked:
        blockers.append("EXISTING_CREDENTIAL_STATUS_NOT_CHECKED")
    if not identity_evidenced:
        blockers.append("SCHEDULED_TASK_IDENTITY_NOT_OBSERVED")
    if not evidence["agentBridgeHttpReachable"]:
        blockers.append("AGENT_BRIDGE_18781_HTTP_NOT_ACCEPTED")
    blockers.append("REAL_AUTHENTICATED_WORKER_JOB_NOT_PROVEN")
    # A reporter's statements never grant permission to run repairs.
    return {
        "schema": SCHEMA,
        "target": "HOVED-PC",
        "mode": "SANITIZED_OFFLINE_EVIDENCE_ONLY",
        "evidence": evidence,
        "blockers": blockers,
        "rootCauseProven": bool(stage_evidenced),
        "productionRepairAuthorized": False,
        "agentWorkerAccepted": False,
        "globalStableGate": "OPEN",
        "nextSafeAction": "READ_ONLY_METADATA_REVIEW_AFTER_SEPARATE_AUTHORIZATION",
        "secretsIncluded": False,
    }


def main():
    parser = argparse.ArgumentParser(description="Classify already-sanitized RAH reports")
    parser.add_argument("envelope", help="JSON: safeFix, noBrowser, context, grok")
    args = parser.parse_args()
    reports = json.loads(Path(args.envelope).read_text(encoding="utf-8-sig"))
    print(json.dumps(classify(reports), ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

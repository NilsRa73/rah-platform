"""Pure, non-secret acceptance gate for the first Grok review receipt.

Do not connect to production services, read tokens, or promote Stable Gate.
A receipt is a reported event, not independent proof of Grok identity.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path

PIN = "a9642c31e99481bdfe29ac7dc87fa3461eb05321"
RECEIPT_SCHEMA = "rah-grok-review-001-v1"


def evaluate_receipt(data: dict) -> dict:
    if not isinstance(data, dict):
        raise ValueError("expected JSON object")
    checks = {
        "schema": data.get("schema") == RECEIPT_SCHEMA,
        "source_pin": data.get("sourceCommit") == PIN,
        "review_result": data.get("result") == "GROK_REVIEW_DELIVERED_LOCAL_STABLE_GATE_OPEN",
        "review_reported": data.get("grokExecuted") is True and data.get("reportsWritten") is True,
        "read_only_mode": data.get("mode") == "READ_ONLY_GROK_HEADLESS",
        "stable_gate_open": data.get("stableGate") == "OPEN",
        "no_credentials_touched": data.get("credentialsTouched") is False,
        "no_acl_changes": data.get("tokenAclModified") is False,
        "no_code_service_changes": data.get("codeOrServicesModified") is False,
        "raven_preserved": data.get("bridge18765Before") == "HTTP_PASS"
            and data.get("bridge18765After") == "HTTP_PASS",
    }
    return {
        "schema": "rah-cross-agent-review-receipt-assessment-v1",
        "reportedReviewValid": all(checks.values()),
        "checkResults": checks,
        # An independent Drive fetch must be assessed OUTSIDE the producer report.
        "driveReadback": "EXTERNAL_VERIFICATION_REQUIRED",
        "agentBridge18781": "NOT_VERIFIED",
        "gemmaInference": "NOT_VERIFIED_BY_THIS_RECEIPT",
        "workerEndToEnd": "NOT_VERIFIED",
        "globalStableGate": "OPEN",
        "secretsIncluded": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="RAH review receipt check; no production access")
    parser.add_argument("receipt", help="sanitized receipt JSON file, not a token or raw log")
    args = parser.parse_args()
    data = json.loads(Path(args.receipt).read_text(encoding="utf-8-sig"))
    result = evaluate_receipt(data)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["reportedReviewValid"] else 2


if __name__ == "__main__":
    raise SystemExit(main())

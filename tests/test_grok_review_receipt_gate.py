"""Offline tests for the reported Grok receipt; never promote runtime readiness."""
from __future__ import annotations

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from rah_grok_review_receipt_gate import PIN, evaluate_receipt


def synthetic_receipt() -> dict:
    return {
        "schema": "rah-grok-review-001-v1",
        "sourceCommit": PIN,
        "result": "GROK_REVIEW_DELIVERED_LOCAL_STABLE_GATE_OPEN",
        "grokExecuted": True,
        "reportsWritten": True,
        "mode": "READ_ONLY_GROK_HEADLESS",
        "stableGate": "OPEN",
        "credentialsTouched": False,
        "tokenAclModified": False,
        "codeOrServicesModified": False,
        "bridge18765Before": "HTTP_PASS",
        "bridge18765After": "HTTP_PASS",
        "independentDriveReadback": "PENDING",
    }


class ReceiptGateTests(unittest.TestCase):
    def test_review_only_receipt_accepted_without_runtime_promotion(self):
        result = evaluate_receipt(synthetic_receipt())
        self.assertTrue(result["reportedReviewValid"])
        self.assertEqual(result["driveReadback"], "EXTERNAL_VERIFICATION_REQUIRED")
        self.assertEqual(result["agentBridge18781"], "NOT_VERIFIED")
        self.assertEqual(result["globalStableGate"], "OPEN")

    def test_fake_stable_gate_pass_is_rejected(self):
        doc = synthetic_receipt()
        doc["stableGate"] = "PASS"
        self.assertFalse(evaluate_receipt(doc)["reportedReviewValid"])

    def test_credential_change_is_rejected(self):
        doc = synthetic_receipt()
        doc["credentialsTouched"] = True
        self.assertFalse(evaluate_receipt(doc)["reportedReviewValid"])

    def test_source_revision_mismatch_is_rejected(self):
        doc = synthetic_receipt()
        doc["sourceCommit"] = "unverified-latest-main"
        self.assertFalse(evaluate_receipt(doc)["reportedReviewValid"])

    def test_report_content_and_secrets_are_never_echoed(self):
        doc = synthetic_receipt()
        doc["unsafeSecretExample"] = "PRIVATE-SYNTHETIC-DO-NOT-ECHO"
        result = evaluate_receipt(doc)
        self.assertNotIn(doc["unsafeSecretExample"], str(result))
        self.assertFalse(result["secretsIncluded"])


if __name__ == "__main__":
    unittest.main()

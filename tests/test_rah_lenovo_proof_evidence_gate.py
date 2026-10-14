"""Synthetic-only regression tests for the Lenovo evidence candidate."""
from datetime import datetime, timezone
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from rah_lenovo_proof_evidence_gate import evaluate

NOW = datetime(2026, 10, 14, 16, 16, tzinfo=timezone.utc)


def sample():
    return {
        "bridgeReport": {
            "schema": "rah-agent-18781-v1",
            "result": "PASS_PRODUCTION_18781_AUTHENTICATED",
            "production18781Pass": True,
            "timestamp": "2026-10-14T00:08:55Z",
            "state": {"health18781": True, "authenticatedStatus": True},
            "safety": {"execCapability": False},
        },
        "inventoryProof": {
            "schema": "rah-2pc-inventory-proof-v1",
            "status": "PASS",
            "protocol": "rah-node-raven-status-v1",
            "capability": "system-inventory",
            "nodeJobId": "synthetic-node-job-001",
            "target": {"host": "192.168.0.49", "port": 18766},
            "inventory": {
                "hostname": "DESKTOP-R2HTAGJ",
                "raven_bridge": {
                    "port": 18765, "health_route": True, "agent_route": True,
                },
            },
            "safety": {
                "readOnly": True,
                "arbitraryCommands": False,
                "callerArguments": False,
                "tokenPersisted": False,
                "localRavenHopOnly": True,
            },
        },
        "workerEvidence": {
            "result": "SAFE_DIAGNOSTIC_EXCEPTION",
            "issues": ["ONEDRIVE_ROOT_NOT_FOUND"],
        },
    }


class LenovoEvidenceTests(unittest.TestCase):
    def test_missing_lenovo_proof_stays_blocked(self):
        data = sample()
        data.pop("inventoryProof")
        result = evaluate(data, NOW)
        self.assertEqual(result["candidateStatus"], "BLOCKED_EVIDENCE")
        self.assertEqual(result["liveLenovoAuthenticatedJob"], "NOT_INDEPENDENTLY_VERIFIED")

    def test_consistent_reports_are_not_hmac_proof(self):
        result = evaluate(sample(), NOW)
        self.assertEqual(result["candidateStatus"], "CANDIDATE_REPORTS_CONSISTENT_AUTH_UNVERIFIED")
        self.assertEqual(result["hmacCryptographicVerification"], "NOT_PERFORMED")
        self.assertEqual(result["globalStableGate"], "OPEN")
        self.assertFalse(result["productionModificationAuthorized"])

    def test_wrong_lenovo_identity_rejected(self):
        data = sample()
        data["inventoryProof"]["inventory"]["hostname"] = "UNKNOWN-DEVICE"
        self.assertEqual(evaluate(data, NOW)["candidateStatus"], "BLOCKED_EVIDENCE")

    def test_unsafe_capability_contract_rejected(self):
        data = sample()
        data["inventoryProof"]["safety"]["arbitraryCommands"] = True
        self.assertFalse(evaluate(data, NOW)["checks"]["sanitizedLenovoInventoryContract"])

    def test_nonstandard_port_rejected(self):
        data = sample()
        data["inventoryProof"]["target"]["port"] = 18777
        self.assertEqual(evaluate(data, NOW)["candidateStatus"], "BLOCKED_EVIDENCE")

    def test_tailscale_cgnat_is_not_supported_by_existing_validator(self):
        data = sample()
        data["inventoryProof"]["target"]["host"] = "100.123.249.19"
        result = evaluate(data, NOW)
        self.assertEqual(result["candidateStatus"], "BLOCKED_EVIDENCE")
        self.assertIn("EXISTING_2PC_ACCEPTANCE_EXPECTS_RFC1918_OR_HOSTNAME", result["blockers"])

    def test_stale_bridge_report_not_current_proof(self):
        result = evaluate(sample(), datetime(2026, 10, 16, tzinfo=timezone.utc))
        self.assertIn("BRIDGE_REPORT_OLDER_THAN_24H_OR_FUTURE", result["blockers"])

    def test_fake_but_consistent_data_never_auto_accepts(self):
        data = sample()
        data["inventoryProof"]["untrustedSecret"] = "not-a-real-secret"
        result = evaluate(data, NOW)
        self.assertNotIn("not-a-real-secret", str(result))
        self.assertEqual(result["liveLenovoAuthenticatedJob"], "NOT_INDEPENDENTLY_VERIFIED")

    def test_r3_missing_handoff_is_not_node_auth_failure(self):
        result = evaluate(sample(), NOW)
        self.assertTrue(result["checks"]["r3DiagnosticExceptionReported"])
        self.assertNotIn("LENOVO_NETWORK_FAILED", result["blockers"])

    def test_missing_node_job_id_rejected(self):
        data = sample()
        data["inventoryProof"]["nodeJobId"] = ""
        self.assertFalse(evaluate(data, NOW)["checks"]["sanitizedLenovoInventoryContract"])

    def test_missing_bridge_health_rejected(self):
        data = sample()
        data["bridgeReport"]["state"]["authenticatedStatus"] = False
        self.assertEqual(evaluate(data, NOW)["candidateStatus"], "BLOCKED_EVIDENCE")

    def test_malformed_envelope_rejected(self):
        with self.assertRaises(ValueError):
            evaluate([], NOW)


if __name__ == "__main__":
    unittest.main()

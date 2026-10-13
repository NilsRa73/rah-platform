from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from rah_agent_bridge_evidence_gate import classify

class EvidenceTests(unittest.TestCase):
    def test_missing_stays_open(self):
        r = classify({})
        self.assertEqual(r['globalStableGate'], 'OPEN')
        self.assertFalse(r['productionRepairAuthorized'])

    def test_reported_error_is_not_proof(self):
        r = classify({'safeFix': {'result': 'BLOCKED_SAFE', 'token_state': 'NOT_CHECKED'}})
        self.assertFalse(r['rootCauseProven'])
        self.assertIn('EXACT_STARTUP_STAGE_NOT_OBSERVED', r['blockers'])

    def test_grok_report_is_not_job_proof(self):
        r = classify({'grok': {'result': 'GROK_REVIEW_DELIVERED_LOCAL_STABLE_GATE_OPEN'}})
        self.assertTrue(r['evidence']['grokReviewReported'])
        self.assertFalse(r['agentWorkerAccepted'])

    def test_tcp_18781_does_not_count_as_http(self):
        r = classify({'context': {'runtime': {'local_ports': {'18781': True}}}})
        self.assertFalse(r['evidence']['agentBridgeHttpReachable'])

    def test_inconsistent_report_does_not_authorize_change(self):
        r = classify({'safeFix': {'first_failure_stage': 'TOKEN_READ',
                                   'task_identity_match': 'MATCH',
                                   'token_state': 'READABLE'}})
        self.assertFalse(r['productionRepairAuthorized'])
        self.assertEqual(r['globalStableGate'], 'OPEN')

if __name__ == '__main__':
    unittest.main()

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

if __name__ == '__main__':
    unittest.main()

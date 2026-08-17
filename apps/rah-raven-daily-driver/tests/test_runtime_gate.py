import sys
import unittest
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP))

from runtime_check import run_checks


class RuntimeGateSmoke(unittest.TestCase):
    def test_gate_has_required_checks(self):
        data = run_checks()
        names = {x["name"] for x in data["checks"]}
        self.assertIn("Chronicle persistence", names)
        self.assertIn("Investigator synthetic", names)
        self.assertIn("Frozen guard", names)
        self.assertIn("LM Studio", names)
        self.assertIn("Real Facebook/archive import", names)
        self.assertIn(data["overall"], {"PASS", "PENDING_RUNTIME"})


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class RavenV1AcceptanceContractTests(unittest.TestCase):
    def test_root_launcher_exists_and_calls_local_acceptance(self):
        cmd = (ROOT / "START-RAVEN-V1-ACCEPTANCE.cmd").read_text(encoding="utf-8")
        self.assertIn("RAH RAVEN V1 - FINAL ACCEPTANCE", cmd)
        self.assertIn('PREPARE-RAVEN-BRIDGE.cmd', cmd)
        self.assertIn('RAH-RAVEN-V1-ACCEPTANCE.ps1', cmd)
        self.assertIn('--self-test', cmd)
        self.assertIn('FULL PASS', cmd)

    def test_acceptance_chain_is_complete(self):
        ps = (ROOT / "raven" / "windows" / "RAH-RAVEN-V1-ACCEPTANCE.ps1").read_text(encoding="utf-8")
        required = [
            "AcceptanceVersion = '1.0.0'",
            "127.0.0.1:18765",
            "doctor.py",
            "RAH-AGENT-TEAM-LIVE-TEST.ps1",
            "RAVEN-V1-ACCEPTANCE-LATEST.json",
            "RAVEN-V1-ACCEPTANCE-LATEST.txt",
            "Window capture",
            "Agent Team LIVE",
            "RAH RAVEN V1: FULL PASS",
        ]
        for marker in required:
            self.assertIn(marker, ps)

    def test_acceptance_stays_local_and_non_destructive(self):
        ps = (ROOT / "raven" / "windows" / "RAH-RAVEN-V1-ACCEPTANCE.ps1").read_text(encoding="utf-8").lower()
        forbidden = [
            "invoke-expression",
            "iex ",
            "new-netfirewallrule",
            "remove-item -recurse",
            "git merge",
            "gh pr merge",
        ]
        for marker in forbidden:
            self.assertNotIn(marker, ps)
        self.assertIn("arbitrarycommands=$false", ps)
        self.assertNotIn("$script:bridgeurl = 'http://0.0.0.0", ps)
        self.assertIn("test-rahloopbackurl 'http://0.0.0.0:18765'", ps)
        self.assertIn("stablepromotion=$false", ps)
        self.assertIn("automaticmerge=$false", ps)

    def test_final_pass_requires_all_runtime_gates(self):
        ps = (ROOT / "raven" / "windows" / "RAH-RAVEN-V1-ACCEPTANCE.ps1").read_text(encoding="utf-8")
        self.assertIn("$bridgeState -eq 'PASS'", ps)
        self.assertIn("$doctorState -eq 'PASS'", ps)
        self.assertIn("$captureState -eq 'PASS'", ps)
        self.assertIn("$agentState -eq 'PASS'", ps)


if __name__ == "__main__":
    unittest.main()

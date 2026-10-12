from __future__ import annotations

import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class RavenV1InstallerContractTests(unittest.TestCase):
    def test_installer_is_one_click_and_non_destructive(self):
        cmd=(ROOT/"INSTALL-RAVEN-V1-CANDIDATE.cmd").read_text(encoding="utf-8")
        ps=(ROOT/"INSTALL-RAVEN-V1-CANDIDATE.ps1").read_text(encoding="utf-8")
        self.assertIn("ONE CLICK", cmd)
        self.assertIn("INSTALL-RAVEN-V1-CANDIDATE.ps1", cmd)
        self.assertIn("--self-test", cmd)
        self.assertIn("START-RAVEN-V1-ACCEPTANCE.cmd", ps)
        self.assertIn("_ARCHIVE\\RAVEN-V1-BEFORE-INSTALL-", ps)
        self.assertIn("deletedFiles=$false", ps)
        self.assertIn("stablePromoted=$false", ps)
        self.assertIn("merged=$false", ps)

    def test_installer_includes_acceptance_freeze_and_rollback(self):
        ps=(ROOT/"INSTALL-RAVEN-V1-CANDIDATE.ps1").read_text(encoding="utf-8")
        for marker in (
            "START-RAVEN-V1-ACCEPTANCE.cmd",
            "FREEZE-RAVEN-V1-CANDIDATE.cmd",
            "ROLLBACK-RAVEN-V1.cmd",
            "RAH-AGENT-TEAM-LIVE-TEST.ps1",
            "RAH-LM-STUDIO-RECOVERY.ps1",
            "raven\\projects.json",
            "raven\\agents.json",
        ):
            self.assertIn(marker,ps)


if __name__=="__main__":
    unittest.main()

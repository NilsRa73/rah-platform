from __future__ import annotations

import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class RavenV1FreezeRollbackContractTests(unittest.TestCase):
    def test_freeze_requires_final_acceptance_pass(self):
        ps = (ROOT / "raven" / "windows" / "FREEZE-RAVEN-V1-CANDIDATE.ps1").read_text(encoding="utf-8")
        self.assertIn("Final acceptance report is missing", ps)
        self.assertIn("accept.overall -ne 'PASS'", ps)
        self.assertIn("FROZEN_CANDIDATE", ps)
        self.assertIn("Get-FileHash", ps)
        self.assertIn("stablePromoted=$false", ps)
        self.assertIn("merged=$false", ps)

    def test_rollback_verifies_hashes_before_restore(self):
        ps = (ROOT / "raven" / "windows" / "ROLLBACK-RAVEN-V1.ps1").read_text(encoding="utf-8")
        self.assertIn("SHA256 mismatch", ps)
        self.assertIn("Test-RahSnapshot", ps)
        self.assertIn("RAVEN-BEFORE-ROLLBACK-", ps)
        self.assertIn("deletePerformed=$false", ps)
        self.assertIn("overlayOnly=$true", ps)

    def test_no_destructive_delete_in_freeze_or_rollback(self):
        text = (
            (ROOT / "raven" / "windows" / "FREEZE-RAVEN-V1-CANDIDATE.ps1").read_text(encoding="utf-8")
            + "\n"
            + (ROOT / "raven" / "windows" / "ROLLBACK-RAVEN-V1.ps1").read_text(encoding="utf-8")
        ).lower()
        for forbidden in ("remove-item -literalpath $root", "rmdir /s /q", "rd /s /q", "del /f", "git merge", "gh pr merge"):
            self.assertNotIn(forbidden, text)

    def test_one_click_launchers_have_self_tests(self):
        for name in ("FREEZE-RAVEN-V1-CANDIDATE.cmd", "ROLLBACK-RAVEN-V1.cmd"):
            text = (ROOT / name).read_text(encoding="utf-8")
            self.assertIn("--self-test", text)


if __name__ == "__main__":
    unittest.main()

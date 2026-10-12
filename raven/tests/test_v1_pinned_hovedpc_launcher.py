from __future__ import annotations

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "RUN-RAVEN-V1-HOVED-PC-PINNED.cmd"

EXPECTED_SHA = "818b6be7ff99ecacd6438f2f383a35b96b4e24e1"


class RavenV1PinnedLauncherTests(unittest.TestCase):
    def test_launcher_is_pinned_and_one_click(self):
        text = LAUNCHER.read_text(encoding="utf-8")
        self.assertIn(f'set "RAH_PAYLOAD_SHA={EXPECTED_SHA}"', text)
        self.assertIn("raw.githubusercontent.com/NilsRa73/rah-platform/%RAH_PAYLOAD_SHA%", text)
        self.assertIn("INSTALL-RAVEN-V1-CANDIDATE.ps1", text)
        self.assertIn('-TargetRoot "C:\\RAH"', text)
        self.assertIn('-SourceBase "%RAH_BASE%"', text)
        self.assertIn("FULL PASS + FROZEN CANDIDATE", text)
        self.assertIn("--self-test", text)

    def test_launcher_does_not_use_moving_branch_for_payload(self):
        text = LAUNCHER.read_text(encoding="utf-8")
        self.assertNotIn(
            "raw.githubusercontent.com/NilsRa73/rah-platform/raven-agent-effect-pack-v1-20260927/",
            text,
        )
        match = re.search(r'set "RAH_PAYLOAD_SHA=([0-9a-f]{40})"', text)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), EXPECTED_SHA)

    def test_launcher_preserves_candidate_boundary(self):
        text = LAUNCHER.read_text(encoding="utf-8").lower()
        for forbidden in ("gh pr merge", "git merge", "stable promotion", "remove-item -recurse"):
            self.assertNotIn(forbidden, text)
        self.assertIn("raven-v1-acceptance-latest.txt", text)


if __name__ == "__main__":
    unittest.main()

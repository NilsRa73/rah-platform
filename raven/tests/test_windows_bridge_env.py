from __future__ import annotations

import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class WindowsBridgeEnvironmentTests(unittest.TestCase):
    def test_helper_exists_and_is_non_destructive(self):
        helper = (ROOT / "raven" / "windows" / "PREPARE-RAVEN-BRIDGE.cmd").read_text(encoding="utf-8")
        lower = helper.lower()
        self.assertIn(".venv-broken-", helper)
        self.assertIn('move "!VENV_DIR!" "!ARCHIVE!"', helper)
        self.assertNotIn("rmdir /s /q", lower)
        self.assertNotIn("rd /s /q", lower)
        self.assertNotIn("del /f", lower)

    def test_helper_prefers_known_supported_python_versions(self):
        helper = (ROOT / "raven" / "windows" / "PREPARE-RAVEN-BRIDGE.cmd").read_text(encoding="utf-8")
        self.assertIn("3.13 3.12 3.11", helper)

    def test_start_raven_checks_and_prepares_bridge_env(self):
        launcher = (ROOT / "START-RAVEN.cmd").read_text(encoding="utf-8")
        check = 'call "raven\\windows\\PREPARE-RAVEN-BRIDGE.cmd" --check'
        repair = 'call "raven\\windows\\PREPARE-RAVEN-BRIDGE.cmd"'
        self.assertIn(check, launcher)
        self.assertIn(repair, launcher)
        self.assertLess(launcher.index(check), launcher.index("[START] Launching the existing Raven Vision local chain"))
        self.assertLess(launcher.index(repair), launcher.index("[START] Launching the existing Raven Vision local chain"))


if __name__ == "__main__":
    unittest.main()

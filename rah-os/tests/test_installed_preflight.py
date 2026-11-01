"""Installed VM checks must never satisfy the Live USB/Stable gate."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "config/includes.chroot/usr/local/bin/rah-live-acceptance"
loader = importlib.machinery.SourceFileLoader("rah_acceptance", str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
acceptance = importlib.util.module_from_spec(spec)
loader.exec_module(acceptance)


class InstalledPreflightTests(unittest.TestCase):
    def collect(self, *, installed=False, live=False, version="0.9", health=True):
        def read(path):
            return {"/etc/rah-os-release": f'VERSION="{version}"',
                    "/proc/cmdline": "quiet boot=live" if live else "quiet"}.get(path, "")

        def fetch(url):
            if url == acceptance.HEALTH_URL:
                return {"status": "ok", "service": "rah-raven-agent"} if health else None
            return {"summary": {"WARN": 0}, "checks": [
                {"key": key, "state": "PASS"} for key in ("network", "display", "gpu")
            ]}

        with patch.object(acceptance, "read_text", side_effect=read), \
             patch.object(acceptance, "fetch_json", side_effect=fetch), \
             patch.object(acceptance, "run_read_only", return_value=(0, "active")), \
             patch.dict(os.environ, {"DISPLAY": ":0"}):
            return acceptance.collect(installed=installed)

    def test_installed_session_pass_is_not_live_or_stable_evidence(self):
        report = self.collect(installed=True)
        self.assertEqual(report["overall"], "PASS")
        self.assertEqual(report["schema"], "rah-os-installed-preflight-v1")
        self.assertEqual(report["test_scope"], "installed-session")
        self.assertFalse(report["stable_review"]["eligible_for_review"])
        self.assertFalse(report["stable_review"]["automatic_promotion"])

    def test_default_still_requires_live_boot(self):
        report = self.collect()
        self.assertEqual(report["overall"], "FAIL")
        self.assertFalse(report["stable_review"]["eligible_for_review"])

    def test_live_acceptance_keeps_existing_gate(self):
        report = self.collect(live=True)
        self.assertEqual(report["overall"], "PASS")
        self.assertEqual(report["schema"], acceptance.SCHEMA)
        self.assertTrue(report["stable_review"]["eligible_for_review"])

    def test_installed_flag_cannot_bypass_version_check(self):
        self.assertEqual(self.collect(installed=True, version="0.4")["overall"], "FAIL")

    def test_installed_flag_cannot_bypass_raven_check(self):
        self.assertEqual(self.collect(installed=True, health=False)["overall"], "FAIL")

    def test_installed_flag_even_on_live_session_never_qualifies(self):
        self.assertFalse(self.collect(installed=True, live=True)["stable_review"]["eligible_for_review"])


if __name__ == "__main__":
    unittest.main()

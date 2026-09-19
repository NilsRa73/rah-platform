#!/usr/bin/env python3
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "config"
    / "includes.chroot"
    / "usr"
    / "local"
    / "lib"
    / "rah"
    / "recovery-center.py"
)

spec = importlib.util.spec_from_file_location("rah_recovery_center", MODULE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load Recovery Center from {MODULE_PATH}")
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)


class RecoveryCenterTests(unittest.TestCase):
    def test_item_shape(self):
        result = recovery.item("WARN", "disk", "Disk", "Low space", "Free space")
        self.assertEqual(result["state"], "WARN")
        self.assertEqual(result["key"], "disk")
        self.assertEqual(result["suggestion"], "Free space")

    def test_repair_plan_prioritizes_warning_suggestions(self):
        checks = [
            recovery.item("PASS", "a", "A", "OK"),
            recovery.item("WARN", "b", "B", "Problem B", "Fix B"),
            recovery.item("INFO", "c", "C", "Info"),
            recovery.item("WARN", "d", "D", "Problem D", "Fix D"),
        ]
        with mock.patch.object(recovery, "raven_check", return_value=checks[0]), \
             mock.patch.object(recovery, "boot_check", return_value=checks[1]), \
             mock.patch.object(recovery, "live_mode_check", return_value=checks[2]), \
             mock.patch.object(recovery, "persistence_check", return_value=checks[3]), \
             mock.patch.object(recovery, "root_mount_check", return_value=checks[0]), \
             mock.patch.object(recovery, "root_storage_check", return_value=checks[0]), \
             mock.patch.object(recovery, "temp_write_check", return_value=checks[0]), \
             mock.patch.object(recovery, "package_check", return_value=checks[0]), \
             mock.patch.object(recovery, "network_check", return_value=checks[0]), \
             mock.patch.object(recovery, "error_log_check", return_value=checks[2]):
            payload = recovery.recovery_payload()

        self.assertEqual(payload["summary"]["WARN"], 2)
        self.assertEqual([x["title"] for x in payload["repair_plan"]], ["B", "D"])
        self.assertIn("does not format disks", payload["safety"])

    def test_html_escapes_untrusted_diagnostic_text(self):
        data = {
            "generated_at": "now",
            "identity": {"hostname": "<host>", "kernel": "k", "architecture": "x", "recovery_center_version": recovery.VERSION, "rah_release": ""},
            "summary": {"PASS": 0, "WARN": 1, "INFO": 0},
            "checks": [recovery.item("WARN", "x", "<script>", "A&B", "<fix>")],
            "repair_plan": [{"priority": 1, "title": "<script>", "reason": "A&B", "suggestion": "<fix>"}],
            "safety": "diagnostic only",
        }
        text = recovery.render_html(data)
        self.assertNotIn("<script>", text)
        self.assertIn("&lt;script&gt;", text)
        self.assertIn("A&amp;B", text)

    def test_report_export_writes_html_and_json(self):
        data = {
            "generated_at": "now",
            "identity": {"hostname": "test", "kernel": "k", "architecture": "x", "recovery_center_version": recovery.VERSION, "rah_release": ""},
            "summary": {"PASS": 1, "WARN": 0, "INFO": 0},
            "checks": [recovery.item("PASS", "x", "X", "OK")],
            "repair_plan": [{"priority": 1, "title": "No urgent repair action", "reason": "OK", "suggestion": "Continue testing"}],
            "safety": "diagnostic only",
        }
        with tempfile.TemporaryDirectory() as td:
            html_path, json_path = recovery.write_reports(data, td)
            self.assertTrue(html_path.exists())
            self.assertTrue(json_path.exists())
            parsed = json.loads(json_path.read_text(encoding="utf-8"))
            self.assertEqual(parsed["identity"]["hostname"], "test")
            self.assertIn("Recovery Center", html_path.read_text(encoding="utf-8"))

    def test_builtin_self_test(self):
        self.assertEqual(recovery.self_test(), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)

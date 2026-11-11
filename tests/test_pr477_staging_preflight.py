"""Contract tests for PR477 read-only preflight. Uses mocks, no host queries."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

FILE = Path(__file__).resolve().parents[1] / "desktop-bridge" / "pr477_staging_preflight.py"
spec = importlib.util.spec_from_file_location("preflight", FILE)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class PreflightTests(unittest.TestCase):
    def test_query_has_read_only_contract(self):
        with patch.object(mod, "powershell_json", side_effect=[
            ({"LocalAddress": "127.0.0.1", "LocalPort": 18765, "OwningProcess": 123}, None),
            ({"ProcessId": 123, "Name": "python.exe", "ExecutablePath": r"C:\RAH\bridge\python.exe"}, None),
        ]) as mocked:
            output = mod.inspect_port_and_process()
        self.assertEqual(output["port_18765"], "LISTENING")
        self.assertTrue(output["process_owner_resolved"])
        self.assertEqual(mocked.call_count, 2)
        for call in mocked.call_args_list:
            code = call.args[0].lower()
            for forbidden in ["stop-process", "start-process", "set-", "remove-", "new-item", "out-file"]:
                self.assertNotIn(forbidden, code)

    def test_candidate_sha_and_no_implicit_backup(self):
        with tempfile.TemporaryDirectory() as folder:
            candidate = Path(folder) / "candidate.exe"
            candidate.write_bytes(b"fixture only")
            with patch.object(mod, "inspect_port_and_process", return_value={"port_18765": "UNKNOWN"}):
                report = mod.collect(candidate, Path(folder))
            self.assertEqual(report["candidate"]["sha256"], hashlib.sha256(b"fixture only").hexdigest())
            self.assertFalse(report["acceptance"]["backup_verified"])
            self.assertFalse(report["acceptance"]["candidate_hash_verified_against_trusted_manifest"])
            self.assertFalse(report["candidate_started"])
            self.assertFalse(report["files_modified"])
            self.assertFalse(report["services_modified"])
            self.assertEqual(report["deployment_gate"]["decision"], "HOLD")
            self.assertFalse(report["deployment_gate"]["may_stop_bridge"])
            self.assertFalse(report["deployment_gate"]["may_replace_live_files"])
            self.assertFalse(report["deployment_gate"]["may_start_second_bridge_on_18765"])
            self.assertFalse(report["active_port_owner"]["verified_raven_installation"])

    def test_port_owner_is_not_installation_identity(self):
        owner = {"ProcessId": 123, "Name": "renamed.exe", "ExecutablePath": r"C:\\Apps\\renamed.exe"}
        listener = {"LocalAddress": "127.0.0.1", "LocalPort": 18765, "OwningProcess": 123}
        with patch.object(mod, "powershell_json", side_effect=[(listener, None), (owner, None)]):
            with patch.object(mod, "metadata", return_value={"exists": False}):
                report = mod.collect(None, None)
        self.assertEqual(report["active_port_owner"]["pid"], 123)
        self.assertEqual(report["active_port_owner"]["process_name"], "renamed.exe")
        self.assertFalse(report["active_port_owner"]["verified_raven_installation"])
        self.assertEqual(report["deployment_gate"]["decision"], "HOLD")

    def test_non_exe_does_not_hash(self):
        with tempfile.TemporaryDirectory() as folder:
            other = Path(folder) / "archive.zip"
            other.write_bytes(b"zip fixture")
            with patch.object(mod, "inspect_port_and_process", return_value={}):
                report = mod.collect(other, None)
            self.assertEqual(report["candidate"]["hash_error"], "only_exe_candidate_accepted")
            self.assertNotIn("sha256", report["candidate"])

    def test_unavailable_inspection_is_unknown_not_absent(self):
        with patch.object(mod, "powershell_json", side_effect=[(None, "powershell_query_failed"), (None, None)]):
            output = mod.inspect_port_and_process()
        self.assertEqual(output["port_18765"], "UNKNOWN")
        self.assertEqual(output["listeners"], [])


if __name__ == "__main__":
    unittest.main()

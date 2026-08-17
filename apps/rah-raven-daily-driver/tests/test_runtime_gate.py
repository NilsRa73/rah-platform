import json
import sys
import unittest
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
ROOT = APP.parents[1]
sys.path.insert(0, str(APP))

from promote_runtime_test import validated_runtime_result
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
        if data["overall"] == "PENDING_RUNTIME":
            self.assertEqual(data["recommended_stage"], "Candidate")

    def test_fake_pass_cannot_promote(self):
        fake = {
            "product": "RAH Raven Daily Driver",
            "version": "1.0",
            "overall": "PASS",
            "recommended_stage": "Runtime Test",
            "checks": [{"name": "Python 3", "status": "PASS", "required": True}],
        }
        with self.assertRaises(ValueError):
            validated_runtime_result(fake)

    def test_complete_pass_contract_is_accepted(self):
        required = [
            "Python 3",
            "requests",
            "Chronicle persistence",
            "Investigator synthetic",
            "Real Facebook/archive import",
            "LM Studio",
            "Frozen guard",
            "Main PC device node",
        ]
        data = {
            "product": "RAH Raven Daily Driver",
            "version": "1.0",
            "overall": "PASS",
            "recommended_stage": "Runtime Test",
            "checks": [{"name": name, "status": "PASS", "required": True} for name in required],
        }
        self.assertTrue(validated_runtime_result(data))

    def test_candidate_manifest_tracks_current_stable_without_claiming_stable(self):
        manifest = json.loads((ROOT / "RAH-RAVEN-DAILY-DRIVER-VERSION.json").read_text(encoding="utf-8"))
        package = json.loads((ROOT / "RAH-RAVEN-DAILY-DRIVER-PACKAGE.json").read_text(encoding="utf-8"))
        canonical = json.loads((ROOT / "RAH-COMMAND-CENTER-VERSION.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["stage"], "candidate")
        self.assertEqual(manifest["stable_gate"]["status"], "not_passed")
        self.assertEqual(manifest["stable_command_center_reference"], canonical["version"])
        self.assertEqual(manifest["stable_node_agent_reference"], "1.3.0")
        self.assertEqual(manifest["authority_delta"], "none")
        self.assertTrue(manifest["features"]["one_click_runtime_acceptance"])
        boundary = manifest["security_boundary"]
        self.assertEqual(boundary["bridge"], "loopback-read-only")
        self.assertFalse(boundary["shell"])
        self.assertFalse(boundary["generic_process_execution"])
        self.assertFalse(boundary["generic_file_api"])
        self.assertFalse(boundary["native_remote_control"])
        self.assertFalse(boundary["credential_attack_features"])
        self.assertFalse(boundary["cloud_agent_enabled_by_default"])
        self.assertFalse(boundary["cloud_response_storage"])
        self.assertFalse(boundary["runtime_acceptance_can_promote_stable"])
        self.assertEqual(package["packageFileCount"], 37)
        self.assertTrue(package["runtimePolicy"]["candidateOnly"])
        self.assertFalse(package["runtimePolicy"]["stablePromotionIncluded"])
        self.assertEqual(
            package["runtimePolicy"]["runtimeAcceptanceRunner"],
            "one-click-gate-evidence-validation-v1-stable-blocked",
        )

    def test_windows_runtime_launchers_fail_closed_and_preserve_exit_codes(self):
        gate = (APP / "RUNTIME-GATE-RAH-RAVEN.bat").read_text(encoding="utf-8")
        runner = (ROOT / "TEST-RAH-RAVEN-RUNTIME.bat").read_text(encoding="utf-8")
        validator = (ROOT / "VALIDATE-RAH-RAVEN-RUNTIME-EVIDENCE.bat").read_text(encoding="utf-8")

        self.assertIn('set "RC=%ERRORLEVEL%"', gate)
        self.assertIn('RAH_RAVEN_NONINTERACTIVE', gate)
        self.assertIn('exit /b %RC%', gate)

        self.assertIn('ONE-CLICK WINDOWS RUNTIME ACCEPTANCE', runner)
        self.assertIn('Stable promotion is always blocked by this runner.', runner)
        self.assertIn('set "GATE_RC=%ERRORLEVEL%"', runner)
        self.assertIn('set "VALIDATOR_RC=%ERRORLEVEL%"', runner)
        self.assertIn('call "%EVIDENCE%"', runner)
        self.assertIn('call "%VALIDATOR%" "%LATEST%"', runner)
        self.assertIn('if not "%GATE_RC%"=="0" exit /b 1', runner)
        self.assertIn('if "%VALIDATOR_RC%"=="2" exit /b 2', runner)
        self.assertIn('if "%VALIDATOR_RC%"=="0" exit /b 0', runner)

        self.assertIn('.venv\\Scripts\\python.exe', validator)
        self.assertIn('exit /b %RC%', validator)


if __name__ == "__main__":
    unittest.main()

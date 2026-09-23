import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


class RavenCore7Contract(unittest.TestCase):
    def test_canonical_entrypoints_exist_and_use_core(self):
        for name in (
            "START-HER.cmd",
            "DIAGNOSTICS.cmd",
            "REPAIR.cmd",
            "INSTALL-RAVEN-CORE-7.cmd",
            "RAVEN-CORE-7.ps1",
            "RAVEN-CORE-7-CONFIG.json",
            "RAVEN-CORE-7.md",
        ):
            self.assertTrue((ROOT / name).is_file(), name)

        start = read("START-HER.cmd")
        self.assertIn("RAVEN-CORE-7.ps1", start)
        self.assertIn("-Mode Start", start)
        self.assertIn("PRECHECK", start)
        self.assertIn("SAFE REPAIR", start)

    def test_config_has_fixed_safety_policy(self):
        config = json.loads(read("RAVEN-CORE-7-CONFIG.json"))
        self.assertEqual(config["version"], "7.0.0-foundation")
        self.assertEqual(config["ports"]["ravenCore"], 18765)
        self.assertEqual(config["ports"]["nodeAgent"], 18766)
        self.assertFalse(config["policy"]["arbitraryShell"])
        self.assertFalse(config["policy"]["backgroundNetworkDiscovery"])
        self.assertFalse(config["policy"]["automaticFirewallChanges"])
        self.assertFalse(config["policy"]["persistNodeTokens"])
        self.assertFalse(config["policy"]["automaticRemoteNodeStart"])

    def test_core_uses_fixed_local_http_allowlist(self):
        ps1 = read("RAVEN-CORE-7.ps1")
        for route in (
            "http://127.0.0.1:18765/health",
            "http://127.0.0.1:18765/agent/capabilities",
            "http://127.0.0.1:18765/agent/jobs/health",
            "http://127.0.0.1:18765/ai/providers",
            "http://127.0.0.1:18765/ai/memory/status",
            "http://127.0.0.1:1234/v1/models",
        ):
            self.assertIn(route, ps1)
        self.assertIn("local HTTP allowlist rejected", ps1)

    def test_start_does_not_widen_remote_authority(self):
        ps1 = read("RAVEN-CORE-7.ps1")
        low = ps1.lower()
        forbidden = (
            "invoke-expression",
            "new-netfirewallrule",
            "set-netfirewallrule",
            "remove-netfirewallrule",
            "start-process cmd.exe",
            "start-process powershell.exe -argumentlist $",
        )
        for marker in forbidden:
            self.assertNotIn(marker, low)

        self.assertIn("Node Agent 18766 remains explicit by design", ps1)
        self.assertIn("automaticRemoteNodeStart = $false", ps1)
        self.assertIn("existing fixed Raven capability allowlist only", ps1)

    def test_repair_scope_is_existing_fixed_front_door_repair(self):
        ps1 = read("RAVEN-CORE-7.ps1")
        self.assertIn("REPAIR-RAH-OS.cmd", ps1)
        self.assertIn("No broad repair was attempted", ps1)
        self.assertNotIn("winget install", ps1.lower())

    def test_machine_status_and_integrations_are_present(self):
        ps1 = read("RAVEN-CORE-7.ps1")
        for marker in (
            "RAH-HARDWARE-REGISTRY.ps1",
            "START-RAH-AI-FABRIC.cmd",
            "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat",
            "START-HER-RAH-2PC-GRID.cmd",
            "SYNC-RAH-PROJECT-MEMORY.ps1",
            "status.json",
            "core7-audit.jsonl",
            "lmStudioModelCount",
            "capabilityCount",
        ):
            self.assertIn(marker, ps1)


if __name__ == "__main__":
    unittest.main()

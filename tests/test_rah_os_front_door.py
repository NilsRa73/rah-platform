import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


class RahOsFrontDoorContract(unittest.TestCase):
    def test_front_door_files_and_fixed_entrypoint(self):
        launcher = read("START-HER-RAH-OS.cmd")
        installer = read("INSTALL-RAH-OS.cmd")
        repair = read("REPAIR-RAH-OS.cmd")
        ps1 = read("RAH-OS-CONTROL.ps1")
        selftest = read("RAH-OS-SELFTEST.ps1")
        acceptance = read("ACCEPT-RAH-OS-v0.6.ps1")
        hoved = read("RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1")

        self.assertIn("RAH-OS-CONTROL.ps1", launcher)
        self.assertIn("RAH-OS-SELFTEST.ps1", launcher)
        self.assertIn("REPAIR-RAH-OS.cmd", launcher)
        self.assertIn("-STA", launcher)
        self.assertIn("C:\\RAH\\RavenOS", installer)

        for name in (
            "START-HER-RAH-OS.cmd",
            "INSTALL-RAH-OS.cmd",
            "REPAIR-RAH-OS.cmd",
            "RAH-OS-CONTROL.ps1",
            "RAH-OS-SELFTEST.ps1",
            "ACCEPT-RAH-OS-v0.6.cmd",
            "ACCEPT-RAH-OS-v0.6.ps1",
            "RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd",
            "RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1",
            "RAH-OS.md",
        ):
            self.assertIn(name, installer)

        self.assertIn("RAH-OS-SELFTEST.ps1", repair)
        self.assertIn("-RepairFrontDoor", repair)
        self.assertIn("DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat", ps1)
        self.assertIn("START-RAH-AI-FABRIC.cmd", ps1)
        self.assertIn("START-HER-RAH-2PC-GRID.cmd", ps1)
        self.assertIn("VERIFY-RAH-2PC-GRID.cmd", ps1)
        self.assertIn("Start RAH Workspace.cmd", ps1)
        self.assertIn("DIAGNOSTICS.cmd", ps1)
        self.assertIn("RavenCore7", ps1)
        self.assertIn("CORE 7 DIAGNOSTICS", ps1)
        self.assertIn("WORKER PROOF", ps1)
        self.assertIn("WORKER-PROOF.cmd", ps1)
        self.assertIn("AI SELF-CHECK", ps1)
        self.assertIn("RAVEN-AI-SELF-CHECK.cmd", ps1)
        self.assertIn("ANYTHINGLLM GATE", ps1)
        self.assertIn("START-HER-ANYTHINGLLM-APPROVAL.cmd", ps1)
        self.assertIn("$aiSelfCheck = Find-RahFile 'RAVEN-AI-SELF-CHECK.cmd'", ps1)
        self.assertIn("$anythingApproval = Find-RahFile 'START-HER-ANYTHINGLLM-APPROVAL.cmd'", ps1)
        self.assertLess(ps1.index("$aiSelfCheck = Find-RahFile"), ps1.index("AiSelfCheck = $aiSelfCheck"))
        self.assertLess(ps1.index("$anythingApproval = Find-RahFile"), ps1.index("AnythingApproval = $anythingApproval"))
        self.assertIn("worker-proof.json", ps1)
        self.assertIn("47824", ps1)
        self.assertIn("1234", ps1)
        self.assertIn("11434", ps1)
        self.assertIn("PRECHECK", ps1)
        self.assertIn("SAFE REPAIR", ps1)
        self.assertIn("rah-os-selftest", selftest)
        self.assertIn("RAVEN-AI-SELF-CHECK.cmd", selftest)
        self.assertIn("START-HER-ANYTHINGLLM-APPROVAL.cmd", selftest)
        self.assertIn("ACCEPT-RAH-OS-v0.6.cmd", selftest)
        self.assertIn("ACCEPT-RAH-OS-v0.6.ps1", selftest)
        self.assertIn("RUN HOVED-PC v0.6", ps1)
        self.assertIn("RAH-OS-ACCEPTANCE.json", ps1)
        self.assertIn("RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd", ps1)
        self.assertIn("RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd", selftest)
        self.assertIn("RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1", selftest)
        self.assertIn("rah-os-v0.6-hoved-pc-sequence", hoved)
        self.assertIn("RAH-OS-HOVED-PC-SEQUENCE.json", hoved)
        self.assertIn("RAH-OS-ACCEPTANCE.json", hoved)
        order = [hoved.index(x) for x in (
            "# 1) FRONT DOOR",
            "# 2) RAVEN CORE",
            "# 3) LOCAL AI",
            "# 4) ANYTHINGLLM",
            "# 5) WORKER PROOF",
            "# 6) COMBINE",
        )]
        self.assertEqual(order, sorted(order))
        self.assertIn("[ValidateSet('PASS','PENDING','FAIL')]", acceptance)
        self.assertNotIn("'WARN'", acceptance)
        self.assertIn("rah-os-v0.6-acceptance", acceptance)
        for area in ("Front Door", "Raven Core", "Local AI", "AnythingLLM", "Worker Proof"):
            self.assertIn(area, acceptance)

    def test_front_door_preserves_safety_boundary(self):
        acceptance = read("ACCEPT-RAH-OS-v0.6.ps1")
        hoved = read("RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1")
        combined = "\n".join(
            read(name).lower()
            for name in (
                "START-HER-RAH-OS.cmd",
                "INSTALL-RAH-OS.cmd",
                "REPAIR-RAH-OS.cmd",
                "RAH-OS-CONTROL.ps1",
                "RAH-OS-SELFTEST.ps1",
                "ACCEPT-RAH-OS-v0.6.ps1",
                "RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1",
            )
        )

        self.assertNotIn("invoke-expression", combined)
        self.assertNotIn("new-netfirewallrule", combined)
        self.assertNotIn("remove-netfirewallrule", combined)
        self.assertNotIn("read-host", combined)
        self.assertNotIn('textbox name="command', combined)
        self.assertNotIn("start-rah-node-agent", combined)
        self.assertIn("127.0.0.1", combined)
        self.assertIn("18765", combined)
        self.assertIn("18766", combined)
        self.assertIn("47824", combined)
        self.assertIn("1234", combined)
        self.assertIn("11434", combined)
        self.assertIn("core 7", combined)
        self.assertNotIn("new-netfirewallrule", acceptance.lower())
        self.assertNotIn("remove-netfirewallrule", acceptance.lower())
        self.assertNotIn("invoke-expression", acceptance.lower())
        self.assertNotIn("read-host", acceptance.lower())
        self.assertNotIn("invoke-expression", hoved.lower())
        self.assertNotIn("new-netfirewallrule", hoved.lower())
        self.assertNotIn("remove-netfirewallrule", hoved.lower())
        self.assertNotIn("start-rah-node-agent", hoved.lower())

    def test_repair_is_fixed_allowlist_only(self):
        selftest = read("RAH-OS-SELFTEST.ps1")
        low = selftest.lower()
        self.assertIn("$frontdoorfiles", low)
        self.assertIn("raw.githubusercontent.com/nilsra73/rah-platform/", low)
        self.assertNotIn("param([string]$command", low)
        self.assertNotIn("scriptblock", low)
        self.assertNotIn("iex ", low)

    def test_auto_start_keeps_node_explicit(self):
        ps1 = read("RAH-OS-CONTROL.ps1")
        docs = read("RAH-OS.md")
        self.assertIn("Node Agent is intentionally not auto-started", ps1)
        self.assertIn("does not auto-start the remote Node Agent", docs)
        self.assertNotIn("START-RAH-NODE-AGENT", ps1)


if __name__ == "__main__":
    unittest.main()

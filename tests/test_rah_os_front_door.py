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
            "RAH-OS.md",
        ):
            self.assertIn(name, installer)

        self.assertIn("RAH-OS-SELFTEST.ps1", repair)
        self.assertIn("-RepairFrontDoor", repair)
        self.assertIn("DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat", ps1)
        self.assertIn("START-RAH-AI-FABRIC.cmd", ps1)
        self.assertIn("START-HER-RAH-2PC-GRID.cmd", ps1)
        self.assertIn("VERIFY-RAH-2PC-GRID.cmd", ps1)
        self.assertIn("PRECHECK", ps1)
        self.assertIn("SAFE REPAIR", ps1)
        self.assertIn("rah-os-selftest", selftest)

    def test_front_door_preserves_safety_boundary(self):
        combined = "\n".join(
            read(name).lower()
            for name in (
                "START-HER-RAH-OS.cmd",
                "INSTALL-RAH-OS.cmd",
                "REPAIR-RAH-OS.cmd",
                "RAH-OS-CONTROL.ps1",
                "RAH-OS-SELFTEST.ps1",
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

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


class RahOsFrontDoorContract(unittest.TestCase):
    def test_front_door_files_and_fixed_entrypoint(self):
        launcher = read("START-HER-RAH-OS.cmd")
        installer = read("INSTALL-RAH-OS.cmd")
        ps1 = read("RAH-OS-CONTROL.ps1")
        self.assertIn("RAH-OS-CONTROL.ps1", launcher)
        self.assertIn("-STA", launcher)
        self.assertIn("C:\\RAH\\RavenOS", installer)
        self.assertIn("START-HER-RAH-OS.cmd", installer)
        self.assertIn("RAH-OS-CONTROL.ps1", installer)
        self.assertIn("RAH-OS.md", installer)
        self.assertIn("DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat", ps1)
        self.assertIn("START-RAH-AI-FABRIC.cmd", ps1)
        self.assertIn("START-HER-RAH-2PC-GRID.cmd", ps1)
        self.assertIn("VERIFY-RAH-2PC-GRID.cmd", ps1)

    def test_front_door_preserves_safety_boundary(self):
        ps1 = read("RAH-OS-CONTROL.ps1")
        low = ps1.lower()
        self.assertNotIn("invoke-expression", low)
        self.assertNotIn("new-netfirewallrule", low)
        self.assertNotIn("remove-netfirewallrule", low)
        self.assertIn("start-process -filepath $", low)
        self.assertNotIn("read-host", low)
        self.assertNotIn('textbox name="command', low)
        self.assertIn("127.0.0.1", ps1)
        self.assertIn("18765", ps1)
        self.assertIn("18766", ps1)

    def test_auto_start_keeps_node_explicit(self):
        ps1 = read("RAH-OS-CONTROL.ps1")
        docs = read("RAH-OS.md")
        self.assertIn("Node Agent is intentionally not auto-started", ps1)
        self.assertIn("does not auto-start the remote Node Agent", docs)
        self.assertNotIn("START-RAH-NODE-AGENT", ps1)


if __name__ == "__main__":
    unittest.main()

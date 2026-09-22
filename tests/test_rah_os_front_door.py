from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_front_door_files_and_fixed_entrypoint():
    launcher = read("START-HER-RAH-OS.cmd")
    installer = read("INSTALL-RAH-OS.cmd")
    ps1 = read("RAH-OS-CONTROL.ps1")
    assert "RAH-OS-CONTROL.ps1" in launcher
    assert "-STA" in launcher
    assert "C:\\RAH\\RavenOS" in installer
    assert "START-HER-RAH-OS.cmd" in installer
    assert "RAH-OS-CONTROL.ps1" in installer
    assert "RAH-OS.md" in installer
    assert "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat" in ps1
    assert "START-RAH-AI-FABRIC.cmd" in ps1
    assert "START-HER-RAH-2PC-GRID.cmd" in ps1
    assert "VERIFY-RAH-2PC-GRID.cmd" in ps1


def test_front_door_preserves_safety_boundary():
    ps1 = read("RAH-OS-CONTROL.ps1")
    low = ps1.lower()
    assert "invoke-expression" not in low
    assert "new-netfirewallrule" not in low
    assert "remove-netfirewallrule" not in low
    assert "start-process -filepath $" in low
    assert "read-host" not in low
    assert 'textbox name="command' not in low
    assert "127.0.0.1" in ps1
    assert "18765" in ps1
    assert "18766" in ps1


def test_auto_start_keeps_node_explicit():
    ps1 = read("RAH-OS-CONTROL.ps1")
    docs = read("RAH-OS.md")
    assert "Node Agent is intentionally not auto-started" in ps1
    assert "does not auto-start the remote Node Agent" in docs
    assert "START-RAH-NODE-AGENT" not in ps1

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT / "START-HER-RAH-AI-STUDIOS-V3.1-CANDIDATE.cmd"
HELPER = ROOT / "RAH-STUDIO-ONE-CLICK.vbs"
BRIDGE = ROOT / "desktop-bridge" / "start-studio-bridge-silent.cmd"
STUDIO = ROOT / "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"


def main() -> None:
    entry = ENTRY.read_text(encoding="utf-8")
    helper = HELPER.read_text(encoding="utf-8")
    bridge = BRIDGE.read_text(encoding="utf-8")

    assert STUDIO.is_file()
    assert "wscript.exe //B //Nologo" in entry
    assert "RAH-STUDIO-ONE-CLICK.vbs" in entry
    assert "powershell" not in entry.lower()

    assert 'shell.Run(command, 0, True)' in helper
    assert "start-studio-bridge-silent.cmd" in helper
    assert "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html" in helper
    assert "powershell" not in helper.lower()

    required = (
        "http://127.0.0.1:18765/health",
        "curl.exe -fsS --max-time 2",
        "RAH Raven Desktop Bridge",
        "app_launcher",
        "agent_runner",
        "anythingllm_approval_gate",
        "taskkill /PID",
        "py_compile",
        "app_launcher.py",
        "raven_bridge.py",
        "start \"\" /b",
    )
    for marker in required:
        assert marker in bridge, marker

    assert "powershell" not in bridge.lower()
    assert "0.0.0.0" not in bridge
    assert "192.168." not in bridge
    assert "taskkill /IM" not in bridge
    assert bridge.index("RAH Raven Desktop Bridge") < bridge.index("taskkill /PID")

    print("RAH AI Studios Candidate one-click hidden Bridge bootstrap contract: PASS")


if __name__ == "__main__":
    main()

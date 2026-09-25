from __future__ import annotations

from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT / "START-HER-RAH-AI-STUDIOS-V3.1-CANDIDATE.cmd"
HELPER = ROOT / "RAH-STUDIO-ONE-CLICK.vbs"
BRIDGE = ROOT / "desktop-bridge" / "start-studio-bridge-silent.cmd"
STUDIO = ROOT / "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
PACKAGE = ROOT / "RAH-RAVEN-VERSION.json"


def executable_text(text: str, comment_prefixes: tuple[str, ...]) -> str:
    lines = []
    for raw in text.splitlines():
        stripped = raw.strip()
        if not stripped:
            continue
        lower = stripped.lower()
        if any(lower.startswith(prefix.lower()) for prefix in comment_prefixes):
            continue
        lines.append(stripped)
    return "\n".join(lines)


def main() -> None:
    entry = ENTRY.read_text(encoding="utf-8")
    helper = HELPER.read_text(encoding="utf-8")
    bridge = BRIDGE.read_text(encoding="utf-8")
    entry_exec = executable_text(entry, ("rem ", "::"))
    helper_exec = executable_text(helper, ("'",))
    bridge_exec = executable_text(bridge, ("rem ", "::"))

    assert STUDIO.is_file()
    assert "wscript.exe //B //Nologo" in entry
    assert "RAH-STUDIO-ONE-CLICK.vbs" in entry
    assert "powershell" not in entry_exec.lower()

    assert 'shell.Run(command, 0, True)' in helper
    assert "start-studio-bridge-silent.cmd" in helper
    assert "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html" in helper
    assert "powershell" not in helper_exec.lower()
    assert '"?boot=" & CStr(rc)' in helper

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

    assert "powershell" not in bridge_exec.lower()
    assert "0.0.0.0" not in bridge
    assert "192.168." not in bridge
    assert "taskkill /IM" not in bridge
    assert bridge.index("RAH Raven Desktop Bridge") < bridge.index("taskkill /PID")

    package = json.loads(PACKAGE.read_text(encoding="utf-8"))
    required_package_files = {
        "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html",
        "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json",
        "raven-studio-launch-client.js",
        "START-HER-RAH-AI-STUDIOS-V3.1-CANDIDATE.cmd",
        "RAH-STUDIO-ONE-CLICK.vbs",
        "desktop-bridge/start-studio-bridge-silent.cmd",
        "desktop-bridge/app_launcher.py",
    }
    assert required_package_files.issubset(set(package["files"]))

    studio = STUDIO.read_text(encoding="utf-8")
    assert "const BOOT_CODE=" in studio
    assert "Port 18765 brukes av en ikke-verifisert tjeneste" in studio

    print("RAH AI Studios Candidate one-click hidden Bridge bootstrap contract: PASS")


if __name__ == "__main__":
    main()

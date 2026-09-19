from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PY = (ROOT / "rah_agent_bridge.py").read_text(encoding="utf-8")
PS = (ROOT / "INSTALL-RAH-AGENT-BRIDGE.ps1").read_text(encoding="utf-8")
CLIENT = (ROOT / "RAH-AGENT-BUS.ps1").read_text(encoding="utf-8")
CMD = (ROOT / "START-HER-RAH-AGENT-BRIDGE.cmd").read_text(encoding="utf-8")


def need(text: str, value: str) -> None:
    assert value in text, f"missing contract marker: {value}"


def main() -> None:
    need(PY, 'VERSION = "1.0.0"')
    need(PY, '"127.0.0.1"')
    need(PY, '"execCapability": False')
    need(PY, '"system.inventory"')
    need(PY, '"code.review"')
    need(PY, '"project.review"')
    need(PY, '"text.task"')
    need(PY, '/v1/jobs/enqueue')
    need(PY, '/v1/jobs/claim')
    need(PY, 'action == "complete"')
    need(PY, 'action == "fail"')
    lower = PY.lower()
    assert "subprocess" not in lower
    assert "os.system" not in lower
    assert "eval(" not in lower
    assert "exec(" not in lower
    assert "0.0.0.0" not in PY

    need(PS, "$script:RahAgentBridgeInstallerVersion = '1.0.0'")
    need(PS, "$script:RahAgentBridgeTaskName = 'RAH Agent Bridge'")
    need(PS, "New-ScheduledTaskPrincipal")
    need(PS, "-RunLevel Highest")
    need(PS, "127.0.0.1")
    need(PS, "execCapability=$false")
    need(PS, "py_compile")
    assert "New-NetFirewallRule" not in PS
    assert "0.0.0.0" not in PS

    need(CLIENT, "$script:RahAgentBusClientVersion = '1.0.0'")
    need(CLIENT, "Bearer $token")
    need(CLIENT, "127.0.0.1:18781")

    need(CMD, 'set "RAH_SELF_PATH=%~f0"')
    need(CMD, "fltmc >nul 2>&1")
    need(CMD, "-Verb RunAs")
    need(CMD, "__RAH_ADMIN__")
    need(CMD, "RAH AGENT BRIDGE: PASS")
    need(CMD, "RAH_AGENT_SOURCE_DIR")


if __name__ == "__main__":
    main()
    print("PASS: RAH Agent Bridge v1 static contract")

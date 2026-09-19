from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PY = (ROOT / "rah_agent_bridge.py").read_text(encoding="utf-8")
PS = (ROOT / "INSTALL-RAH-AGENT-BRIDGE.ps1").read_text(encoding="utf-8")
CLIENT = (ROOT / "RAH-AGENT-BUS.ps1").read_text(encoding="utf-8")
CMD = (ROOT / "START-HER-RAH-AGENT-BRIDGE.cmd").read_text(encoding="utf-8")
WORKER = (ROOT / "rah_agent_worker.py").read_text(encoding="utf-8")


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

    need(PS, "$script:RahAgentBridgeInstallerVersion = '1.1.0'")
    need(PS, "$script:RahAgentBridgeTaskName = 'RAH Agent Bridge'")
    need(PS, "$script:RahAgentWorkerTaskName = 'RAH Agent Worker'")
    need(PS, "$script:RahAgentBridgeWorker = 'rah_agent_worker.py'")
    need(PS, "New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited")
    need(PS, "C:\\RAH\\AgentWorker\\worker-state.json")
    need(PS, "New-ScheduledTaskPrincipal")
    need(PS, "-RunLevel Highest")
    need(PS, "127.0.0.1")
    need(PS, "execCapability=$false")
    need(PS, "py_compile")
    assert "New-NetFirewallRule" not in PS
    assert "0.0.0.0" not in PS

    need(WORKER, 'VERSION = "1.0.0"')
    need(WORKER, 'DEFAULT_BRIDGE = "http://127.0.0.1:18781"')
    need(WORKER, 'DEFAULT_FABRIC = "http://127.0.0.1:18765"')
    need(WORKER, '"system.inventory": "system-inventory"')
    need(WORKER, 'ALLOWED_TEST_CAPABILITIES')
    need(WORKER, '"test-bridge-security"')
    need(WORKER, '/ai/chat')
    need(WORKER, '/agent/jobs')
    need(WORKER, 'execCapability": False')
    worker_lower = WORKER.lower()
    assert "subprocess" not in worker_lower
    assert "os.system" not in worker_lower
    assert "eval(" not in worker_lower
    assert "exec(" not in worker_lower
    assert "0.0.0.0" not in WORKER

    need(CLIENT, "$script:RahAgentBusClientVersion = '1.0.0'")
    need(CLIENT, "Bearer $token")
    need(CLIENT, "127.0.0.1:18781")

    need(CMD, 'set "RAH_SELF_PATH=%~f0"')
    need(CMD, "fltmc >nul 2>&1")
    need(CMD, "-Verb RunAs")
    need(CMD, "__RAH_ADMIN__")
    need(CMD, "RAH AGENT TEAM BRIDGE: PASS")
    need(CMD, "RAH_AGENT_SOURCE_DIR")


if __name__ == "__main__":
    main()
    print("PASS: RAH Agent Bridge v1 static contract")

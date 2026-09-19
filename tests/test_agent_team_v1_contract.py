from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKER = (ROOT / "rah_agent_worker.py").read_text(encoding="utf-8")
INSTALL = (ROOT / "INSTALL-RAH-AGENT-WORKER.ps1").read_text(encoding="utf-8")
ACCEPT = (ROOT / "RAH-AGENT-TEAM-ACCEPTANCE.ps1").read_text(encoding="utf-8")
CMD = (ROOT / "START-HER-RAH-AGENT-TEAM.cmd").read_text(encoding="utf-8")


def need(text: str, value: str) -> None:
    assert value in text, f"missing contract marker: {value}"


def main() -> None:
    need(WORKER, 'VERSION = "1.0.0"')
    need(WORKER, 'DEFAULT_BRIDGE = "http://127.0.0.1:18781"')
    need(WORKER, 'DEFAULT_FABRIC = "http://127.0.0.1:18765"')
    need(WORKER, '"system.inventory": "system-inventory"')
    need(WORKER, '"project.review"')
    need(WORKER, '"agent.message"')
    need(WORKER, 'ALLOWED_TEST_CAPABILITIES')
    need(WORKER, '"test-bridge-security"')
    need(WORKER, '"execCapability": False')
    need(WORKER, '/ai/chat')
    need(WORKER, '/agent/jobs')
    need(WORKER, 'handledBy')
    need(WORKER, 'attemptCount')
    need(WORKER, 'fallbackUsed')
    need(WORKER, 'attempts')
    need(WORKER, 'WorkerJobError')

    lower = WORKER.lower()
    for forbidden in ("import subprocess", "subprocess.", "os.system", "eval(", "exec(", "0.0.0.0"):
        assert forbidden not in lower, f"forbidden production capability: {forbidden}"

    need(INSTALL, "$script:RahAgentWorkerInstallerVersion = '1.0.0'")
    need(INSTALL, "$script:TaskName = 'RAH Agent Worker'")
    need(INSTALL, "-RunLevel Limited")
    need(INSTALL, "execCapability=$false")
    need(INSTALL, "bridgeTokenCollected=$false")
    need(INSTALL, "tokenCollectedInReports=$false")
    need(INSTALL, "py_compile")

    need(ACCEPT, "$script:RahAgentTeamAcceptanceVersion='1.0.0'")
    need(ACCEPT, "system.inventory")
    need(ACCEPT, "agent.message")
    need(ACCEPT, "bridgeTokenCollected=$false")
    need(ACCEPT, "arbitraryCommands=$false")

    need(CMD, 'set "RAH_SELF_PATH=%~f0"')
    need(CMD, "fltmc >nul 2>&1")
    need(CMD, "-Verb RunAs")
    need(CMD, "__RAH_ADMIN__")
    need(CMD, "RAH AGENT TEAM v1: PASS / READY")
    need(CMD, "RAH_AGENT_SOURCE_DIR")


if __name__ == "__main__":
    main()
    print("PASS: RAH Agent Team v1 static contract")

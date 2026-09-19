from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PS = (ROOT / "RAH-AGENT-TEAM-LIVE-TEST.ps1").read_text(encoding="utf-8")
CMD = (ROOT / "START-HER-RAH-AGENT-LIVE.cmd").read_text(encoding="utf-8")


def need(text: str, value: str) -> None:
    assert value in text, f"missing contract marker: {value}"


def main() -> None:
    need(PS, "$script:RahAgentTeamLiveTestVersion = '1.0.0'")
    need(PS, "'http://127.0.0.1:18781'")
    need(PS, "'http://127.0.0.1:18765'")
    need(PS, "'RAH Raven AI Providers'")
    need(PS, "'RAH Raven Bridge'")
    need(PS, "'RAH Agent Bridge'")
    need(PS, "'RAH Agent Worker'")
    need(PS, "-Kind 'system.inventory'")
    need(PS, "-Kind 'agent.message'")
    need(PS, "RAH LIVE AGENT OK")
    need(PS, "RAH AGENT TEAM LIVE: FULL PASS")
    need(PS, "rah-agent-team-live-latest.json")
    need(PS, "RAH-AGENT-TEAM-LIVE.txt")
    need(PS, "bridgeTokenCollected=$false")
    need(PS, "arbitraryCommands=$false")
    need(PS, "Test-RahLoopbackUrl")
    need(PS, "Get-RahToken")
    need(PS, "Bearer '+$Token")

    lower = PS.lower()
    for forbidden in ("invoke-expression", "iex ", "0.0.0.0", "new-netfirewallrule", "stop-process", "remove-itemproperty"):
        assert forbidden not in lower, f"forbidden live-test capability: {forbidden}"

    need(CMD, 'set "RAH_SELF_PATH=%~f0"')
    need(CMD, "fltmc >nul 2>&1")
    need(CMD, "-Verb RunAs")
    need(CMD, "__RAH_ADMIN__")
    need(CMD, "RAH_LIVE_TEST_URL")
    need(CMD, "RAH AGENT TEAM LIVE: FULL PASS")
    need(CMD, "C:\\RAH\\AgentWorker\\reports\\RAH-AGENT-TEAM-LIVE.txt")


if __name__ == "__main__":
    main()
    print("PASS: RAH Agent Team Live Test v1 static contract")

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PS1 = (ROOT / "RAH-HOME-DIAGNOSTICS.ps1").read_text(encoding="utf-8")


def require(needle: str) -> None:
    assert needle in PS1, f"missing diagnostics contract marker: {needle}"


def main() -> None:
    require("$script:RahHomeDiagnosticsVersion = '1.0.0'")
    require("schema='rah-home-diagnostics'")
    require("RAH HOME BLACK BOX: READY")
    require("Protect-RahText")
    require("PAIR\\s*CODE")
    require("Bearer [REDACTED]")
    require("peerStoreContentCollected=$false")
    require("rah-home-support-latest.json")
    require("RAH-HOME-SUPPORT-")
    require("Compress-Archive")
    require("Get-NetIPAddress")
    require("Get-NetTCPConnection")
    require("Get-NetFirewallRule")
    require("Get-ScheduledTask")
    require("Get-RahFileInventory")
    require("Get-RahProcessSummary")
    require("worker-agent.err.log")
    require("RAH-PYTHON-CONSOLE-GUARD.txt")

    lowered = PS1.lower()
    assert "invoke-expression" not in lowered
    assert "iex " not in lowered
    assert "-listenaddress 0.0.0.0" not in lowered
    assert "-profile any" not in lowered
    # The peer store may be existence-checked, but its raw content must never be read/copied.
    assert "get-content -literalpath $peerstorepath" not in lowered
    assert "copy-item -literalpath $peerstorepath" not in lowered


if __name__ == "__main__":
    main()
    print("PASS: RAH Home Diagnostics v1 static contract")

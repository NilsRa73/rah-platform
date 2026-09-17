from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PS1 = (ROOT / "RAH-HOME-FINALIZE.ps1").read_text(encoding="utf-8")
CMD = (ROOT / "START-HER-RAH-HOME.cmd").read_text(encoding="utf-8")
GUARD = (ROOT / "RAH-WINDOWS-PYTHON-CONSOLE-GUARD.ps1").read_text(encoding="utf-8")
DIAG = (ROOT / "RAH-HOME-DIAGNOSTICS.ps1").read_text(encoding="utf-8")


def require(text: str, needle: str) -> None:
    assert needle in text, f"missing contract marker: {needle}"


def main() -> None:
    require(PS1, "$script:RahHomeFinalizeVersion = '1.0.0'")
    require(PS1, "ValidateSet('Auto','Leader','Worker')")
    require(PS1, "Test-RahPrivateIPv4")
    require(PS1, "Get-NetIPAddress")
    require(PS1, "Get-NetRoute")
    require(PS1, "RAH-HOME-ACCEPTANCE.ps1")
    require(PS1, "RAH-HOME-INSTALL.ps1")
    require(PS1, "RAH-HOME-NODE-CLIENT.ps1")
    require(PS1, "@('health','systemInfo','benchmark')")
    require(PS1, "RAH HOME 2-PC: FULL PASS")
    require(PS1, "rah-home-finalize-latest.json")
    require(PS1, "RAH-HOME-WORKER-READY.txt")
    require(PS1, "-Profile Private")
    require(PS1, "$script:RahWorkerTaskName = 'RAH Home Worker'")
    require(PS1, "-ListenAddress '+$Address+' -AllowLan -Port '")
    require(PS1, "Get-RahPeerAddress")
    require(PS1, "SkipFirewall")
    require(PS1, "SkipAutostart")
    require(PS1, "Finalize v1 bruker stable RAH Home-port 18766")

    lowered = PS1.lower()
    assert "invoke-expression" not in lowered
    assert "iex " not in lowered
    assert "-listenaddress 0.0.0.0" not in lowered
    assert "-localaddress 0.0.0.0" not in lowered
    assert "-profile any" not in lowered
    assert "action='shell'" not in lowered
    assert "action=\"shell\"" not in lowered

    require(CMD, "START-HER bootstrap + Black Box + Python guard + Finalize self-test PASS")
    require(CMD, "RAH-HOME-FINALIZE.ps1")
    require(CMD, "RahHomeFinalizeVersion = '1.0.0'")
    require(CMD, "RAH-WINDOWS-PYTHON-CONSOLE-GUARD.ps1")
    require(CMD, "RahPythonConsoleGuardVersion = '1.0.0'")
    require(CMD, "RAH-HOME-DIAGNOSTICS.ps1")
    require(CMD, "RahHomeDiagnosticsVersion = '1.0.0'")
    require(CMD, 'set "PYTHON_BASIC_REPL=1"')
    require(CMD, "-PersistUserSetting")
    require(CMD, ":COLLECT_DIAG")
    require(CMD, "rah-home-support-latest.json")
    require(CMD, "-Mode %RAH_MODE%")
    require(CMD, 'set "RAH_MODE=Auto"')
    require(CMD, 'set "RAH_BOOT=C:\\RAH\\Bootstrap"')
    require(CMD, "if not defined RAH_URL")
    require(CMD, "if not defined RAH_GUARD_URL")
    require(CMD, "if not defined RAH_DIAG_URL")

    require(GUARD, "$script:RahPythonConsoleGuardVersion = '1.0.0'")
    require(GUARD, "$script:RahKnownIssueSignature = '_pyrepl Windows console WinError 123'")
    require(GUARD, "PYTHON_BASIC_REPL")
    require(GUARD, "[version]'3.13.0'")
    require(GUARD, "RAH_PYTHON_NONINTERACTIVE_OK")
    require(GUARD, "rah-python-console-guard.json")
    require(GUARD, "RAH-PYTHON-CONSOLE-GUARD.txt")
    require(GUARD, "SetEnvironmentVariable('PYTHON_BASIC_REPL','1','User')")
    guard_lower = GUARD.lower()
    assert "invoke-expression" not in guard_lower
    assert "start-process python" not in guard_lower

    require(DIAG, "$script:RahHomeDiagnosticsVersion = '1.0.0'")
    require(DIAG, "schema='rah-home-diagnostics'")
    require(DIAG, "Protect-RahText")
    require(DIAG, "peerStoreContentCollected=$false")
    require(DIAG, "RAH HOME BLACK BOX: READY")
    diag_lower = DIAG.lower()
    assert "invoke-expression" not in diag_lower
    assert "get-content -literalpath $peerstorepath" not in diag_lower


if __name__ == "__main__":
    main()
    print("PASS: RAH Home Finalize v1 + Python Guard + Black Box contract")

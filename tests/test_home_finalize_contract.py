from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PS1 = (ROOT / "RAH-HOME-FINALIZE.ps1").read_text(encoding="utf-8")
CMD = (ROOT / "START-HER-RAH-HOME.cmd").read_text(encoding="utf-8")


def require(text: str, needle: str) -> None:
    assert needle in text, f"missing contract marker: {needle}"


def main() -> None:
    require(PS1, "$script:RahHomeFinalizeVersion = '1.0.0'")
    require(PS1, "ValidateSet('Auto','Leader','Worker')")
    require(PS1, "Test-RahPrivateIPv4")
    require(PS1, "RAH-HOME-ACCEPTANCE.ps1")
    require(PS1, "RAH-HOME-INSTALL.ps1")
    require(PS1, "RAH-HOME-NODE-CLIENT.ps1")
    require(PS1, "@('health','systemInfo','benchmark')")
    require(PS1, "RAH HOME 2-PC: FULL PASS")
    require(PS1, "rah-home-finalize-latest.json")
    require(PS1, "RAH-HOME-WORKER-READY.txt")
    require(PS1, "-Profile Private")
    require(PS1, "$script:RahWorkerTaskName = 'RAH Home Worker'")
    require(PS1, "-ListenAddress ' + $Address + ' -AllowLan -Port '")
    require(PS1, "Get-RahPeerAddress")
    require(PS1, "SkipFirewall")
    require(PS1, "SkipAutostart")

    lowered = PS1.lower()
    assert "invoke-expression" not in lowered
    assert "iex " not in lowered
    assert "0.0.0.0" not in PS1
    assert "-profile any" not in lowered
    assert "action='shell'" not in lowered
    assert "action=\"shell\"" not in lowered

    require(CMD, "START-HER bootstrap + Finalize self-test PASS")
    require(CMD, "RAH-HOME-FINALIZE.ps1")
    require(CMD, "RahHomeFinalizeVersion = '1.0.0'")
    require(CMD, "-Mode %RAH_MODE%")
    require(CMD, 'set "RAH_MODE=Auto"')
    require(CMD, 'set "RAH_BOOT=C:\\RAH\\Bootstrap"')


if __name__ == "__main__":
    main()
    print("PASS: RAH Home Finalize v1 static contract")

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PS = (ROOT / "RAH-MEMORY-STARTUP-DOCTOR.ps1").read_text(encoding="utf-8")
CMD = (ROOT / "START-HER-RAH-MEMORY-DOCTOR.cmd").read_text(encoding="utf-8")


def need(text: str, value: str) -> None:
    assert value in text, f"missing contract marker: {value}"


def main() -> None:
    need(PS, "$script:RahMemoryDoctorVersion = '1.0.0'")
    need(PS, "Get-RahProcessClassification")
    need(PS, "Get-RahStartupClassification")
    need(PS, "'PROTECTED'")
    need(PS, "'MANUAL'")
    need(PS, "'REVIEW'")
    need(PS, "'KEEP'")
    for marker in ("anythingllm", "lm studio", "tailscale", "rustdesk", "anydesk", "speedify", "c:\\rah\\"):
        need(PS.lower(), marker)
    need(PS, "Read-Host")
    need(PS, "Stop-Process -Id $p.pid -Force")
    need(PS, "Disable-RahSelectedStartup")
    need(PS, "Restore-RahLatestStartup")
    need(PS, "startup-$stamp.json")
    need(PS, "Move-Item -LiteralPath $s.originalPath")
    need(PS, "Remove-ItemProperty -LiteralPath $s.source")
    need(PS, "No process or startup entry is changed by Audit mode.")
    need(PS, "memory-doctor-$stamp.html")
    need(PS, "rah-memory-startup-doctor")

    lower = PS.lower()
    assert "stop-service" not in lower
    assert "set-service" not in lower
    assert "remove-item -literalpath $root -recurse" not in lower
    assert "get-process | stop-process" not in lower
    assert "where-object" in lower

    # A force-stop must remain behind an explicit typed JA confirmation.
    force_pos = PS.find("Stop-Process -Id $p.pid -Force")
    confirm_pos = PS.rfind("Read-Host", 0, force_pos)
    assert confirm_pos >= 0, "force stop lacks explicit confirmation path"

    need(CMD, 'set "RAH_SELF_PATH=%~f0"')
    need(CMD, "fltmc >nul 2>&1")
    need(CMD, "-Verb RunAs")
    need(CMD, "__RAH_ADMIN__")
    need(CMD, "--audit")
    need(CMD, "--restore")
    need(CMD, "RAH MEMORY DOCTOR: PASS")


if __name__ == "__main__":
    main()
    print("PASS: RAH Memory & Startup Doctor v1 static contract")

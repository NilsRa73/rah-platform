from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAUNCHERS = [
    "START-HER-RAH-HOME.cmd",
    "RAH-HOME-ACCEPTANCE.cmd",
    "RAH-HOME-INSTALL.cmd",
    "RAH-HOME-NODE-SETUP.cmd",
]


def require(text: str, needle: str, name: str) -> None:
    assert needle in text, f"{name}: missing {needle!r}"


def main() -> None:
    for name in LAUNCHERS:
        text = (ROOT / name).read_text(encoding="utf-8")
        lowered = text.lower()
        require(text, 'set "RAH_SELF_PATH=%~f0"', name)
        require(text, "fltmc >nul 2>&1", name)
        require(text, "-Verb RunAs", name)
        require(text, "$env:RAH_SELF_PATH", name)
        require(text, "__RAH_ADMIN__", name)
        require(text, ":VERIFY_ADMIN", name)
        require(text, ":FAIL_UAC", name)
        require(text, ":FAIL_NOT_ADMIN", name)
        assert "net session" not in lowered, f"{name}: legacy net session elevation remains"
        assert lowered.count("fltmc >nul 2>&1") >= 2, f"{name}: must verify admin before and after relaunch"

    for name in ("RAH-HOME-INSTALL.cmd", "RAH-HOME-NODE-SETUP.cmd"):
        text = (ROOT / name).read_text(encoding="utf-8")
        require(text, 'set "RAH_FORWARD_ARGS=%*"', name)
        require(text, "%RAH_FORWARD_ARGS%", name)
        require(text, 'if /I "%~1"=="-SelfTest" goto RUN', name)

    finalizer = (ROOT / "START-HER-RAH-HOME.cmd").read_text(encoding="utf-8")
    require(finalizer, 'set "RAH_MODE=Auto"', "START-HER-RAH-HOME.cmd")
    require(finalizer, "RAH HOME FINALIZE: PASS", "START-HER-RAH-HOME.cmd")


if __name__ == "__main__":
    main()
    print("PASS: RAH Home admin launcher contract")

from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
CMD=ROOT/"RAH-AUTO-CONTINUE-v1-START-HER.cmd"
META=ROOT/"RAH-AUTO-CONTINUE-v1.json"

def main():
    text=CMD.read_text(encoding="utf-8")
    low=text.lower()

    required=[
        "RAH - FORTSETT MED AUTO v1",
        "492e6543b443cfb5b4a126a82555a6e08fc5503b",
        "RAH-HOVED-PC-FINALIZER-v2-START-HER.cmd",
        "RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-START-HER.cmd",
        "RAH - Fortsett med auto.lnk",
        "CORE_GATE",
        "READY-FOR-REBOOT-CHECK",
        "Stable Gate remains OPEN",
        "arbitraryCommands=$false",
        "arbitraryPaths=$false",
        "callerArguments=$false",
        r"G:\My Drive\RAH CLOUD\99_INBOX",
    ]
    for marker in required:
        assert marker in text, marker

    forbidden=[
        "raw.githubusercontent.com",
        "invoke-webrequest",
        "start-bitstransfer",
        "winget ",
        "choco ",
        "diskpart",
        "bcdedit",
        "bootrec",
        "clear-disk",
        "remove-partition",
        "new-partition",
        "format-volume",
    ]
    for marker in forbidden:
        assert marker not in low, marker

    # UAC is allowed only for self-elevation of this exact launcher.
    assert "Start-Process -FilePath $env:RAH_SELF -Verb RunAs -ArgumentList '__RAH_ADMIN__'" in text

    # Only one immutable GitHub archive source is allowed.
    assert "$ArchiveUrl='https://github.com/NilsRa73/rah-platform/archive/'+$Pinned+'.zip'" in text
    assert "refs/heads/main" not in text
    assert "archive/main.zip" not in text

    # State machine: core before full closeout, and reboot is terminal.
    assert text.index("if($core -ne 'PASS')") < text.index("ACTION: running Full Gate Closeout v1.")
    assert "exit 20" in text
    assert "stableGate='OPEN'" in text

    print("RAH Auto Continue v1 contract: PASS")

if __name__=="__main__":
    main()

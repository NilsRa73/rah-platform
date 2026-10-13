from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CMD=ROOT/"RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-START-HER.cmd"

def main():
    text=CMD.read_text(encoding="utf-8")
    low=text.lower()

    required=[
        "RAH HOVED-PC FULL GATE CLOSEOUT v1",
        "RAH-HOVED-PC-FINALIZER-v2-LATEST.json",
        "coreGate",
        "CORE PASS is required first",
        "CONFIGURE-RAH-PROJECT-MEMORY.ps1",
        "TEST-ANYTHINGLLM-APPROVAL.ps1",
        "RAVEN-CORE-7-WORKER-PROOF.ps1",
        "START-HER-RAH-2PC-GRID.cmd",
        "RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1",
        "READY-FOR-REBOOT-CHECK",
        "FULL_STABLE_GATE=OPEN",
        "tokenIncluded=$false",
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
        "anythingllm-token.txt",
    ]
    for marker in forbidden:
        assert marker not in low, marker

    # No full stable PASS before reboot observation.
    assert "FULL_STABLE_GATE=PASS" not in text
    assert "popupRebootVerification='PENDING'" in text

    # The closeout must gate on v2 core PASS before interactive setup.
    gate=text.split("S '1/6 REQUIRE VERIFIED CORE PASS'",1)[1].split("S '2/6",1)[0]
    assert "[string]$v2.coreGate -ne 'PASS'" in gate
    assert "exit 12" in gate

    print("RAH HOVED-PC full-gate closeout v1 contract: PASS")

if __name__=="__main__":
    main()

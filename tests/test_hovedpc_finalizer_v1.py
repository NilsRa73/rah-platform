from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACCEPT = ROOT / "RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1"
PROOF = ROOT / "RAVEN-JOB-EXECUTOR-PROOF.ps1"
FINALIZER = ROOT / "RAH-HOVED-PC-FINALIZER-v1-START-HER.cmd"


def must(text, markers):
    for marker in markers:
        assert marker in text, marker


def main():
    accept = ACCEPT.read_text(encoding="utf-8")
    proof = PROOF.read_text(encoding="utf-8")
    finalizer = FINALIZER.read_text(encoding="utf-8")
    lower = (proof + "\n" + finalizer).lower()

    must(accept, [
        "$coreNames=@('Front Door','Raven Core','Local AI')",
        "$coreOverall=",
        "coreOverall=$coreOverall;overall=$overall",
        "if($overall -eq 'PASS'){exit 0}",
        "exit 1",
    ])
    assert "status='PENDING'" not in accept
    assert "if($overall -eq 'PENDING')" not in accept

    must(proof, [
        "rah-raven-job-executor-proof-v1",
        "RAH Raven Bridge",
        "queued-read-only-allowlist",
        "capability='system-inventory'",
        "confirm=$true",
        "queued-after-explicit-confirm",
        "files_modified -ne $false",
        "arbitrary_commands -ne $false",
        "tools_executed",
        "Test-HighestTask",
        "Start-ScheduledTask",
        "http://127.0.0.1:18765/agent/jobs/health",
    ])

    must(finalizer, [
        "RAH HOVED-PC FINALIZER v1",
        "__RAH_ADMIN__",
        "Start-Process -FilePath $env:RAH_SELF -Verb RunAs",
        "RAH Raven Bridge",
        "RunLevel",
        "system-inventory",
        "queued-after-explicit-confirm",
        "Gemma 3 4B",
        "coreOverall",
        "CORE_GATE=",
        "FULL_STABLE_GATE=",
        r"G:\My Drive\RAH CLOUD\99_INBOX",
        "RAH-HOVED-PC-FINALIZER-v1-LATEST.json",
    ])

    forbidden = [
        "github.com",
        "raw.githubusercontent",
        "https://",
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
        assert marker not in lower, marker

    # Any HTTP runtime endpoint in proof/finalizer must be loopback.
    urls = []
    for token in lower.replace('"', " ").replace("'", " ").split():
        if token.startswith("http://"):
            urls.append(token.strip("()[]{};,"))
    assert urls
    assert all("127.0.0.1" in u or "localhost" in u for u in urls), urls

    print("RAH HOVED-PC Finalizer v1 contract: PASS")


if __name__ == "__main__":
    main()

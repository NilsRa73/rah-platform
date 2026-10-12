from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CMD = ROOT / "RAH-HOVED-PC-FINALIZER-v2-START-HER.cmd"
META = ROOT / "RAH-HOVED-PC-FINALIZER-v2.json"

PIN = "c05e11ad7a6d15153efff50dd982295469980091"
ALLOWED_URL = f"https://github.com/NilsRa73/rah-platform/archive/{PIN}.zip"


def main():
    text = CMD.read_text(encoding="utf-8")
    low = text.lower()

    required = [
        "RAH HOVED-PC FINALIZER v2",
        PIN,
        "$ArchiveUrl='https://github.com/NilsRa73/rah-platform/archive/'+$Pinned+'.zip'",
        "$Runtime=Join-Path $Root 'Runtime\\RavenElevated'",
        "$Backups=Join-Path $Root 'Backups\\HOVED-PC-Finalizer-v2'",
        "coreOverall",
        "RAVEN-JOB-EXECUTOR-PROOF.ps1",
        "RAH Raven Bridge",
        "RunLevel Highest",
        "Canonical real Job Executor proof PASS.",
        "RAH_OS_CORE_READY",
        "CORE FINAL: PASS",
        r"G:\My Drive\RAH CLOUD\99_INBOX",
        "stableV04Touched=$false",
    ]
    for marker in required:
        assert marker in text, marker

    forbidden = [
        "raw.githubusercontent.com",
        "invoke-webrequest",
        "start-bitstransfer",
        "winget ",
        "choco ",
        "git pull",
        "git fetch",
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

    # Only the pinned GitHub archive is allowed to be an external URL.
    external = re.findall(r"https://[^'\"\s]+", text)
    assert len(external) == 1, external
    # The URL is composed from the pinned variable at runtime; no branch/main URL.
    assert external[0] == "https://github.com/NilsRa73/rah-platform/archive/", external

    # Runtime HTTP calls must remain loopback.
    for url in re.findall(r"http://[^'\"\s)]+", text):
        assert "127.0.0.1" in url or "localhost" in url, url

    # Candidate acceptance refresh must be backed up first.
    refresh = text.split("S '2/8 REFRESH CANDIDATE ACCEPTANCE FILES WITH BACKUP'",1)[1].split("S '3/8",1)[0]
    assert "Backup-File $dst" in refresh
    assert "Copy-Item" in refresh
    assert "coreOverall" in refresh

    # Stable v0.4 must never be used as a mutation target.
    assert "C:\\RAH\\RavenOS-v0.4" not in text
    assert "stable v0.4 untouched" in low

    print("RAH HOVED-PC Finalizer v2 contract: PASS")


if __name__ == "__main__":
    main()

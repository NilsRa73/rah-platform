from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/"RUN-RAH-AI-STUDIOS-CANDIDATE4-FULLY-OFFLINE-ACCEPTANCE.cmd"


def main():
    text=SCRIPT.read_text(encoding="utf-8")
    lower=text.lower()

    required=[
        "RAH_OFFLINE=1",
        "NO_PROXY=127.0.0.1,localhost,::1",
        "C:\\RAH\\Offline\\Candidate4",
        "LOCAL PACKAGE",
        "OFFLINE CACHE",
        "LOCAL START",
        "FULL READINESS",
        "127.0.0.1:18765/health",
        "127.0.0.1:18765/apps/status",
        "127.0.0.1:1234/v1/models",
        "--noproxy",
        "3.1.0-candidate.4",
        "fixed-allowlist-explicit-launch",
        "read-only-allowlist",
        "anythingllm_approval_gate",
        "world-media",
        "rah-os",
        "raven-browser",
        "start-studio-bridge-silent.cmd",
        "FINAL: PASS",
        "FINAL: PENDING",
        "FINAL: FAIL",
        "No network repair was attempted",
    ]
    for marker in required:
        assert marker in text, marker

    forbidden=[
        "github.com",
        "raw.githubusercontent",
        "https://",
        "git pull",
        "git fetch",
        "invoke-webrequest",
        "bitsadmin",
        "winget ",
        "choco ",
        "diskpart",
        "format ",
        "bcdedit",
        "bootrec",
        "clear-disk",
        "remove-partition",
        "new-partition",
    ]
    for marker in forbidden:
        assert marker not in lower, marker

    assert "http://" in lower
    external_http=[
        token for token in lower.replace('"',' ').split()
        if token.startswith("http://") and "127.0.0.1" not in token and "localhost" not in token
    ]
    assert not external_http, external_http
    assert "UPDATE-RAH-RAVEN.ps1" not in text
    assert "pip install" not in lower
    assert "set \"RAH_OFFLINE=1\"" in text
    print("RAH Candidate.4 fully offline acceptance contract: PASS")


if __name__=="__main__":
    main()

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "RUN-RAH-AI-STUDIOS-CANDIDATE4-FULLY-OFFLINE-ACCEPTANCE.cmd"


def main():
    text = SCRIPT.read_text(encoding="utf-8")
    lower = text.lower()

    required = [
        "RAH_OFFLINE=1",
        "NO_PROXY=127.0.0.1,localhost,::1",
        "C:\\RAH\\Offline\\Candidate4",
        "CACHE_VENV",
        "LOCAL PACKAGE",
        "OFFLINE CACHE",
        "LOCAL BRIDGE",
        "LOCAL AI",
        "127.0.0.1:18765/health",
        "127.0.0.1:18765/apps/status",
        "127.0.0.1:1234/v1/models",
        'curl.exe --noproxy "*"',
        "3.1.0-candidate.4",
        "fixed-allowlist-explicit-launch",
        "read-only-allowlist",
        "anythingllm_approval_gate",
        "world-media",
        "rah-os",
        "raven-browser",
        ":ensure_venv_cache",
        ":restore_venv_cache",
        "robocopy",
        "--no-index",
        "--find-links",
        "FINAL: PASS",
        "FINAL: PENDING",
        "FINAL: FAIL",
        "No network repair was attempted",
        "No GitHub, DNS, WAN or VPN access was required",
    ]
    for marker in required:
        assert marker in text, marker

    forbidden = [
        "github.com",
        "raw.githubusercontent",
        "https://",
        "git pull",
        "git fetch",
        "invoke-webrequest",
        "bitsadmin",
        "winget ",
        "choco ",
        "update-rah-raven.ps1",
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

    # Every HTTP endpoint in the acceptance path must be loopback.
    urls = []
    for token in lower.replace('"', " ").replace("=", " ").split():
        if token.startswith("http://"):
            urls.append(token.strip("()[]{};,"))
    assert urls, "Expected loopback HTTP endpoints"
    assert all(
        ("127.0.0.1" in url or "localhost" in url)
        for url in urls
    ), urls

    # Offline repair may invoke pip only against a local source.
    pip_lines = [line.lower() for line in text.splitlines() if "pip install" in line.lower()]
    assert pip_lines, "Expected local wheelhouse fallback"
    for line in pip_lines:
        assert "--no-index" in line, line
        assert "--find-links" in line, line
        assert "http://" not in line and "https://" not in line, line

    # Do not route through the normal one-click bootstrap/update path.
    assert "START-HER-RAH-AI-STUDIOS-V3.1-CANDIDATE.cmd" not in text
    assert "RAH-STUDIO-ONE-CLICK.vbs" not in text
    assert "start-studio-bridge-silent.cmd" not in text

    # Unknown port owner must fail closed; only verified Raven may be terminated.
    assert "Nothing was killed" in text
    assert text.index('call :json_value "%TMP_HEALTH%" "name" "RAH Raven Desktop Bridge"') < text.index("taskkill /PID")

    print("RAH Candidate.4 fully offline acceptance contract: PASS")


if __name__ == "__main__":
    main()

from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/"RUN-RAH-AI-STUDIOS-CANDIDATE4-HOVED-PC-ACCEPTANCE.cmd"


def main():
    text=SCRIPT.read_text(encoding="utf-8")
    required=[
        "PRECHECK",
        "UPDATE",
        "START",
        "POSTCHECK",
        "FINAL: PASS",
        "FINAL: PENDING",
        "FINAL: FAIL",
        "UPDATE-RAH-RAVEN.ps1",
        "-NoStart",
        "START-HER-RAH-AI-STUDIOS-V3.1-CANDIDATE.cmd",
        "http://127.0.0.1:18765/health",
        "http://127.0.0.1:18765/apps/status",
        'call :json_bool "%TMP_HEALTH%" "app_launcher" "True"',
        'call :json_value "%TMP_HEALTH%" "app_launcher_mode" "fixed-allowlist-explicit-launch"',
        'call :json_bool "%TMP_HEALTH%" "agent_runner" "True"',
        'call :json_value "%TMP_HEALTH%" "agent_runner_mode" "read-only-allowlist"',
        'call :json_bool "%TMP_HEALTH%" "anythingllm_approval_gate" "True"',
        'call :json_bool "%TMP_HEALTH%" "anythingllm_approval_configured" "True"',
        'call :json_app "%TMP_STATUS%" "world-media"',
        'call :json_app "%TMP_STATUS%" "rah-os"',
        'call :json_app "%TMP_STATUS%" "raven-browser"',
    ]
    for marker in required:
        assert marker in text, marker

    forbidden=[
        "diskpart",
        "format ",
        "bcdedit",
        "bootrec",
        "wmic disk",
        "clear-disk",
        "remove-partition",
        "new-partition",
    ]
    lower=text.lower()
    for marker in forbidden:
        assert marker not in lower, marker

    assert "curl.exe -fsSL --retry 3" in text
    assert "powershell.exe -NoLogo -NoProfile -NonInteractive" in text
    assert "Start-Process" not in text
    assert "Invoke-WebRequest" not in text
    assert "taskkill" not in text
    assert "ConvertFrom-Json" in text
    assert ":json_value" in text
    assert ":json_bool" in text
    assert ":json_app" in text
    assert "127.0.0.1:18765" in text
    assert "0.0.0.0" not in text
    assert "FINAL_RC=10" in text
    print("RAH AI Studios Candidate.4 HOVED-PC acceptance contract: PASS")


if __name__=="__main__":
    main()

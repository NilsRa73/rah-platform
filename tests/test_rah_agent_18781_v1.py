from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CMD=ROOT/"RAH-AGENT-18781-v1-START-HER.cmd"

def main():
    text=CMD.read_text(encoding="utf-8")
    low=text.lower()
    required=[
        "RAH HOVED-PC AGENT 18781 v1",
        "17099d8125bccfc26d85ff6ef09d0352cb9cdbaf",
        "INSTALL-RAH-AGENT-BRIDGE.ps1",
        "rah_agent_bridge.py",
        "RAH-AGENT-BUS.ps1",
        "http://127.0.0.1:18781/health",
        "http://127.0.0.1:18781/v1/jobs/status",
        "execCapability -eq $false",
        "NEXT_GATE=LENOVO_AUTHENTICATED_NODE_JOB",
        "STABLE_GATE=OPEN",
        "credentialValueReported=$false",
        "Raven GOLD still PASS",
        "Gemma still PASS",
    ]
    for m in required:
        assert m in text, m

    forbidden=[
        "0.0.0.0",
        "new-netfirewallrule",
        "diskpart",
        "bcdedit",
        "bootrec",
        "clear-disk",
        "remove-partition",
        "format-volume",
        "write-host $localcredential",
        "credentialValueReported=$true",
        "STABLE_GATE=PASS",
    ]
    for m in forbidden:
        assert m not in text, m

    assert "$ArchiveUrl='https://github.com/NilsRa73/rah-platform/archive/'+$Pinned+'.zip'" in text
    assert "archive/main.zip" not in text
    assert "refs/heads/main" not in text
    print("RAH Agent 18781 v1 contract: PASS")

if __name__=="__main__":
    main()

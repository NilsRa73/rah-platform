from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CMD=ROOT/"RAH-WORKER-GEMMA-PROOF-v1-START-HER.cmd"

def main():
    text=CMD.read_text(encoding="utf-8")
    low=text.lower()
    required=[
        "RAH WORKER GEMMA PROOF v1",
        "3611e51a952570cfd83ab08dbf57b5cc686ba57d",
        "http://127.0.0.1:18781/v1/jobs/enqueue",
        "http://127.0.0.1:18765",
        "gemma-3-4b-it",
        "rah-agent-worker",
        "execCapability -eq $false",
        "PASS_WORKER_TO_LOCAL_GEMMA",
        "NEXT_GATE=",
        "LENOVO_AUTHENTICATED_NODE_JOB",
        "STABLE_GATE=OPEN",
        "credentialValueReported=$false",
        "workerPersistentInstall=$false",
    ]
    for m in required:
        assert m in text, m

    forbidden=[
        "0.0.0.0",
        "diskpart",
        "bcdedit",
        "bootrec",
        "new-netfirewallrule",
        "invoke-expression",
        "start-process cmd",
        "stable_gate=pass",
        "credentialvaluereported=$true",
    ]
    for m in forbidden:
        assert m not in low, m

    assert "provider='lmstudio'" in text
    assert "model='gemma-3-4b-it'" in text
    assert "--once" in text
    print("RAH Worker Gemma proof v1 contract: PASS")

if __name__=="__main__":
    main()

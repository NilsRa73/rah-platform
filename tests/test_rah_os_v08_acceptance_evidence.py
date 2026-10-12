from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1"


def main():
    text = SCRIPT.read_text(encoding="utf-8")

    required = [
        "0.8.2-evidence-first",
        "function Get-LocalJson",
        "function Test-LmInference",
        "'http://127.0.0.1:18765/health'",
        "'http://127.0.0.1:18765/agent/jobs/health'",
        "'http://127.0.0.1:1234/v1/models'",
        "Raven Core state evidence PASS",
        "$n.status='PENDING'",
        "$w.status='PENDING'",
        "$overall=if($coreFailures.Count -gt 0 -or $allFailures.Count -gt 0){'FAIL'}elseif($allPending.Count -gt 0){'PENDING'}else{'PASS'}",
        "if($overall -eq 'PENDING'){exit 2}",
    ]
    for marker in required:
        assert marker in text, marker

    # Raven canonical state must be sufficient evidence for PASS; do not couple it
    # to the child PowerShell process exit code.
    raven_block = text.split("$c=Stage 'Raven Core'", 1)[1].split("$stages.Add($c)", 1)[0]
    assert "[string]$core.overall -eq 'PASS'" in raven_block
    assert "$c.exitCode -eq 0 -and $core" not in raven_block

    # Local AI must use live loopback evidence/inference, not parse a fragile TXT.
    ai_block = text.split("$a=[pscustomobject]", 1)[1].split("$stages.Add($a)", 1)[0]
    assert "Test-LmInference" in ai_block
    assert "agent/jobs/health" in ai_block
    assert "AI-SELF-CHECK-LATEST.txt" not in ai_block

    # Known deferred gates are PENDING, not core failures.
    anything = text.split("$n=Stage 'AnythingLLM'", 1)[1].split("$stages.Add($n)", 1)[0]
    assert "$n.exitCode -eq 10" in anything
    assert "$n.status='PENDING'" in anything

    worker = text.split("$w=Stage 'Worker Proof'", 1)[1].split("$stages.Add($w)", 1)[0]
    assert "$w.status='PENDING'" in worker
    assert "state -eq 'PENDING'" in worker

    forbidden = [
        "raw.githubusercontent.com",
        "Invoke-WebRequest",
        "diskpart",
        "bcdedit",
        "bootrec",
        "Clear-Disk",
        "Remove-Partition",
        "New-Partition",
    ]
    for marker in forbidden:
        assert marker not in text, marker

    print("RAH OS v0.8 evidence-first acceptance contract: PASS")


if __name__ == "__main__":
    main()

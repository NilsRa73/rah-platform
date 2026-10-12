from __future__ import annotations
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PS=ROOT/"ACCEPT-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5-HOVED-PC.ps1"
CMD=ROOT/"ACCEPT-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5-HOVED-PC.cmd"

def req(text,needle):
    if needle not in text:
        raise AssertionError(f"Missing {needle!r}")

def main():
    ps=PS.read_text(encoding="utf-8")
    cmd=CMD.read_text(encoding="utf-8")
    for n in (
        "STATIC -> CANDIDATE SELFTEST -> ONE CLICK -> EVIDENCE",
        "RAH-RAVEN-STUDIO-ONECLICK-V3.1-CANDIDATE.5.ps1",
        "RAVEN-STUDIO-ONECLICK-LATEST.json",
        "POSTCHECK Desktop Bridge",
        "POSTCHECK Agent Runner",
        "read-only-allowlist confirmed",
        "LM Studio",
        "offline (optional; does not block acceptance)",
        "FINAL: ",
        "RAVEN-STUDIO-HOVED-PC-ACCEPTANCE-LATEST.json",
    ):
        req(ps,n)

    # Match executable mutation commands, not the literal deny-list strings
    # embedded in the acceptance policy itself.
    forbidden_commands=(
        r"(?im)^\s*(?:&\s*)?(?:pip(?:\.exe)?|python(?:\.exe)?\s+-m\s+pip|py(?:\.exe)?\s+-m\s+pip)\s+install\b",
        r"(?im)^\s*Stop-Process\b",
        r"(?im)^\s*New-NetFirewallRule\b",
        r"(?im)^\s*Set-NetFirewallRule\b",
    )
    for pattern in forbidden_commands:
        if re.search(pattern,ps):
            raise AssertionError(f"Acceptance contains forbidden executable mutation: {pattern}")

    req(cmd,"ACCEPT-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5-HOVED-PC.ps1")
    req(cmd,"FINAL: PASS")
    req(cmd,"FINAL: FAIL")
    print("RAH RAVEN STUDIO CANDIDATE.5 HOVED-PC ACCEPTANCE CONTRACT: PASS")

if __name__=="__main__":
    main()

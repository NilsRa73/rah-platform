from __future__ import annotations
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def txt(n): return (ROOT/n).read_text(encoding="utf-8")
def req(t,n):
    if n not in t: raise AssertionError(f"Missing {n!r}")
def main():
    m=json.loads(txt("RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.json"))
    studio=txt("RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.html")
    diag=txt("RAH-RAVEN-STUDIO-DIAGNOSTICS-V3.1-CANDIDATE.5.html")
    orch=txt("RAH-RAVEN-STUDIO-ONECLICK-V3.1-CANDIDATE.5.ps1")
    repair=txt("SAFE-REPAIR-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.ps1")
    start=txt("START-HER-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.cmd")
    assert m["version"]=="3.1.0-candidate.5"
    assert m["based_on"]=="3.1.0-candidate.4"
    oc=m["one_click_startup"]
    assert oc["precheck"] and oc["safe_repair"] and oc["postcheck"] and oc["opens_studio"]
    assert oc["final_states"]==["PASS","FAIL"]
    assert oc["lm_studio_optional"] is True
    for n in ("STARTUP PASS","STARTUP FAIL","startupParams","RAH-RAVEN-STUDIO-DIAGNOSTICS-V3.1-CANDIDATE.5.html"): req(studio,n)
    for n in ("RUN FULL CHECK","SAFE REPAIR","RUN ONE-CLICK STARTUP","Agent Runner","Root cause"): req(diag,n)
    for n in ("PRECHECK","POSTCHECK","Get-Snapshot","Safe Repair","RAVEN-STUDIO-ONECLICK-LATEST.json","read-only-allowlist"): req(orch,n)
    if "pip install" in orch or "Stop-Process" in orch: raise AssertionError("Unsafe orchestrator mutation")
    if "pip install" in repair or "Stop-Process" in repair: raise AssertionError("Unsafe repair mutation")
    req(repair,"-WindowStyle Hidden")
    req(start,"RAH-RAVEN-STUDIO-ONECLICK-V3.1-CANDIDATE.5.ps1")
    for h in (studio,diag):
        if "https://" in h: raise AssertionError("Candidate runtime must stay local-only")
        for u in re.findall(r"http://[^\"'\s<]+",h):
            if not (u.startswith("http://127.0.0.1:18765/") or u.startswith("http://127.0.0.1:1234/")):
                raise AssertionError(f"Unexpected URL: {u}")
    print("RAH RAVEN STUDIO v3.1 CANDIDATE.5 CONTRACT: PASS")
if __name__=="__main__": main()

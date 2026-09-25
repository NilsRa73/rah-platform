from __future__ import annotations
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
STUDIO=ROOT/"RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.html"
DIAG=ROOT/"RAH-RAVEN-STUDIO-DIAGNOSTICS-V3.1-CANDIDATE.4.html"
MANIFEST=ROOT/"RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.json"
REPAIR=ROOT/"SAFE-REPAIR-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.ps1"
START=ROOT/"START-HER-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.cmd"
ACCEPT=ROOT/"RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.ps1"

def req(text,needle):
    if needle not in text: raise AssertionError(f"Missing {needle!r}")

def main():
    studio=STUDIO.read_text(encoding="utf-8")
    diag=DIAG.read_text(encoding="utf-8")
    manifest=json.loads(MANIFEST.read_text(encoding="utf-8"))
    repair=REPAIR.read_text(encoding="utf-8")
    start=START.read_text(encoding="utf-8")
    accept=ACCEPT.read_text(encoding="utf-8")

    assert manifest["version"]=="3.1.0-candidate.4"
    assert manifest["stage"]=="candidate"
    assert manifest["based_on"]=="3.1.0-candidate.3"
    assert manifest["diagnostics_contract"]["groups"]==["launch","bridge","lm_studio","agent_runner"]
    assert manifest["diagnostics_contract"]["bridge_timeout_ms"]==2500
    assert manifest["safe_repair"]["install_dependencies"] is False
    assert manifest["safe_repair"]["firewall_changes"] is False
    assert manifest["safe_repair"]["network_changes"] is False
    assert manifest["safe_repair"]["model_downloads"] is False
    assert manifest["safe_repair"]["process_kills"] is False

    req(studio,"RAH-RAVEN-STUDIO-DIAGNOSTICS-V3.1-CANDIDATE.4.html")
    req(studio,"SAFE-REPAIR-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.cmd")
    for marker in ("App Launch","Desktop Bridge","LM Studio","Agent Runner","Root cause","RUN FULL CHECK","SAFE REPAIR","RETEST FAILED ONLY","COPY REPORT","SAVE JSON","AbortController","127.0.0.1:18765/health","127.0.0.1:18765/agent/capabilities"):
        req(diag,marker)
    if "https://" in diag: raise AssertionError("Diagnostics must stay local-only")
    urls=re.findall(r"http://[^\"'\s<]+",diag)
    for url in urls:
        if not (url.startswith("http://127.0.0.1:18765/") or url.startswith("http://127.0.0.1:1234/")):
            raise AssertionError(f"Unexpected URL {url}")
    req(repair,"-WindowStyle Hidden")
    if "pip install" in repair: raise AssertionError("Safe Repair must not install dependencies")
    if "Stop-Process" in repair: raise AssertionError("Safe Repair must not kill processes")
    req(start,"RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.ps1")
    req(accept,"3.1.0-candidate.4")
    print("RAH RAVEN STUDIO v3.1 CANDIDATE.4 CONTRACT: PASS")

if __name__=="__main__": main()

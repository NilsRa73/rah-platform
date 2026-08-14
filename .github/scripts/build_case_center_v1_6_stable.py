from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
FROZEN=[
 "RAH-RAVEN-CASE-CENTER.html","desktop-bridge/server_v16.py","desktop-bridge/test_case_v16.py",
 ".github/workflows/validate-case-center-v16.yml","RAH-RAVEN-START.html","RAH-RAVEN-CORE-DEMO.html",
 "RAH-RAVEN-VISION-CORE.html","raven-vision-core.js","RAH-RAVEN-COUNCIL.html","raven-council.js",
 "RAH-RAVEN-AGENT-RUNNER.html","desktop-bridge/agent_runner.py","RAH-RAVEN-MEMORY-SYNC.html",
 "raven-chronicle-sync.js","RAH-RAVEN-MISSION-CONTROL.html","RAH-RAVEN-PROJECT.html",
 "RAH-RAVEN-NOW-V2.html","RAH-RAVEN-CHRONICLE-LIVE.html","desktop-bridge/server_v17.py",
 "index.html","system-health-v1.7.js","RAH-HOME-CONTROL.html","raven-checkpoint-policy.js",
]
EXPECTED_CORE={"raven_vision":"0.6","raven_council":"0.3","agent_runner":"0.3","memory_sync":"0.2","mission_control":"2.9","project_focus":"2.4","raven_core":"1.12","raven_now":"2.17","raven_studio":"2.8"}
def p(x):return ROOT/x
def digest(x):return hashlib.sha256(p(x).read_bytes()).hexdigest()
before={x:digest(x) for x in FROZEN}

manifest_path=p("RAH-RAVEN-CASE-CENTER-VERSION.json")
manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
assert manifest["product"]=="RAH Raven Case Center"
assert manifest["version"]=="1.6.0"
assert manifest["stage"]=="candidate"
assert manifest["next_milestone"]=="stable-gate"
assert manifest["features"]["foreign_browser_origin_guard"] is True
assert manifest["features"]["cors_wildcard"] is False
manifest.update({
 "stage":"stable",
 "next_milestone":None,
 "stable_since":"2026-08-14",
 "development_paused":True,
 "change_policy":"bugfix-only-until-explicit-reopen",
 "stable_release_gate":{"status":"passed","gate_version":"1.0.0","runtime_files_frozen":True},
})
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

master_path=p("RAH-RAVEN-VERSION.json")
master=json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"]==EXPECTED_CORE
assert master["privacy"]["raven_chronicle_stable"] is True
assert master["privacy"]["system_health_stable"] is True
assert master["privacy"]["case_center_stable"] is False
master["privacy"]["case_center_stable"]=True
master_path.write_text(json.dumps(master,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

test_path=p("tests/raven-case-center-v16.test.mjs")
test=test_path.read_text(encoding="utf-8")
repls={
 'assert.equal(component.stage, "candidate");':'assert.equal(component.stage, "stable");',
 'assert.equal(component.next_milestone, "stable-gate");':'assert.equal(component.next_milestone, null);\nassert.equal(component.stable_since, "2026-08-14");\nassert.equal(component.development_paused, true);\nassert.equal(component.change_policy, "bugfix-only-until-explicit-reopen");\nassert.equal(component.stable_release_gate?.status, "passed");\nassert.equal(component.stable_release_gate?.gate_version, "1.0.0");\nassert.equal(component.stable_release_gate?.runtime_files_frozen, true);',
 'assert.equal(master.privacy.case_center_stable, false);':'assert.equal(master.privacy.case_center_stable, true);',
 'console.log("RAH Raven Case Center v1.6 candidate contract passed.");':'console.log("RAH Raven Case Center v1.6 stable contract passed with runtime freeze preserved.");',
}
for old,new in repls.items():
 if test.count(old)!=1:raise RuntimeError(f"Stable test anchor missing/ambiguous: {old}")
 test=test.replace(old,new,1)
test_path.write_text(test,encoding="utf-8")

after={x:digest(x) for x in FROZEN}
changed=[x for x in FROZEN if before[x]!=after[x]]
if changed:raise RuntimeError(f"Stable Gate changed frozen Case Center/Raven runtime: {changed}")
master=json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"]==EXPECTED_CORE
print("Built Case Center v1.6 stable metadata contract; runtime and nine-core platform freeze preserved.")

from pathlib import Path
import json

manifest_path=Path('RAH-RAVEN-VERSION.json')
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['version']='2.0.31'
manifest['released_at']='2026-08-13'
manifest['summary']='RAH Raven 2.0.31 adds one aggregate Release Gate for the temporary-finish runway. It does not add runtime features. The gate pins the current component versions, verifies the package manifest and core safety boundaries, and runs the established Raven semantic tests as one release-candidate check before the planned 2.0.32 temporary stable freeze.'
manifest['release_gate']={
  'stage':'release-candidate',
  'temporary_stable_target':'2.0.32',
  'runtime_feature_change':False,
  'component_versions':{
    'raven_now':'2.17',
    'raven_studio':'2.8',
    'raven_core':'1.12',
    'raven_vision':'0.5',
    'mission_control':'2.8',
    'project_focus':'2.4',
    'raven_council':'0.2',
    'agent_runner':'0.2',
    'memory_sync':'0.1'
  }
}
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

test=Path('tests/raven-release-gate.test.mjs')
test.write_text(r'''import assert from "node:assert/strict";
import fs from "node:fs";

const read = p => fs.readFileSync(p,"utf8");
const manifest = JSON.parse(read("RAH-RAVEN-VERSION.json"));
assert.equal(manifest.product,"RAH Raven");
assert.equal(manifest.version,"2.0.31");
assert.equal(manifest.launcher,"3.0");
assert.equal(manifest.release_gate?.stage,"release-candidate");
assert.equal(manifest.release_gate?.temporary_stable_target,"2.0.32");
assert.equal(manifest.release_gate?.runtime_feature_change,false);

const expected = {
  raven_now:["RAH-RAVEN-NOW-V2.html","RAH Raven Now v2.17","2.17"],
  raven_studio:["RAH-RAVEN-START.html","RAH Raven Studio v2.8","2.8"],
  raven_core:["RAH-RAVEN-CORE-DEMO.html","RAH Raven Core Workflow v1.12","1.12"],
  raven_vision:["RAH-RAVEN-VISION-CORE.html","RAH Raven Vision Core v0.5","0.5"],
  mission_control:["RAH-RAVEN-MISSION-CONTROL.html","RAH Raven Mission Control v2.8","2.8"],
  project_focus:["RAH-RAVEN-PROJECT.html","RAH Raven Project Focus v2.4","2.4"],
  raven_council:["RAH-RAVEN-COUNCIL.html","RAH Raven Council v0.2","0.2"],
  agent_runner:["RAH-RAVEN-AGENT-RUNNER.html","RAH Raven Agent Runner v0.2","0.2"],
  memory_sync:["RAH-RAVEN-MEMORY-SYNC.html","RAH Raven Memory Sync v0.1","0.1"]
};
for(const [key,[file,marker,version]] of Object.entries(expected)){
  assert.equal(manifest.release_gate.component_versions[key],version,`${key} version pin`);
  assert.ok(manifest.files.includes(file),`${file} must be in package manifest`);
  assert.match(read(file),new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g,"\\$&")),`${file} identity`);
}

for(const file of manifest.files) assert.ok(fs.existsSync(file),`Missing manifest file: ${file}`);
const privacy=manifest.privacy;
for(const key of ["keylogging","clipboard_capture","hidden_microphone","hidden_camera","automatic_sending","hidden_screen_capture"])
  assert.equal(privacy[key],false,`${key} must stay false`);
for(const key of [
  "raven_core_continue_navigation_only",
  "raven_core_continue_no_storage_writes",
  "vision_chatgpt_mode_no_auto_send",
  "chatgpt_handoff_history_shared_policy_read_only",
  "chatgpt_handoff_receipt_shared_policy_read_only"
]) assert.equal(privacy[key],true,`${key} must stay true`);

const now=read("RAH-RAVEN-NOW-V2.html");
assert.match(now,/id="continueButton"/);
assert.match(now,/raven-checkpoint-policy\.js/);
const core=read("RAH-RAVEN-CORE-DEMO.html");
assert.match(core,/id="coreContinue"/);
assert.match(core,/KOPIER RAVEN STATUS TIL CHATGPT/);
const receipt=read("raven-handoff-receipt.js");
assert.doesNotMatch(receipt,/localStorage|sessionStorage|fetch\(|XMLHttpRequest|writeState\(|location\s*=|window\.open/);

console.log("RAH Raven 2.0.31 Release Gate: component identity, package and safety boundaries OK.");
''',encoding='utf-8')
print('Built Raven 2.0.31 release candidate metadata and aggregate gate.')

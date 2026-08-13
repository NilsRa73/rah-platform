import assert from "node:assert/strict";
import fs from "node:fs";
const core=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");
const now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");
const studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");
assert.match(core,/RAH Raven Core Workflow v1\.12/);
assert.match(now,/RAH Raven Now v2\.16/);
assert.match(studio,/RAH Raven Studio v2\.7/);
assert.match(core,/id="handoffResumePanel"/);
assert.match(core,/id="handoffResume"/);
assert.match(core,/function handoffResumeHref\(session\)/);
assert.match(core,/if\(!session\?\.source\|\|!session\.status\)return ""/);
assert.match(core,/params\.set\("handoffReturn","ready"\)/);
assert.match(core,/params\.set\("handoffStatus","ready"\)/);
assert.match(core,/if\(session\.image\)params\.set\("handoffImage","ready"\)/);
assert.match(core,/resumePanel\.hidden=!resumeHref/);
assert.match(core,/FORTSETT TIL \$\{session\.source\.key==="now"\?"RAVEN NOW":"RAVEN STUDIO"\}/);
assert.match(now,/id="handoffReturnNotice"/);
assert.match(studio,/id="handoffReturnNotice"/);
assert.match(now,/function renderHandoffReceipt\(params\)/);
assert.match(studio,/function renderHandoffReceipt\(params\)/);
const resumeFn=core.split("function handoffResumeHref(session){",2)[1].split("function renderHandoffSession(){",1)[0];
assert.doesNotMatch(resumeFn,/localStorage|sessionStorage|fetch\(|writeState\(|activeMission\s*=|activeProject\s*=|\.done\s*=/);
for(const text of [now,studio]){
  assert.match(text,/Dette bekrefter ikke mottak i ChatGPT/);
  assert.doesNotMatch(text,/api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);
}
assert.match(now,/id="continueButton" href="RAH-RAVEN-MISSION-CONTROL\.html"/);
console.log("Raven 2.0.27 keeps Handoff Resume status-gated and URL-only while source surfaces show a local receipt.");

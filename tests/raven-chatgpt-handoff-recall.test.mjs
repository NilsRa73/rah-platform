import assert from "node:assert/strict";
import fs from "node:fs";
const core=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");
const policy=fs.readFileSync("raven-handoff-history-lite.js","utf8");
function between(text,start,end,label){const a=text.indexOf(start);assert.notEqual(a,-1,`${label}: start missing`);const b=text.indexOf(end,a+start.length);assert.notEqual(b,-1,`${label}: end missing`);return text.slice(a+start.length,b)}
assert.match(core,/RAH Raven Core Workflow v1\.12/);
assert.match(core,/Core v1\.12 · SHARED HANDOFF RECALL/);
assert.match(core,/<script src="raven-handoff-history-lite\.js"><\/script>/);
assert.match(core,/const HANDOFF_HISTORY = window\.RavenHandoffHistoryLite/);
for(const id of ["handoffRecall","handoffRecallTitle","handoffRecallMeta"])assert.match(core,new RegExp(`id="${id}"`));
assert.match(core,/SIST MANUELT LAGREDE HANDOFF · READ ONLY/);
assert.match(core,/function readHandoffRecall\(\)\{return HANDOFF_HISTORY\.read\(localStorage\);\}/);
assert.match(core,/const item=readHandoffRecall\(\),view=HANDOFF_HISTORY\.describe\(item\)/);
const read=between(core,"function readHandoffRecall(){","function renderHandoffRecall(){","Recall read");
const render=between(core,"function renderHandoffRecall(){","function chatGPTSupportSnapshot(){","Recall render");
for(const body of [read,render]){
  assert.doesNotMatch(body,/localStorage\.setItem|localStorage\.removeItem|sessionStorage|fetch\(|writeState\(|activeMission\s*=|activeProject\s*=|\.done\s*=|\/agent\/run|navigator\.clipboard|imageData|dataUrl|Blob\(/i);
  assert.doesNotMatch(body,/coreContinue.*href|continueButton.*href|recommendedCheckpointButton.*href/);
}
assert.doesNotMatch(read,/JSON\.parse\(localStorage\.getItem\(/);
assert.match(render,/\.textContent=view\.(title|meta)/);
assert.doesNotMatch(render,/\.innerHTML\s*=/);
const support=between(core,"function chatGPTSupportSnapshot(){","async function copySupportSnapshot(){","Support snapshot");
assert.doesNotMatch(support,/localStorage|sessionStorage|HANDOFF_HISTORY/);
const session=between(core,"function handoffSession(){","async function copySupportSnapshot(){","Handoff Session area");
assert.doesNotMatch(session,/localStorage|sessionStorage|HANDOFF_HISTORY/);
assert.match(core,/renderHandoffRecall\(\);/);
assert.doesNotMatch(core,/localStorage\.setItem\(HANDOFF_HISTORY/);
assert.doesNotMatch(core,/localStorage\.removeItem\(HANDOFF_HISTORY/);
assert.doesNotMatch(policy,/setItem\(|removeItem\(|localStorage|sessionStorage/);
assert.doesNotMatch(core,/api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);
console.log("Raven 2.0.29 Core Recall consumes one shared read-only History Lite policy without changing operational state.");

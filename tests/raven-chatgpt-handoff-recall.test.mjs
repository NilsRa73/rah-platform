import assert from "node:assert/strict";
import fs from "node:fs";
const core=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");
function between(text,start,end,label){const a=text.indexOf(start);assert.notEqual(a,-1,`${label}: start missing`);const b=text.indexOf(end,a+start.length);assert.notEqual(b,-1,`${label}: end missing`);return text.slice(a+start.length,b)}
assert.match(core,/RAH Raven Core Workflow v1\.11/);
assert.match(core,/Core v1\.11 · HANDOFF RECALL/);
for(const id of ["handoffRecall","handoffRecallTitle","handoffRecallMeta"])assert.match(core,new RegExp(`id="${id}"`));
assert.match(core,/SIST MANUELT LAGREDE HANDOFF · READ ONLY/);
assert.match(core,/rah\.raven\.chatgpt-handoff-history-lite-v1/);
assert.match(core,/function readHandoffRecall\(\)/);
assert.match(core,/function renderHandoffRecall\(\)/);
assert.match(core,/localStorage\.getItem\(HANDOFF_HISTORY_KEY\)/);
assert.match(core,/\["now","studio"\]\.includes\(raw\.surface\)/);
assert.match(core,/Object\.freeze\(\{version:1,surface:raw\.surface,status:raw\.status===true,image:raw\.image===true/);
assert.match(core,/Ingen lagret kvittering/);
assert.match(core,/ingen prompt, tekst, analyse eller bildefil leses/i);
const read=between(core,"function readHandoffRecall(){","function renderHandoffRecall(){","Recall read");
const render=between(core,"function renderHandoffRecall(){","function chatGPTSupportSnapshot(){","Recall render");
for(const body of [read,render]){
  assert.doesNotMatch(body,/localStorage\.setItem|localStorage\.removeItem|sessionStorage|fetch\(|writeState\(|activeMission\s*=|activeProject\s*=|\.done\s*=|\/agent\/run|navigator\.clipboard|imageData|dataUrl|Blob\(/i);
  assert.doesNotMatch(body,/coreContinue.*href|continueButton.*href|recommendedCheckpointButton.*href/);
}
assert.match(read,/localStorage\.getItem/);
assert.doesNotMatch(read,/prompt|analysis|answer|message|body|imageData|dataUrl|blob/i);
assert.match(render,/\.textContent=/);
assert.doesNotMatch(render,/\.innerHTML\s*=/);
const support=between(core,"function chatGPTSupportSnapshot(){","async function copySupportSnapshot(){","Support snapshot");
assert.doesNotMatch(support,/localStorage|sessionStorage/);
const session=between(core,"function handoffSession(){","async function copySupportSnapshot(){","Handoff Session area");
assert.doesNotMatch(session,/localStorage|sessionStorage/);
assert.match(core,/renderHandoffRecall\(\);/);
assert.equal((core.match(/localStorage\.getItem\(HANDOFF_HISTORY_KEY\)/g)||[]).length,1);
assert.equal((core.match(/localStorage\.setItem\(HANDOFF_HISTORY_KEY/g)||[]).length,0);
assert.equal((core.match(/localStorage\.removeItem\(HANDOFF_HISTORY_KEY/g)||[]).length,0);
assert.doesNotMatch(core,/api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);
console.log("Raven 2.0.28 Handoff Recall reads one explicit History Lite receipt as metadata-only read-only context, isolated from support snapshot and URL-only Session.");

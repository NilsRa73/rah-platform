import assert from "node:assert/strict";
import fs from "node:fs";
const now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");
const studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");
function between(text,start,end,label){const a=text.indexOf(start);assert.notEqual(a,-1,`${label}: start missing`);const b=text.indexOf(end,a+start.length);assert.notEqual(b,-1,`${label}: end missing`);return text.slice(a+start.length,b)}
assert.match(now,/RAH Raven Now v2\.15/);
assert.match(studio,/RAH Raven Studio v2\.6/);
for(const text of [now,studio]){
  for(const id of ["handoffReceiptSave","handoffHistoryLite","handoffHistoryTitle","handoffHistoryMeta","handoffHistoryDelete"])assert.match(text,new RegExp(`id="${id}"`));
  assert.match(text,/rah\.raven\.chatgpt-handoff-history-lite-v1/);
  assert.match(text,/LAGRE KVITTERING/);
  assert.match(text,/SIST LAGREDE HANDOFF · MANUELL/);
  assert.match(text,/SLETT LAGRET/);
  assert.match(text,/ingen tekst eller bildefil/i);
  assert.match(text,/function readHandoffHistory\(\)/);
  assert.match(text,/function renderHandoffHistory\(\)/);
  assert.match(text,/function saveHandoffReceipt\(\)/);
  assert.match(text,/function deleteHandoffHistory\(\)/);
  assert.doesNotMatch(text,/saveHandoffReceipt\(\);/);
  assert.doesNotMatch(text,/api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);
}
const nowSave=between(now,"function saveHandoffReceipt(){","function deleteHandoffHistory(){","Now save");
const studioSave=between(studio,"function saveHandoffReceipt(){","function deleteHandoffHistory(){","Studio save");
for(const body of [nowSave,studioSave]){
  assert.match(body,/handoffReceipt\(new URLSearchParams\(location\.search\)\)/);
  assert.match(body,/localStorage\.setItem\(HANDOFF_HISTORY_KEY,JSON\.stringify\(item\)\)/);
  assert.match(body,/version:1/);
  assert.match(body,/status:receipt\.status/);
  assert.match(body,/image:receipt\.image/);
  assert.match(body,/savedAt:new Date\(\)\.toISOString\(\)/);
  assert.doesNotMatch(body,/prompt|message|body|analysis|answer|imageData|dataUrl|blob|clipboard|fetch\(|writeState\(|activeMission\s*=|activeProject\s*=|\.done\s*=|\/agent\/run/i);
  assert.doesNotMatch(body,/continueButton.*href|recommendedCheckpointButton.*href/);
}
assert.match(nowSave,/surface:'now'/);
assert.match(studioSave,/surface:'studio'/);
const nowDelete=between(now,"function deleteHandoffHistory(){","if(params.get('projectActivated')==='1')","Now delete");
const studioDelete=between(studio,"function deleteHandoffHistory(){","renderHandoffHistory();","Studio delete");
for(const body of [nowDelete,studioDelete]){
  assert.match(body,/localStorage\.removeItem\(HANDOFF_HISTORY_KEY\)/);
  assert.doesNotMatch(body,/setItem\(|writeState\(|activeMission\s*=|activeProject\s*=|\.done\s*=/);
}
assert.equal((now.match(/localStorage\.setItem\(HANDOFF_HISTORY_KEY/g)||[]).length,1);
assert.equal((studio.match(/localStorage\.setItem\(HANDOFF_HISTORY_KEY/g)||[]).length,1);
assert.match(now,/\$\('handoffReceiptSave'\)\.onclick=saveHandoffReceipt/);
assert.match(studio,/\$\('handoffReceiptSave'\)\.onclick=saveHandoffReceipt/);
assert.match(now,/\$\('handoffHistoryDelete'\)\.onclick=deleteHandoffHistory/);
assert.match(studio,/\$\('handoffHistoryDelete'\)\.onclick=deleteHandoffHistory/);
assert.match(now,/id="continueButton" href="RAH-RAVEN-MISSION-CONTROL\.html"/);
console.log("Raven 2.0.27 Handoff History Lite is explicit-save, single-record, metadata-only and operationally isolated.");

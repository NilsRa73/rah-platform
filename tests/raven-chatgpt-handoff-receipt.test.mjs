import assert from "node:assert/strict";
import fs from "node:fs";
const now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");
const studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");
const policy=fs.readFileSync("raven-handoff-receipt.js","utf8");
function between(text,start,end,label){const a=text.indexOf(start);assert.notEqual(a,-1,`${label}: start missing`);const b=text.indexOf(end,a+start.length);assert.notEqual(b,-1,`${label}: end missing`);return text.slice(a+start.length,b)}
assert.match(now,/RAH Raven Now v2\.17/);
assert.match(studio,/RAH Raven Studio v2\.8/);
for(const text of [now,studio]){
  assert.match(text,/id="handoffReturnNotice"/);
  assert.match(text,/id="handoffReceiptStatus"/);
  assert.match(text,/id="handoffReceiptImage"/);
  assert.match(text,/id="handoffReceiptClose"/);
  assert.match(text,/<script src="raven-handoff-receipt\.js"><\/script>/);
  assert.match(text,/HANDOFF_RECEIPT=window\.RavenHandoffReceipt/);
  assert.match(text,/function handoffReceipt\(params\)\{return HANDOFF_RECEIPT\.parse\(params\);\}/);
  assert.match(text,/HANDOFF_RECEIPT\.describe\(receipt\)/);
  assert.match(text,/for\(const key of HANDOFF_RECEIPT\.QUERY_KEYS\)url\.searchParams\.delete\(key\)/);
  assert.match(text,/history\.replaceState\(\{\},'',`\$\{url\.pathname\}\$\{url\.search\}\$\{url\.hash\}`\)/);
  assert.doesNotMatch(text,/params\.get\('handoffReturn'\)!=='ready'/);
  assert.doesNotMatch(text,/searchParams\.delete\('projectActivated'\)/);
}
assert.match(policy,/const QUERY_KEYS=Object\.freeze\(\['handoffReturn','handoffStatus','handoffImage'\]\)/);
assert.match(policy,/params\.get\('handoffReturn'\)!==READY/);
assert.match(policy,/STATUS: KLAR/);
assert.match(policy,/BILDE: KLAR/);
assert.match(policy,/BILDE: IKKE MARKERT/);
assert.match(policy,/Dette bekrefter ikke mottak i ChatGPT/);
const nowReceipt=between(now,"function handoffReceipt(params){","function closeHandoffReceipt(){","Now receipt");
const nowClose=between(now,"function closeHandoffReceipt(){","function renderHandoffReceipt(params){","Now close");
const nowRender=between(now,"function renderHandoffReceipt(params){","const params=new URLSearchParams(location.search)","Now render");
const studioReceipt=between(studio,"function handoffReceipt(params){","function closeHandoffReceipt(){","Studio receipt");
const studioClose=between(studio,"function closeHandoffReceipt(){","function renderHandoffReceipt(params){","Studio close");
const studioRender=between(studio,"function renderHandoffReceipt(params){","renderHandoffReceipt(handoffParams);","Studio render");
for(const body of [nowReceipt,nowClose,nowRender,studioReceipt,studioClose,studioRender]){
  assert.doesNotMatch(body,/localStorage|sessionStorage|fetch\(|writeState\(|activeMission\s*=|activeProject\s*=|\.done\s*=|\/agent\/run/);
  assert.doesNotMatch(body,/continueButton.*href|recommendedCheckpointButton.*href/);
}
for(const body of [nowClose,studioClose]){
  assert.match(body,/HANDOFF_RECEIPT\.QUERY_KEYS/);
  assert.doesNotMatch(body,/location\.href\s*=|location\.assign|location\.replace/);
}
assert.match(now,/\$\('handoffReceiptClose'\)\.onclick=closeHandoffReceipt/);
assert.match(studio,/\$\('handoffReceiptClose'\)\.onclick=closeHandoffReceipt/);
assert.match(now,/id="continueButton" href="RAH-RAVEN-MISSION-CONTROL\.html"/);
assert.doesNotMatch(policy,/localStorage|sessionStorage|setItem\(|removeItem\(|fetch\(|navigator\.|location\.|history\.|window\.open/);
console.log("Raven 2.0.30 Handoff Receipt uses one shared read-only URL policy; close/save/delete remain explicit local actions.");

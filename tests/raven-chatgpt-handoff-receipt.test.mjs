import assert from "node:assert/strict";
import fs from "node:fs";
const now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");
const studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");
function between(text,start,end,label){const a=text.indexOf(start);assert.notEqual(a,-1,`${label}: start missing`);const b=text.indexOf(end,a+start.length);assert.notEqual(b,-1,`${label}: end missing`);return text.slice(a+start.length,b)}
for(const text of [now,studio]){
  assert.match(text,/id="handoffReturnNotice"/);
  assert.match(text,/id="handoffReceiptStatus"/);
  assert.match(text,/id="handoffReceiptImage"/);
  assert.match(text,/id="handoffReceiptClose"/);
  assert.match(text,/function handoffReceipt\(params\)/);
  assert.match(text,/function closeHandoffReceipt\(\)/);
  assert.match(text,/function renderHandoffReceipt\(params\)/);
  assert.match(text,/params\.get\('handoffReturn'\)!=='ready'/);
  assert.match(text,/STATUS: KLAR/);
  assert.match(text,/BILDE: KLAR/);
  assert.match(text,/BILDE: IKKE MARKERT/);
  assert.match(text,/Dette bekrefter ikke mottak i ChatGPT/);
  assert.match(text,/history\.replaceState\(\{\},'',`\$\{url\.pathname\}\$\{url\.search\}\$\{url\.hash\}`\)/);
  assert.match(text,/\['handoffReturn','handoffStatus','handoffImage'\]/);
  assert.doesNotMatch(text,/searchParams\.delete\('projectActivated'\)/);
}
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
assert.match(now,/\$\('handoffReceiptClose'\)\.onclick=closeHandoffReceipt/);
assert.match(studio,/\$\('handoffReceiptClose'\)\.onclick=closeHandoffReceipt/);
assert.doesNotMatch(nowClose+studioClose,/location\.href\s*=|location\.assign|location\.replace/);
assert.match(now,/id="continueButton" href="RAH-RAVEN-MISSION-CONTROL\.html"/);
console.log("Raven 2.0.26 Handoff Receipt is explicit, URL-cleanup-only and does not mutate Raven state.");

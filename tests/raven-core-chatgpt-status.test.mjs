import assert from "node:assert/strict";
import fs from "node:fs";

const html=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");

function between(text,start,end){
  const a=text.indexOf(start);
  assert.notEqual(a,-1,`missing start: ${start}`);
  const b=text.indexOf(end,a+start.length);
  assert.notEqual(b,-1,`missing end: ${end}`);
  return text.slice(a+start.length,b);
}

assert.match(html,/RAH Raven Core Workflow v1\.12/);
assert.match(html,/Core v1\.12 · SHARED HANDOFF RECALL/);
for(const id of ["copyCoreStatus","downloadCoreStatus","supportShareStatus"]){
  assert.match(html,new RegExp(`id="${id}"`));
}
assert.match(html,/KOPIER STATUS/);
assert.match(html,/STATUS TXT/);
assert.match(html,/Ingen bilder, prompts eller analysesvar inkluderes/);
assert.match(html,/function chatGPTSupportSnapshot\(/);
assert.match(html,/async function copySupportSnapshot\(/);
assert.match(html,/function downloadSupportSnapshot\(/);

const snapshot=between(html,"function chatGPTSupportSnapshot(){","async function copySupportSnapshot(){");
for(const marker of [
  "CHECKPOINT.contextSnapshot",
  "CHECKPOINT.recommendSnapshot",
  "snapshot.activeProject",
  "snapshot.mission",
  "snapshot.blocker",
  "snapshot.nextStep",
  "snapshot.relation",
  "checkpoint.title",
  "nextActionHint"
]){
  assert.ok(snapshot.includes(marker),`missing support marker: ${marker}`);
}
for(const forbidden of [
  "latestVision",
  "latestCouncil",
  "latestAgent",
  ".prompt",
  ".answer",
  "imageData",
  "visionHistory",
  "localStorage",
  "fetch(",
  "writeState(",
  "/agent/run"
]){
  assert.equal(snapshot.includes(forbidden),false,`support snapshot leaked forbidden marker: ${forbidden}`);
}
assert.match(snapshot,/Automatisk sending: NEI/);
assert.match(snapshot,/Bilder\/prompts\/analysesvar inkludert: NEI/);

const copy=between(html,"async function copySupportSnapshot(){","function downloadSupportSnapshot(){");
assert.match(copy,/navigator\.clipboard\?\.writeText/);
assert.match(copy,/await navigator\.clipboard\.writeText\(text\)/);
assert.doesNotMatch(copy,/fetch\(/);
assert.doesNotMatch(copy,/localStorage/);
assert.doesNotMatch(copy,/writeState\(/);
assert.doesNotMatch(copy,/\/agent\/run/);

const download=between(html,"function downloadSupportSnapshot(){","function render(){");
assert.match(download,/new Blob\(\[chatGPTSupportSnapshot\(\)\]/);
assert.match(download,/RAH-Raven-Status-ChatGPT\.txt/);
assert.doesNotMatch(download,/fetch\(/);
assert.doesNotMatch(download,/localStorage/);

assert.match(html,/\$\("copyCoreStatus"\)\.onclick=copySupportSnapshot/);
assert.match(html,/\$\("downloadCoreStatus"\)\.onclick=downloadSupportSnapshot/);
assert.doesNotMatch(html,/copySupportSnapshot\(\);/);
assert.doesNotMatch(html,/downloadSupportSnapshot\(\);/);

console.log("Raven Core v1.12 status handoff remains minimal, read-only and manual inside the source-aware handoff center.");

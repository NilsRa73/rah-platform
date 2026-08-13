from pathlib import Path
import json


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"{label}: marker missing: {old[:180]!r}")
    return text.replace(old, new, 1)


# Raven Now v2.15 — explicit single-receipt Handoff History Lite.
now_path = Path("RAH-RAVEN-NOW-V2.html")
now = now_path.read_text(encoding="utf-8")
for old, new in [
    ("<title>RAH Raven Now v2.14</title>", "<title>RAH Raven Now v2.15</title>"),
    ('<span class="badge">v2.14 · READ ONLY</span>', '<span class="badge">v2.15 · READ ONLY</span>'),
    ("RAH Raven Now v2.14 · shared Raven Context Snapshot", "RAH Raven Now v2.15 · shared Raven Context Snapshot"),
]:
    now = replace_once(now, old, new, "Now version")

old = '''<div id="handoffReturnNotice" class="activation-notice" aria-live="polite">
  <strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span>
  <div class="row" style="margin-top:9px">
    <span id="handoffReceiptStatus" class="badge good">STATUS: KLAR</span>
    <span id="handoffReceiptImage" class="badge">BILDE: IKKE MARKERT</span>
    <button class="btn" id="handoffReceiptClose" type="button">LUKK KVITTERING</button>
  </div>
</div>'''
new = '''<div id="handoffReturnNotice" class="activation-notice" aria-live="polite">
  <strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span>
  <div class="row" style="margin-top:9px">
    <span id="handoffReceiptStatus" class="badge good">STATUS: KLAR</span>
    <span id="handoffReceiptImage" class="badge">BILDE: IKKE MARKERT</span>
    <button class="btn" id="handoffReceiptSave" type="button">LAGRE KVITTERING</button>
    <button class="btn" id="handoffReceiptClose" type="button">LUKK KVITTERING</button>
  </div>
</div>
<div id="handoffHistoryLite" class="checkpoint" hidden>
  <small>SIST LAGREDE HANDOFF · MANUELL</small>
  <strong id="handoffHistoryTitle">Ingen lagret kvittering</strong>
  <p id="handoffHistoryMeta">Kun statusmarkør, bildemarkør, kildeflate og tidspunkt kan lagres eksplisitt.</p>
  <button class="btn" id="handoffHistoryDelete" type="button">SLETT LAGRET</button>
</div>'''
now = replace_once(now, old, new, "Now History Lite panel")

history_now = r'''const HANDOFF_HISTORY_KEY='rah.raven.chatgpt-handoff-history-lite-v1';
  function readHandoffHistory(){
    try{
      const raw=JSON.parse(localStorage.getItem(HANDOFF_HISTORY_KEY)||'null');
      if(!raw||raw.version!==1)return null;
      return Object.freeze({version:1,surface:raw.surface==='studio'?'studio':'now',status:raw.status===true,image:raw.image===true,savedAt:typeof raw.savedAt==='string'?raw.savedAt:''});
    }catch{return null;}
  }
  function renderHandoffHistory(){
    const item=readHandoffHistory(),panel=$('handoffHistoryLite');panel.hidden=!item;if(!item)return;
    const source=item.surface==='studio'?'Raven Studio':'Raven Now',status=item.status?'STATUS KLAR':'STATUS UKJENT',image=item.image?'BILDE KLAR':'UTEN BILDEMARKØR';
    let saved='ukjent tidspunkt';if(item.savedAt){const date=new Date(item.savedAt);if(!Number.isNaN(date.getTime()))saved=date.toLocaleString('nb-NO');}
    $('handoffHistoryTitle').textContent=`${source} · ${status} · ${image}`;
    $('handoffHistoryMeta').textContent=`Lagret ${saved}. Kun statusmarkør, bildemarkør, kildeflate og tidspunkt er lagret — ingen tekst eller bildefil.`;
  }
  function saveHandoffReceipt(){
    const receipt=handoffReceipt(new URLSearchParams(location.search));if(!receipt)return;
    const item=Object.freeze({version:1,surface:'now',status:receipt.status,image:receipt.image,savedAt:new Date().toISOString()});
    localStorage.setItem(HANDOFF_HISTORY_KEY,JSON.stringify(item));
    renderHandoffHistory();
  }
  function deleteHandoffHistory(){localStorage.removeItem(HANDOFF_HISTORY_KEY);renderHandoffHistory();}
  '''
now = replace_once(
    now,
    "  const params=new URLSearchParams(location.search);",
    "  const params=new URLSearchParams(location.search);" + history_now,
    "Now History Lite runtime",
)
now = replace_once(
    now,
    "renderHandoffReceipt(params);$('handoffReceiptClose').onclick=closeHandoffReceipt;$('refresh').onclick=refresh;",
    "renderHandoffReceipt(params);renderHandoffHistory();$('handoffReceiptSave').onclick=saveHandoffReceipt;$('handoffReceiptClose').onclick=closeHandoffReceipt;$('handoffHistoryDelete').onclick=deleteHandoffHistory;$('refresh').onclick=refresh;",
    "Now History Lite bindings",
)
now_path.write_text(now, encoding="utf-8")


# Raven Studio v2.6 — same explicit single receipt, shared dedicated key.
studio_path = Path("RAH-RAVEN-START.html")
studio = studio_path.read_text(encoding="utf-8")
for old, new in [
    ("<title>RAH Raven Studio v2.5</title>", "<title>RAH Raven Studio v2.6</title>"),
    ("Raven Studio v2.5 · Local-first", "Raven Studio v2.6 · Local-first"),
    ("RAH Raven Studio v2.5 · Raven 2.0.26", "RAH Raven Studio v2.6 · Raven 2.0.27"),
]:
    studio = replace_once(studio, old, new, "Studio version")

old = '''<div id="handoffReturnNotice" class="message" hidden aria-live="polite">
  <strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span>
  <div class="buttons" style="margin-top:9px">
    <span id="handoffReceiptStatus" class="tag">STATUS: KLAR</span>
    <span id="handoffReceiptImage" class="tag">BILDE: IKKE MARKERT</span>
    <button id="handoffReceiptClose" type="button">LUKK KVITTERING</button>
  </div>
</div>'''
new = '''<div id="handoffReturnNotice" class="message" hidden aria-live="polite">
  <strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span>
  <div class="buttons" style="margin-top:9px">
    <span id="handoffReceiptStatus" class="tag">STATUS: KLAR</span>
    <span id="handoffReceiptImage" class="tag">BILDE: IKKE MARKERT</span>
    <button id="handoffReceiptSave" type="button">LAGRE KVITTERING</button>
    <button id="handoffReceiptClose" type="button">LUKK KVITTERING</button>
  </div>
</div>
<div id="handoffHistoryLite" class="message" hidden>
  <strong>SIST LAGREDE HANDOFF · MANUELL</strong>
  <div id="handoffHistoryTitle" style="margin-top:6px;color:#f1d47d;font-weight:800">Ingen lagret kvittering</div>
  <div id="handoffHistoryMeta" style="margin-top:4px">Kun statusmarkør, bildemarkør, kildeflate og tidspunkt kan lagres eksplisitt.</div>
  <div class="buttons" style="margin-top:9px"><button id="handoffHistoryDelete" type="button">SLETT LAGRET</button></div>
</div>'''
studio = replace_once(studio, old, new, "Studio History Lite panel")

history_studio = r'''
const HANDOFF_HISTORY_KEY='rah.raven.chatgpt-handoff-history-lite-v1';
function readHandoffHistory(){
  try{
    const raw=JSON.parse(localStorage.getItem(HANDOFF_HISTORY_KEY)||'null');
    if(!raw||raw.version!==1)return null;
    return Object.freeze({version:1,surface:raw.surface==='studio'?'studio':'now',status:raw.status===true,image:raw.image===true,savedAt:typeof raw.savedAt==='string'?raw.savedAt:''});
  }catch{return null;}
}
function renderHandoffHistory(){
  const item=readHandoffHistory(),panel=$('handoffHistoryLite');panel.hidden=!item;if(!item)return;
  const source=item.surface==='studio'?'Raven Studio':'Raven Now',status=item.status?'STATUS KLAR':'STATUS UKJENT',image=item.image?'BILDE KLAR':'UTEN BILDEMARKØR';
  let saved='ukjent tidspunkt';if(item.savedAt){const date=new Date(item.savedAt);if(!Number.isNaN(date.getTime()))saved=date.toLocaleString('nb-NO');}
  $('handoffHistoryTitle').textContent=`${source} · ${status} · ${image}`;
  $('handoffHistoryMeta').textContent=`Lagret ${saved}. Kun statusmarkør, bildemarkør, kildeflate og tidspunkt er lagret — ingen tekst eller bildefil.`;
}
function saveHandoffReceipt(){
  const receipt=handoffReceipt(new URLSearchParams(location.search));if(!receipt)return;
  const item=Object.freeze({version:1,surface:'studio',status:receipt.status,image:receipt.image,savedAt:new Date().toISOString()});
  localStorage.setItem(HANDOFF_HISTORY_KEY,JSON.stringify(item));
  renderHandoffHistory();
}
function deleteHandoffHistory(){localStorage.removeItem(HANDOFF_HISTORY_KEY);renderHandoffHistory();}
renderHandoffHistory();
$('handoffReceiptSave').onclick=saveHandoffReceipt;
$('handoffHistoryDelete').onclick=deleteHandoffHistory;
'''
studio = replace_once(
    studio,
    "renderHandoffReceipt(handoffParams);\n$('handoffReceiptClose').onclick=closeHandoffReceipt;",
    "renderHandoffReceipt(handoffParams);" + history_studio + "$('handoffReceiptClose').onclick=closeHandoffReceipt;",
    "Studio History Lite runtime",
)
studio_path.write_text(studio, encoding="utf-8")


# Version-sensitive source-surface tests.
for name, pairs in {
    "tests/raven-now-v2.test.mjs": [("v2\\.14", "v2\\.15"), ("v2.14", "v2.15")],
    "tests/raven-chatgpt-handoff-entry.test.mjs": [
        ("v2\\.14", "v2\\.15"), ("v2\\.5", "v2\\.6"), ("Raven 2.0.26", "Raven 2.0.27")
    ],
    "tests/raven-chatgpt-handoff-resume.test.mjs": [
        ("v2\\.14", "v2\\.15"), ("v2\\.5", "v2\\.6"), ("Raven 2.0.26", "Raven 2.0.27")
    ],
    "tests/raven-chatgpt-handoff-receipt.test.mjs": [("Raven 2.0.26", "Raven 2.0.27")],
}.items():
    path=Path(name)
    text=path.read_text(encoding="utf-8")
    for old,new in pairs:text=text.replace(old,new)
    path.write_text(text,encoding="utf-8")


# New semantic test: persistence is explicit, single-record and metadata-only.
Path("tests/raven-chatgpt-handoff-history-lite.test.mjs").write_text(r'''import assert from "node:assert/strict";
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
''',encoding="utf-8")


# Manifest 2.0.27.
manifest_path=Path("RAH-RAVEN-VERSION.json")
m=json.loads(manifest_path.read_text(encoding="utf-8"))
if m.get("version")!="2.0.26":raise SystemExit(f"Expected 2.0.26 manifest, got {m.get('version')}")
m["version"]="2.0.27"
m["released_at"]="2026-08-13"
m["summary"]=(
    "RAH Raven 2.0.27 adds Handoff History Lite to Raven Now v2.15 and Raven Studio v2.6. "
    "A Handoff receipt is never logged automatically: the user must explicitly choose LAGRE KVITTERING. "
    "Only one latest receipt is kept under a dedicated local key, containing source surface, status marker, optional image marker and save timestamp. "
    "No prompt, text, analysis, answer or image bytes are stored. SLETT LAGRET explicitly removes the saved receipt. "
    "History Lite does not change Raven state, Studio state, projects, missions, steps or the normal FORTSETT route."
)
p=m.setdefault("privacy",{})
p.update({
    "chatgpt_handoff_history_lite_visible":True,
    "chatgpt_handoff_history_lite_explicit_save_only":True,
    "chatgpt_handoff_history_lite_auto_save":False,
    "chatgpt_handoff_history_lite_single_receipt":True,
    "chatgpt_handoff_history_lite_metadata_only":True,
    "chatgpt_handoff_history_lite_excludes_text_content":True,
    "chatgpt_handoff_history_lite_excludes_image_bytes":True,
    "chatgpt_handoff_history_lite_explicit_delete":True,
    "chatgpt_handoff_history_lite_shared_between_now_and_studio":True,
    "chatgpt_handoff_history_lite_dedicated_storage_key":True,
    "chatgpt_handoff_history_lite_does_not_change_continue_route":True,
})
manifest_path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

print("Built Raven 2.0.27 Handoff History Lite.")

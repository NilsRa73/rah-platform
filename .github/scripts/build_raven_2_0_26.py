from pathlib import Path
import json


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"{label}: marker missing: {old[:160]!r}")
    return text.replace(old, new, 1)


# Raven Now v2.14 — visible Handoff Receipt with explicit URL cleanup only.
now_path = Path("RAH-RAVEN-NOW-V2.html")
now = now_path.read_text(encoding="utf-8")
for old, new in [
    ("<title>RAH Raven Now v2.13</title>", "<title>RAH Raven Now v2.14</title>"),
    ('<span class="badge">v2.13 · READ ONLY</span>', '<span class="badge">v2.14 · READ ONLY</span>'),
    ("RAH Raven Now v2.13 · shared Raven Context Snapshot", "RAH Raven Now v2.14 · shared Raven Context Snapshot"),
]:
    now = replace_once(now, old, new, "Now version")

old = '<div id="handoffReturnNotice" class="activation-notice"><strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span></div>'
new = '''<div id="handoffReturnNotice" class="activation-notice" aria-live="polite">
  <strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span>
  <div class="row" style="margin-top:9px">
    <span id="handoffReceiptStatus" class="badge good">STATUS: KLAR</span>
    <span id="handoffReceiptImage" class="badge">BILDE: IKKE MARKERT</span>
    <button class="btn" id="handoffReceiptClose" type="button">LUKK KVITTERING</button>
  </div>
</div>'''
now = replace_once(now, old, new, "Now receipt panel")

old = """  const params=new URLSearchParams(location.search);if(params.get('projectActivated')==='1')$('activationNotice').classList.add('show');if(params.get('handoffReturn')==='ready'){const statusReady=params.get('handoffStatus')==='ready',imageReady=params.get('handoffImage')==='ready';$('handoffReturnNotice').classList.add('show');$('handoffReturnMeta').textContent=statusReady?(imageReady?'Status og bilde er markert klare. Raven-data er ikke endret.':'Status er markert klar; bilde var valgfritt. Raven-data er ikke endret.'):'Handoff er returnert uten Raven-stateendring.';}$('refresh').onclick=refresh;window.addEventListener('storage',render);render();refresh();setInterval(loadSystem,30000)"""
new = """  function handoffReceipt(params){
    if(params.get('handoffReturn')!=='ready')return null;
    return Object.freeze({status:params.get('handoffStatus')==='ready',image:params.get('handoffImage')==='ready'});
  }
  function closeHandoffReceipt(){
    const url=new URL(location.href);
    for(const key of ['handoffReturn','handoffStatus','handoffImage'])url.searchParams.delete(key);
    history.replaceState({},'',`${url.pathname}${url.search}${url.hash}`);
    $('handoffReturnNotice').classList.remove('show');
  }
  function renderHandoffReceipt(params){
    const receipt=handoffReceipt(params);if(!receipt)return;
    $('handoffReturnNotice').classList.add('show');
    $('handoffReturnMeta').textContent=receipt.status?(receipt.image?'Status og bilde er lokalt markert klare etter eksplisitte handlinger. Dette bekrefter ikke mottak i ChatGPT.':'Status er lokalt markert klar; bilde var valgfritt. Dette bekrefter ikke mottak i ChatGPT.'):'Returmarkør finnes, men status er ikke markert klar.';
    $('handoffReceiptStatus').textContent=receipt.status?'STATUS: KLAR':'STATUS: UKJENT';
    $('handoffReceiptStatus').className=receipt.status?'badge good':'badge';
    $('handoffReceiptImage').textContent=receipt.image?'BILDE: KLAR':'BILDE: IKKE MARKERT';
    $('handoffReceiptImage').className=receipt.image?'badge good':'badge';
  }
  const params=new URLSearchParams(location.search);if(params.get('projectActivated')==='1')$('activationNotice').classList.add('show');renderHandoffReceipt(params);$('handoffReceiptClose').onclick=closeHandoffReceipt;$('refresh').onclick=refresh;window.addEventListener('storage',render);render();refresh();setInterval(loadSystem,30000)"""
now = replace_once(now, old, new, "Now receipt runtime")
now_path.write_text(now, encoding="utf-8")


# Raven Studio v2.5 — same receipt semantics, without touching favorites/recent state.
studio_path = Path("RAH-RAVEN-START.html")
studio = studio_path.read_text(encoding="utf-8")
for old, new in [
    ("<title>RAH Raven Studio v2.4</title>", "<title>RAH Raven Studio v2.5</title>"),
    ("Raven Studio v2.4 · Local-first", "Raven Studio v2.5 · Local-first"),
    ("RAH Raven Studio v2.4 · Raven 2.0.25", "RAH Raven Studio v2.5 · Raven 2.0.26"),
]:
    studio = replace_once(studio, old, new, "Studio version")

old = '<div id="handoffReturnNotice" class="message" hidden><strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span></div>'
new = '''<div id="handoffReturnNotice" class="message" hidden aria-live="polite">
  <strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span>
  <div class="buttons" style="margin-top:9px">
    <span id="handoffReceiptStatus" class="tag">STATUS: KLAR</span>
    <span id="handoffReceiptImage" class="tag">BILDE: IKKE MARKERT</span>
    <button id="handoffReceiptClose" type="button">LUKK KVITTERING</button>
  </div>
</div>'''
studio = replace_once(studio, old, new, "Studio receipt panel")

old = """const handoffParams=new URLSearchParams(location.search);
if(handoffParams.get('handoffReturn')==='ready'){const statusReady=handoffParams.get('handoffStatus')==='ready',imageReady=handoffParams.get('handoffImage')==='ready';$('handoffReturnNotice').hidden=false;$('handoffReturnMeta').textContent=statusReady?(imageReady?'Status og bilde er markert klare. Ingen Studio-state er endret.':'Status er markert klar; bilde var valgfritt. Ingen Studio-state er endret.'):'Handoff er returnert uten Studio-stateendring.';}
const FAVORITES_KEY='rah-raven-studio-favorites-v1';"""
new = """const handoffParams=new URLSearchParams(location.search);
function handoffReceipt(params){
  if(params.get('handoffReturn')!=='ready')return null;
  return Object.freeze({status:params.get('handoffStatus')==='ready',image:params.get('handoffImage')==='ready'});
}
function closeHandoffReceipt(){
  const url=new URL(location.href);
  for(const key of ['handoffReturn','handoffStatus','handoffImage'])url.searchParams.delete(key);
  history.replaceState({},'',`${url.pathname}${url.search}${url.hash}`);
  $('handoffReturnNotice').hidden=true;
}
function renderHandoffReceipt(params){
  const receipt=handoffReceipt(params);if(!receipt)return;
  $('handoffReturnNotice').hidden=false;
  $('handoffReturnMeta').textContent=receipt.status?(receipt.image?'Status og bilde er lokalt markert klare etter eksplisitte handlinger. Dette bekrefter ikke mottak i ChatGPT.':'Status er lokalt markert klar; bilde var valgfritt. Dette bekrefter ikke mottak i ChatGPT.'):'Returmarkør finnes, men status er ikke markert klar.';
  $('handoffReceiptStatus').textContent=receipt.status?'STATUS: KLAR':'STATUS: UKJENT';
  $('handoffReceiptImage').textContent=receipt.image?'BILDE: KLAR':'BILDE: IKKE MARKERT';
}
renderHandoffReceipt(handoffParams);
$('handoffReceiptClose').onclick=closeHandoffReceipt;
const FAVORITES_KEY='rah-raven-studio-favorites-v1';"""
studio = replace_once(studio, old, new, "Studio receipt runtime")
studio_path.write_text(studio, encoding="utf-8")


# Align version-specific tests that intentionally track these two surfaces.
for name, pairs in {
    "tests/raven-now-v2.test.mjs": [("v2\\.13", "v2\\.14"), ("v2.13", "v2.14")],
    "tests/raven-chatgpt-handoff-entry.test.mjs": [
        ("v2\\.13", "v2\\.14"), ("v2\\.4", "v2\\.5"),
        ("Raven 2.0.25", "Raven 2.0.26")
    ],
}.items():
    path = Path(name)
    text = path.read_text(encoding="utf-8")
    for old, new in pairs:
        text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")


# Handoff Resume remains unchanged in Core; update its integration test to the new source surfaces.
Path("tests/raven-chatgpt-handoff-resume.test.mjs").write_text(r'''import assert from "node:assert/strict";
import fs from "node:fs";
const core=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");
const now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");
const studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");
assert.match(core,/RAH Raven Core Workflow v1\.10/);
assert.match(now,/RAH Raven Now v2\.14/);
assert.match(studio,/RAH Raven Studio v2\.5/);
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
console.log("Raven 2.0.26 keeps Handoff Resume status-gated and URL-only while source surfaces show a local receipt.");
''', encoding="utf-8")


# New semantic safety test for explicit Handoff Receipt + close.
Path("tests/raven-chatgpt-handoff-receipt.test.mjs").write_text(r'''import assert from "node:assert/strict";
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
''', encoding="utf-8")


# Permanent Raven Now validation.
wf = Path(".github/workflows/validate-raven-now-v2.yml")
text = wf.read_text(encoding="utf-8")
text = text.replace(
    "      - tests/raven-chatgpt-handoff-resume.test.mjs\n      - tests/raven-project-focus.test.mjs",
    "      - tests/raven-chatgpt-handoff-resume.test.mjs\n      - tests/raven-chatgpt-handoff-receipt.test.mjs\n      - tests/raven-project-focus.test.mjs",
)
text = text.replace(
    "      - name: Validate Handoff Resume\n        run: node tests/raven-chatgpt-handoff-resume.test.mjs\n      - name: Validate Project Focus semantics",
    "      - name: Validate Handoff Resume\n        run: node tests/raven-chatgpt-handoff-resume.test.mjs\n      - name: Validate Handoff Receipt\n        run: node tests/raven-chatgpt-handoff-receipt.test.mjs\n      - name: Validate Project Focus semantics",
)
wf.write_text(text, encoding="utf-8")


# Permanent one-click validation.
wf = Path(".github/workflows/validate-raven-one-click.yml")
text = wf.read_text(encoding="utf-8")
text = text.replace("Raven 2.0.25 safety contract", "Raven 2.0.26 safety contract")
text = text.replace("m['version']=='2.0.25'", "m['version']=='2.0.26'")
text = text.replace(
    "      - 'tests/raven-chatgpt-handoff-resume.test.mjs'\n      - 'tests/raven-vision-core.test.mjs'",
    "      - 'tests/raven-chatgpt-handoff-resume.test.mjs'\n      - 'tests/raven-chatgpt-handoff-receipt.test.mjs'\n      - 'tests/raven-vision-core.test.mjs'",
)
text = text.replace(
    "            'chatgpt_handoff_resume_does_not_change_continue_route','chatgpt_handoff_resume_navigation_only'\n",
    "            'chatgpt_handoff_resume_does_not_change_continue_route','chatgpt_handoff_resume_navigation_only',\n"
    "            'chatgpt_handoff_receipt_visible','chatgpt_handoff_receipt_url_only','chatgpt_handoff_receipt_close_explicit',\n"
    "            'chatgpt_handoff_receipt_close_cleans_handoff_query_only','chatgpt_handoff_receipt_no_storage_writes',\n"
    "            'chatgpt_handoff_receipt_does_not_change_continue_route'\n",
)
text = text.replace(
    "            'tests/raven-chatgpt-handoff-resume.test.mjs',\n            'tests/raven-vision-core.test.mjs'",
    "            'tests/raven-chatgpt-handoff-resume.test.mjs',\n            'tests/raven-chatgpt-handoff-receipt.test.mjs',\n            'tests/raven-vision-core.test.mjs'",
)
text = text.replace("Manifest 2.0.25 / launcher 3.0 / explicit URL-only Handoff Resume: OK", "Manifest 2.0.26 / launcher 3.0 / explicit Handoff Receipt: OK")
text = text.replace("explicit Handoff Resume Raven 2.0.25: OK", "explicit Handoff Receipt Raven 2.0.26: OK")
wf.write_text(text, encoding="utf-8")


# Permanent Core workflow also checks the source receipt because Core produces its URL markers.
wf = Path(".github/workflows/validate-raven-core-demo.yml")
text = wf.read_text(encoding="utf-8")
text = text.replace(
    "      - tests/raven-chatgpt-handoff-resume.test.mjs\n      - tests/raven-vision-core.test.mjs",
    "      - tests/raven-chatgpt-handoff-resume.test.mjs\n      - tests/raven-chatgpt-handoff-receipt.test.mjs\n      - tests/raven-vision-core.test.mjs",
)
text = text.replace(
    "      - name: Run Handoff Resume validation\n        run: node tests/raven-chatgpt-handoff-resume.test.mjs\n      - name: Run Raven Vision v0.5 handoff validation",
    "      - name: Run Handoff Resume validation\n        run: node tests/raven-chatgpt-handoff-resume.test.mjs\n      - name: Run Handoff Receipt validation\n        run: node tests/raven-chatgpt-handoff-receipt.test.mjs\n      - name: Run Raven Vision v0.5 handoff validation",
)
wf.write_text(text, encoding="utf-8")


# Manifest 2.0.26.
manifest_path = Path("RAH-RAVEN-VERSION.json")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["version"] = "2.0.26"
manifest["released_at"] = "2026-08-13"
manifest["summary"] = (
    "RAH Raven 2.0.26 adds a local Handoff Receipt to Raven Now v2.14 and Raven Studio v2.5. "
    "On return from an explicit ChatGPT Handoff, the source shows whether status and optional image were locally marked ready. "
    "The receipt explicitly says that this does not confirm ChatGPT received the content. "
    "LUKK KVITTERING removes only handoff URL markers with history.replaceState; it writes no Raven or Studio state and does not change the normal FORTSETT route."
)
p = manifest.setdefault("privacy", {})
p["chatgpt_handoff_receipt_visible"] = True
p["chatgpt_handoff_receipt_url_only"] = True
p["chatgpt_handoff_receipt_close_explicit"] = True
p["chatgpt_handoff_receipt_close_cleans_handoff_query_only"] = True
p["chatgpt_handoff_receipt_no_storage_writes"] = True
p["chatgpt_handoff_receipt_does_not_change_continue_route"] = True
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print("Built Raven 2.0.26 Handoff Receipt.")

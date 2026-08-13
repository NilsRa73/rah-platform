from pathlib import Path
import json


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"{label}: marker missing: {old[:180]!r}")
    return text.replace(old, new, 1)

# Raven Now v2.17: consume one shared, pure URL receipt parser/descriptor.
now_path=Path('RAH-RAVEN-NOW-V2.html')
now=now_path.read_text(encoding='utf-8')
now=now.replace('v2.16','v2.17')
now=replace_once(
    now,
    '<script src="raven-handoff-history-lite.js"></script>',
    '<script src="raven-handoff-receipt.js"></script>\n<script src="raven-handoff-history-lite.js"></script>',
    'Now shared receipt script'
)
now=replace_once(
    now,
    "  const Checkpoint=window.RAHCheckpointPolicy;\n  if(!Checkpoint)throw new Error('Raven checkpoint policy module missing');",
    "  const Checkpoint=window.RAHCheckpointPolicy;\n  if(!Checkpoint)throw new Error('Raven checkpoint policy module missing');\n  const HANDOFF_RECEIPT=window.RavenHandoffReceipt;\n  if(!HANDOFF_RECEIPT)throw new Error('Raven Handoff Receipt policy missing');",
    'Now shared receipt binding'
)
old_now_receipt="""  function handoffReceipt(params){
    if(params.get('handoffReturn')!=='ready')return null;
    return Object.freeze({status:params.get('handoffStatus')==='ready',image:params.get('handoffImage')==='ready'});
  }
"""
new_now_receipt="""  function handoffReceipt(params){return HANDOFF_RECEIPT.parse(params);}
"""
now=replace_once(now,old_now_receipt,new_now_receipt,'Now receipt parser')
now=replace_once(
    now,
    "    for(const key of ['handoffReturn','handoffStatus','handoffImage'])url.searchParams.delete(key);",
    "    for(const key of HANDOFF_RECEIPT.QUERY_KEYS)url.searchParams.delete(key);",
    'Now close query keys'
)
old_now_render="""  function renderHandoffReceipt(params){
    const receipt=handoffReceipt(params);if(!receipt)return;
    $('handoffReturnNotice').classList.add('show');
    $('handoffReturnMeta').textContent=receipt.status?(receipt.image?'Status og bilde er lokalt markert klare etter eksplisitte handlinger. Dette bekrefter ikke mottak i ChatGPT.':'Status er lokalt markert klar; bilde var valgfritt. Dette bekrefter ikke mottak i ChatGPT.'):'Returmarkør finnes, men status er ikke markert klar.';
    $('handoffReceiptStatus').textContent=receipt.status?'STATUS: KLAR':'STATUS: UKJENT';
    $('handoffReceiptStatus').className=receipt.status?'badge good':'badge';
    $('handoffReceiptImage').textContent=receipt.image?'BILDE: KLAR':'BILDE: IKKE MARKERT';
    $('handoffReceiptImage').className=receipt.image?'badge good':'badge';
  }
"""
new_now_render="""  function renderHandoffReceipt(params){
    const receipt=handoffReceipt(params);if(!receipt)return;const view=HANDOFF_RECEIPT.describe(receipt);
    $('handoffReturnNotice').classList.add('show');
    $('handoffReturnMeta').textContent=view.meta;
    $('handoffReceiptStatus').textContent=view.statusText;
    $('handoffReceiptStatus').className=receipt.status?'badge good':'badge';
    $('handoffReceiptImage').textContent=view.imageText;
    $('handoffReceiptImage').className=receipt.image?'badge good':'badge';
  }
"""
now=replace_once(now,old_now_render,new_now_render,'Now shared receipt render')
now_path.write_text(now,encoding='utf-8')

# Raven Studio v2.8: same shared parser/descriptor; close/save/delete stay explicit locally.
studio_path=Path('RAH-RAVEN-START.html')
studio=studio_path.read_text(encoding='utf-8')
studio=studio.replace('v2.7','v2.8')
studio=studio.replace('Raven 2.0.29','Raven 2.0.30')
studio=replace_once(
    studio,
    '<script src="raven-handoff-history-lite.js"></script>',
    '<script src="raven-handoff-receipt.js"></script>\n<script src="raven-handoff-history-lite.js"></script>',
    'Studio shared receipt script'
)
studio=replace_once(
    studio,
    "const $=id=>document.getElementById(id);\nconst handoffParams=new URLSearchParams(location.search);",
    "const $=id=>document.getElementById(id);\nconst HANDOFF_RECEIPT=window.RavenHandoffReceipt;if(!HANDOFF_RECEIPT)throw new Error('Raven Handoff Receipt policy missing');\nconst handoffParams=new URLSearchParams(location.search);",
    'Studio shared receipt binding'
)
old_studio_receipt="""function handoffReceipt(params){
  if(params.get('handoffReturn')!=='ready')return null;
  return Object.freeze({status:params.get('handoffStatus')==='ready',image:params.get('handoffImage')==='ready'});
}
"""
new_studio_receipt="""function handoffReceipt(params){return HANDOFF_RECEIPT.parse(params);}
"""
studio=replace_once(studio,old_studio_receipt,new_studio_receipt,'Studio receipt parser')
studio=replace_once(
    studio,
    "  for(const key of ['handoffReturn','handoffStatus','handoffImage'])url.searchParams.delete(key);",
    "  for(const key of HANDOFF_RECEIPT.QUERY_KEYS)url.searchParams.delete(key);",
    'Studio close query keys'
)
old_studio_render="""function renderHandoffReceipt(params){
  const receipt=handoffReceipt(params);if(!receipt)return;
  $('handoffReturnNotice').hidden=false;
  $('handoffReturnMeta').textContent=receipt.status?(receipt.image?'Status og bilde er lokalt markert klare etter eksplisitte handlinger. Dette bekrefter ikke mottak i ChatGPT.':'Status er lokalt markert klar; bilde var valgfritt. Dette bekrefter ikke mottak i ChatGPT.'):'Returmarkør finnes, men status er ikke markert klar.';
  $('handoffReceiptStatus').textContent=receipt.status?'STATUS: KLAR':'STATUS: UKJENT';
  $('handoffReceiptImage').textContent=receipt.image?'BILDE: KLAR':'BILDE: IKKE MARKERT';
}
"""
new_studio_render="""function renderHandoffReceipt(params){
  const receipt=handoffReceipt(params);if(!receipt)return;const view=HANDOFF_RECEIPT.describe(receipt);
  $('handoffReturnNotice').hidden=false;
  $('handoffReturnMeta').textContent=view.meta;
  $('handoffReceiptStatus').textContent=view.statusText;
  $('handoffReceiptImage').textContent=view.imageText;
}
"""
studio=replace_once(studio,old_studio_render,new_studio_render,'Studio shared receipt render')
studio_path.write_text(studio,encoding='utf-8')

# Version-sensitive tests.
for path in Path('tests').glob('*.mjs'):
    text=path.read_text(encoding='utf-8')
    text=text.replace('v2\\.16','v2\\.17').replace('v2.16','v2.17')
    text=text.replace('v2\\.7','v2\\.8').replace('v2.7','v2.8')
    path.write_text(text,encoding='utf-8')

# Rewrite Handoff Receipt integration contract around the shared read-only policy.
Path('tests/raven-chatgpt-handoff-receipt.test.mjs').write_text(r'''import assert from "node:assert/strict";
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
''',encoding='utf-8')

# Manifest 2.0.30.
manifest_path=Path('RAH-RAVEN-VERSION.json')
m=json.loads(manifest_path.read_text(encoding='utf-8'))
if m.get('version')!='2.0.29':
    raise SystemExit(f"Expected 2.0.29 base, got {m.get('version')}")
m['version']='2.0.30'
m['released_at']='2026-08-13'
m['summary']='RAH Raven 2.0.30 centralizes ChatGPT Handoff return-receipt parsing and presentation in one shared read-only URL policy used by Raven Now v2.17 and Raven Studio v2.8. The shared module only interprets handoffReturn, handoffStatus and handoffImage values and describes their UI labels; it has no storage, network, navigation or Raven-state capability. LUKK KVITTERING, LAGRE KVITTERING and SLETT LAGRET remain explicit local actions. Handoff History Lite and FORTSETT behavior are unchanged.'
files=m['files']
if 'raven-handoff-receipt.js' not in files:
    anchor=files.index('raven-handoff-history-lite.js') if 'raven-handoff-history-lite.js' in files else files.index('raven-checkpoint-policy.js')
    files.insert(anchor,'raven-handoff-receipt.js')
p=m['privacy']
p.update({
    'chatgpt_handoff_receipt_shared_policy': True,
    'chatgpt_handoff_receipt_shared_between_now_and_studio': True,
    'chatgpt_handoff_receipt_shared_policy_read_only': True,
    'chatgpt_handoff_receipt_shared_policy_value_based': True,
    'chatgpt_handoff_receipt_shared_policy_no_storage_writes': True,
    'chatgpt_handoff_receipt_shared_policy_no_storage_deletes': True,
    'chatgpt_handoff_receipt_shared_policy_no_network': True,
    'chatgpt_handoff_receipt_shared_policy_cannot_control_navigation': True,
    'chatgpt_handoff_receipt_close_remains_explicit_local_action': True
})
manifest_path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Built Raven 2.0.30 shared Handoff Receipt policy.')

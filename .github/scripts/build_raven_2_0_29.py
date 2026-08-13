from pathlib import Path
import json


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"{label}: marker missing: {old[:180]!r}")
    return text.replace(old, new, 1)

# Core v1.12: consume shared read-only History Lite policy.
core_path=Path('RAH-RAVEN-CORE-DEMO.html')
core=core_path.read_text(encoding='utf-8')
core=core.replace('v1.11','v1.12')
core=core.replace('Core v1.12 · HANDOFF RECALL','Core v1.12 · SHARED HANDOFF RECALL')
core=replace_once(core,'<script src="raven-checkpoint-policy.js"></script>','<script src="raven-handoff-history-lite.js"></script>\n<script src="raven-checkpoint-policy.js"></script>','Core shared policy script')
core=replace_once(core,'  const CHECKPOINT = window.RAHCheckpointPolicy;','  const CHECKPOINT = window.RAHCheckpointPolicy;\n  const HANDOFF_HISTORY = window.RavenHandoffHistoryLite;\n  if(!HANDOFF_HISTORY)throw new Error("Raven Handoff History Lite policy missing");','Core shared policy binding')
old_core='''  const HANDOFF_HISTORY_KEY='rah.raven.chatgpt-handoff-history-lite-v1';
  function readHandoffRecall(){
    try{
      const raw=JSON.parse(localStorage.getItem(HANDOFF_HISTORY_KEY)||'null');
      if(!raw||raw.version!==1||!["now","studio"].includes(raw.surface))return null;
      return Object.freeze({version:1,surface:raw.surface,status:raw.status===true,image:raw.image===true,savedAt:typeof raw.savedAt==="string"?raw.savedAt:""});
    }catch{return null;}
  }

  function renderHandoffRecall(){
    const item=readHandoffRecall();
    const title=$("handoffRecallTitle"),meta=$("handoffRecallMeta");
    if(!item){
      title.textContent="Ingen lagret kvittering";
      meta.textContent="Core leser bare den dedikerte History Lite-kvitteringen. Ingen tekst eller bildefil hentes.";
      return;
    }
    const source=item.surface==="studio"?"Raven Studio":"Raven Now";
    const status=item.status?"STATUS KLAR":"STATUS UKJENT";
    const image=item.image?"BILDE KLAR":"UTEN BILDEMARKØR";
    let saved="ukjent tidspunkt";
    if(item.savedAt){const date=new Date(item.savedAt);if(!Number.isNaN(date.getTime()))saved=date.toLocaleString("nb-NO");}
    title.textContent=`${source} · ${status} · ${image}`;
    meta.textContent=`Lagret ${saved}. Read-only metadata fra siste eksplisitt lagrede kvittering; ingen prompt, tekst, analyse eller bildefil leses.`;
  }
'''
new_core='''  function readHandoffRecall(){return HANDOFF_HISTORY.read(localStorage);}

  function renderHandoffRecall(){
    const item=readHandoffRecall(),view=HANDOFF_HISTORY.describe(item);
    $("handoffRecallTitle").textContent=view.title;
    $("handoffRecallMeta").textContent=view.meta;
  }
'''
core=replace_once(core,old_core,new_core,'Core shared Recall runtime')
core=core.replace('Raven Core v1.12 viser en source-aware URL-basert handoff-økt','Raven Core v1.12 bruker én delt read-only Handoff History Lite-policy og viser en source-aware URL-basert handoff-økt')
core_path.write_text(core,encoding='utf-8')

# Raven Now v2.16: same shared read-only parser/formatter, explicit local writes unchanged.
now_path=Path('RAH-RAVEN-NOW-V2.html')
now=now_path.read_text(encoding='utf-8')
now=now.replace('v2.15','v2.16')
now=replace_once(now,'<script src="raven-checkpoint-policy.js"></script>','<script src="raven-handoff-history-lite.js"></script>\n<script src="raven-checkpoint-policy.js"></script>','Now shared policy script')
old_now='''  const params=new URLSearchParams(location.search);const HANDOFF_HISTORY_KEY='rah.raven.chatgpt-handoff-history-lite-v1';
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
'''
new_now='''  const params=new URLSearchParams(location.search);const HANDOFF_HISTORY=window.RavenHandoffHistoryLite;if(!HANDOFF_HISTORY)throw new Error('Raven Handoff History Lite policy missing');const HANDOFF_HISTORY_KEY=HANDOFF_HISTORY.STORAGE_KEY;
  function readHandoffHistory(){return HANDOFF_HISTORY.read(localStorage);}
  function renderHandoffHistory(){
    const item=readHandoffHistory(),panel=$('handoffHistoryLite');panel.hidden=!item;if(!item)return;
    const view=HANDOFF_HISTORY.describe(item);
    $('handoffHistoryTitle').textContent=view.title;
    $('handoffHistoryMeta').textContent=view.meta;
  }
'''
now=replace_once(now,old_now,new_now,'Now shared History runtime')
now_path.write_text(now,encoding='utf-8')

# Studio v2.7: same shared read-only parser/formatter, explicit local writes unchanged.
studio_path=Path('RAH-RAVEN-START.html')
studio=studio_path.read_text(encoding='utf-8')
studio=studio.replace('v2.6','v2.7')
studio=studio.replace('Raven 2.0.27','Raven 2.0.29')
studio=replace_once(studio,'</main>\n<script>','</main>\n<script src="raven-handoff-history-lite.js"></script>\n<script>','Studio shared policy script')
old_studio='''const HANDOFF_HISTORY_KEY='rah.raven.chatgpt-handoff-history-lite-v1';
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
'''
new_studio='''const HANDOFF_HISTORY=window.RavenHandoffHistoryLite;if(!HANDOFF_HISTORY)throw new Error('Raven Handoff History Lite policy missing');const HANDOFF_HISTORY_KEY=HANDOFF_HISTORY.STORAGE_KEY;
function readHandoffHistory(){return HANDOFF_HISTORY.read(localStorage);}
function renderHandoffHistory(){
  const item=readHandoffHistory(),panel=$('handoffHistoryLite');panel.hidden=!item;if(!item)return;
  const view=HANDOFF_HISTORY.describe(item);
  $('handoffHistoryTitle').textContent=view.title;
  $('handoffHistoryMeta').textContent=view.meta;
}
'''
studio=replace_once(studio,old_studio,new_studio,'Studio shared History runtime')
studio_path.write_text(studio,encoding='utf-8')

# Version-sensitive tests.
for path in Path('tests').glob('*.mjs'):
    text=path.read_text(encoding='utf-8')
    text=text.replace('v1\\.11','v1\\.12').replace('v1.11','v1.12')
    text=text.replace('Core v1\\.12 · HANDOFF RECALL','Core v1\\.12 · SHARED HANDOFF RECALL')
    text=text.replace('Core v1.12 · HANDOFF RECALL','Core v1.12 · SHARED HANDOFF RECALL')
    text=text.replace('v2\\.15','v2\\.16').replace('v2.15','v2.16')
    text=text.replace('v2\\.6','v2\\.7').replace('v2.6','v2.7')
    path.write_text(text,encoding='utf-8')

Path('tests/raven-chatgpt-handoff-recall.test.mjs').write_text(r'''import assert from "node:assert/strict";
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
assert.doesNotMatch(core,/JSON\.parse\(localStorage\.getItem\(/);
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
''',encoding='utf-8')

Path('tests/raven-chatgpt-handoff-history-lite.test.mjs').write_text(r'''import assert from "node:assert/strict";
import fs from "node:fs";
const now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");
const studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");
const policy=fs.readFileSync("raven-handoff-history-lite.js","utf8");
function between(text,start,end,label){const a=text.indexOf(start);assert.notEqual(a,-1,`${label}: start missing`);const b=text.indexOf(end,a+start.length);assert.notEqual(b,-1,`${label}: end missing`);return text.slice(a+start.length,b)}
assert.match(now,/RAH Raven Now v2\.16/);
assert.match(studio,/RAH Raven Studio v2\.7/);
for(const text of [now,studio]){
  for(const id of ["handoffReceiptSave","handoffHistoryLite","handoffHistoryTitle","handoffHistoryMeta","handoffHistoryDelete"])assert.match(text,new RegExp(`id="${id}"`));
  assert.match(text,/<script src="raven-handoff-history-lite\.js"><\/script>/);
  assert.match(text,/HANDOFF_HISTORY=window\.RavenHandoffHistoryLite/);
  assert.match(text,/HANDOFF_HISTORY_KEY=HANDOFF_HISTORY\.STORAGE_KEY/);
  assert.match(text,/function readHandoffHistory\(\)\{return HANDOFF_HISTORY\.read\(localStorage\);\}/);
  assert.match(text,/HANDOFF_HISTORY\.describe\(item\)/);
  assert.match(text,/LAGRE KVITTERING/);
  assert.match(text,/SIST LAGREDE HANDOFF · MANUELL/);
  assert.match(text,/SLETT LAGRET/);
  assert.match(text,/function saveHandoffReceipt\(\)/);
  assert.match(text,/function deleteHandoffHistory\(\)/);
  assert.doesNotMatch(text,/saveHandoffReceipt\(\);/);
  assert.doesNotMatch(text,/JSON\.parse\(localStorage\.getItem\(HANDOFF_HISTORY_KEY/);
  assert.doesNotMatch(text,/api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);
}
assert.doesNotMatch(policy,/setItem\(|removeItem\(|localStorage|sessionStorage|fetch\(|navigator\.|location\./);
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
console.log("Raven 2.0.29 Now and Studio share one read-only Handoff History policy while save/delete remain explicit local actions.");
''',encoding='utf-8')

manifest_path=Path('RAH-RAVEN-VERSION.json')
m=json.loads(manifest_path.read_text(encoding='utf-8'))
m['version']='2.0.29';m['released_at']='2026-08-13'
m['summary']='RAH Raven 2.0.29 centralizes Handoff History Lite reading and presentation in one shared read-only policy module used by Raven Core v1.12, Raven Now v2.16 and Raven Studio v2.7. The shared module only normalizes, reads and describes the single metadata-only receipt; it has no save, delete, navigation, Raven-state or network capability. Explicit LAGRE KVITTERING and SLETT LAGRET actions remain local to Raven Now and Studio, while Core stays read-only. FORTSETT and the canonical Context Snapshot route are unchanged.'
files=m.setdefault('files',[])
if 'raven-handoff-history-lite.js' not in files:
    idx=files.index('raven-checkpoint-policy.js') if 'raven-checkpoint-policy.js' in files else len(files)
    files.insert(idx,'raven-handoff-history-lite.js')
p=m.setdefault('privacy',{})
p.update({
 'chatgpt_handoff_history_shared_read_policy':True,
 'chatgpt_handoff_history_shared_between_core_now_studio':True,
 'chatgpt_handoff_history_shared_policy_read_only':True,
 'chatgpt_handoff_history_shared_policy_value_based':True,
 'chatgpt_handoff_history_shared_policy_no_storage_writes':True,
 'chatgpt_handoff_history_shared_policy_no_storage_deletes':True,
 'chatgpt_handoff_history_shared_policy_no_network':True,
 'chatgpt_handoff_history_shared_policy_cannot_control_navigation':True,
 'chatgpt_handoff_history_save_delete_remain_explicit_on_source_surfaces':True
})
manifest_path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Built Raven 2.0.29 shared Handoff Recall policy.')

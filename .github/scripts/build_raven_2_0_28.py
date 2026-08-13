from pathlib import Path
import json


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"{label}: marker missing: {old[:180]!r}")
    return text.replace(old, new, 1)


core_path = Path("RAH-RAVEN-CORE-DEMO.html")
core = core_path.read_text(encoding="utf-8")
core = core.replace("v1.10", "v1.11")
core = core.replace("Core v1.11 · HANDOFF RESUME", "Core v1.11 · HANDOFF RECALL")

old_ui = '''  <div class="row" style="margin-top:10px"><a class="btn" id="handoffSourceReturn" href="RAH-RAVEN-NOW-V2.html" hidden>← TILBAKE</a></div>
  <div id="supportShareStatus" class="sub" style="margin-top:9px">Økten lagrer ikke status-tekst eller bilde; bare URL-markører viser hvilke manuelle steg som er gjennomført.</div>'''
new_ui = '''  <div class="row" style="margin-top:10px"><a class="btn" id="handoffSourceReturn" href="RAH-RAVEN-NOW-V2.html" hidden>← TILBAKE</a></div>
  <div id="handoffRecall" class="handoff-note" aria-live="polite">
    <small style="display:block;color:var(--gold);font-weight:900;letter-spacing:.7px">SIST MANUELT LAGREDE HANDOFF · READ ONLY</small>
    <strong id="handoffRecallTitle" style="display:block;margin-top:5px;color:var(--gold2)">Ingen lagret kvittering</strong>
    <div id="handoffRecallMeta" class="sub" style="margin-top:5px">Core leser bare den dedikerte History Lite-kvitteringen. Ingen tekst eller bildefil hentes.</div>
  </div>
  <div id="supportShareStatus" class="sub" style="margin-top:9px">Økten lagrer ikke status-tekst eller bilde; bare URL-markører viser hvilke manuelle steg som er gjennomført.</div>'''
core = replace_once(core, old_ui, new_ui, "Core Recall UI")

old_runtime = '''    $("chatgptHandoffVision").href=`RAH-RAVEN-VISION-CORE.html?mode=chatgpt&return=core${session.status?"&status=ready":""}${session.source?`&handoffFrom=${session.source.key}`:""}`;
  }

  function setHandoffMarker(name,value="ready"){'''
new_runtime = '''    $("chatgptHandoffVision").href=`RAH-RAVEN-VISION-CORE.html?mode=chatgpt&return=core${session.status?"&status=ready":""}${session.source?`&handoffFrom=${session.source.key}`:""}`;
    renderHandoffRecall();
  }

  const HANDOFF_HISTORY_KEY='rah.raven.chatgpt-handoff-history-lite-v1';
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

  function setHandoffMarker(name,value="ready"){'''
core = replace_once(core, old_runtime, new_runtime, "Core Recall runtime")
core_path.write_text(core, encoding="utf-8")

# Bump every Core-version-sensitive semantic assertion to v1.11.
for path in Path("tests").glob("*.mjs"):
    text = path.read_text(encoding="utf-8")
    text = text.replace("v1\\.10", "v1\\.11").replace("v1.10", "v1.11")
    path.write_text(text, encoding="utf-8")

Path("tests/raven-chatgpt-handoff-recall.test.mjs").write_text(r'''import assert from "node:assert/strict";
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
const render=between(core,"function renderHandoffRecall(){","function setHandoffMarker(","Recall render");
for(const body of [read,render]){
  assert.doesNotMatch(body,/localStorage\.setItem|localStorage\.removeItem|sessionStorage|fetch\(|writeState\(|activeMission\s*=|activeProject\s*=|\.done\s*=|\/agent\/run|navigator\.clipboard|imageData|dataUrl|Blob\(/i);
  assert.doesNotMatch(body,/coreContinue.*href|continueButton.*href|recommendedCheckpointButton.*href/);
}
assert.match(read,/localStorage\.getItem/);
assert.doesNotMatch(read,/prompt|analysis|answer|message|body|imageData|dataUrl|blob/i);
assert.match(render,/\.textContent=/);
assert.doesNotMatch(render,/\.innerHTML\s*=/);
const session=between(core,"function handoffSession(){","function handoffResumeHref(session){","Handoff session");
assert.doesNotMatch(session,/localStorage|sessionStorage/);
assert.match(core,/renderHandoffRecall\(\);/);
assert.equal((core.match(/localStorage\.getItem\(HANDOFF_HISTORY_KEY\)/g)||[]).length,1);
assert.equal((core.match(/localStorage\.setItem\(HANDOFF_HISTORY_KEY/g)||[]).length,0);
assert.equal((core.match(/localStorage\.removeItem\(HANDOFF_HISTORY_KEY/g)||[]).length,0);
assert.doesNotMatch(core,/api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);
console.log("Raven 2.0.28 Handoff Recall reads one explicit History Lite receipt as metadata-only, read-only context.");
''',encoding="utf-8")

manifest_path=Path("RAH-RAVEN-VERSION.json")
manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["version"]="2.0.28"
manifest["released_at"]="2026-08-13"
manifest["summary"]="RAH Raven 2.0.28 adds Handoff Recall to Raven Core v1.11. Core can read the one latest receipt that the user previously chose to save in Handoff History Lite and display its source surface, status marker, optional image marker and save time as read-only context. Recall reads only the dedicated History Lite key, stores nothing, deletes nothing, sends nothing, and never reads prompt text, analysis content or image bytes. The Handoff Session remains URL-only and the normal FORTSETT route is unchanged."
p=manifest.setdefault("privacy",{})
p.update({
  "chatgpt_handoff_recall_visible": True,
  "chatgpt_handoff_recall_read_only": True,
  "chatgpt_handoff_recall_reads_history_lite_only": True,
  "chatgpt_handoff_recall_metadata_only": True,
  "chatgpt_handoff_recall_no_storage_writes": True,
  "chatgpt_handoff_recall_no_storage_deletes": True,
  "chatgpt_handoff_recall_no_auto_send": True,
  "chatgpt_handoff_recall_does_not_change_continue_route": True
})
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("Built Raven 2.0.28 Handoff Recall.")

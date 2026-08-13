from pathlib import Path
import json


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'{label}: marker missing: {old[:120]}')
    return text.replace(old, new, 1)

# Core v1.10: explicit Handoff Resume. URL-only, source allowlisted, status-gated.
core_path = Path('RAH-RAVEN-CORE-DEMO.html')
core = core_path.read_text(encoding='utf-8')
for old, new in [
    ('<title>RAH Raven Core Workflow v1.9</title>', '<title>RAH Raven Core Workflow v1.10</title>'),
    ('Core v1.9 · SOURCE RETURN', 'Core v1.10 · HANDOFF RESUME'),
    ('RAH Raven 2.0.24 · Core v1.9 support snapshot', 'RAH Raven 2.0.25 · Core v1.10 support snapshot'),
    ('RAH-Raven-Core-v1.9-', 'RAH-Raven-Core-v1.10-'),
    ('Raven Core v1.9 viser en source-aware URL-basert handoff-økt', 'Raven Core v1.10 viser en source-aware URL-basert handoff-økt med eksplisitt Resume'),
]:
    core = replace_once(core, old, new, 'Core version')

old = '''  <div id="handoffSessionSummary" class="handoff-note">Start med status. Bilde er valgfritt. Ingenting sendes automatisk.</div>\n  <div class="row" style="margin-top:10px"><a class="btn" id="handoffSourceReturn" href="RAH-RAVEN-NOW-V2.html" hidden>← TILBAKE</a></div>'''
new = '''  <div id="handoffSessionSummary" class="handoff-note">Start med status. Bilde er valgfritt. Ingenting sendes automatisk.</div>\n  <div id="handoffResumePanel" class="handoff-note" hidden>\n    <strong id="handoffResumeTitle">HANDOFF RESUME KLAR</strong>\n    <div id="handoffResumeMeta" class="sub" style="margin:5px 0 10px">Status må deles eksplisitt før Resume blir tilgjengelig.</div>\n    <a class="btn primary" id="handoffResume" href="RAH-RAVEN-NOW-V2.html">FORTSETT TIL KILDEN →</a>\n  </div>\n  <div class="row" style="margin-top:10px"><a class="btn" id="handoffSourceReturn" href="RAH-RAVEN-NOW-V2.html" hidden>← TILBAKE</a></div>'''
core = replace_once(core, old, new, 'Core resume panel')

old = '''  function handoffSession(){\n    const params=new URLSearchParams(location.search);\n    return {status:params.get("handoffStatus")==="ready",image:params.get("handoffImage")==="ready",source:handoffSource(params.get("handoffFrom"))};\n  }\n\n  function renderHandoffSession(){'''
new = '''  function handoffSession(){\n    const params=new URLSearchParams(location.search);\n    return Object.freeze({status:params.get("handoffStatus")==="ready",image:params.get("handoffImage")==="ready",source:handoffSource(params.get("handoffFrom"))});\n  }\n\n  function handoffResumeHref(session){\n    if(!session?.source||!session.status)return "";\n    const params=new URLSearchParams();\n    params.set("handoffReturn","ready");\n    params.set("handoffStatus","ready");\n    if(session.image)params.set("handoffImage","ready");\n    return `${session.source.href}?${params.toString()}`;\n  }\n\n  function renderHandoffSession(){'''
core = replace_once(core, old, new, 'Core resume function')

old = '''    const sourceReturn=$("handoffSourceReturn");\n    sourceReturn.hidden=!session.source;\n    if(session.source){sourceReturn.href=session.source.href;sourceReturn.textContent=session.source.label;}\n    $("chatgptHandoffVision").href=`RAH-RAVEN-VISION-CORE.html?mode=chatgpt&return=core${session.status?"&status=ready":""}${session.source?`&handoffFrom=${session.source.key}`:""}`;'''
new = '''    const sourceReturn=$("handoffSourceReturn");\n    sourceReturn.hidden=!session.source;\n    if(session.source){sourceReturn.href=session.source.href;sourceReturn.textContent=session.source.label;}\n    const resumeHref=handoffResumeHref(session),resumePanel=$("handoffResumePanel"),resumeLink=$("handoffResume");\n    resumePanel.hidden=!resumeHref;\n    if(resumeHref){\n      resumeLink.href=resumeHref;\n      resumeLink.textContent=`FORTSETT TIL ${session.source.key==="now"?"RAVEN NOW":"RAVEN STUDIO"} →`;\n      $("handoffResumeMeta").textContent=session.image?"Status og bilde er markert klare etter eksplisitte handlinger. Resume navigerer bare tilbake til kilden.":"Status er markert klar. Bilde var valgfritt. Resume navigerer bare tilbake til kilden.";\n    }\n    $("chatgptHandoffVision").href=`RAH-RAVEN-VISION-CORE.html?mode=chatgpt&return=core${session.status?"&status=ready":""}${session.source?`&handoffFrom=${session.source.key}`:""}`;'''
core = replace_once(core, old, new, 'Core resume render')
core_path.write_text(core, encoding='utf-8')

# Raven Now v2.13: read-only URL return feedback. Normal FORTSETT remains untouched.
now_path = Path('RAH-RAVEN-NOW-V2.html')
now = now_path.read_text(encoding='utf-8')
for old, new in [
    ('<title>RAH Raven Now v2.12</title>', '<title>RAH Raven Now v2.13</title>'),
    ('<span class="badge">v2.12 · READ ONLY</span>', '<span class="badge">v2.13 · READ ONLY</span>'),
    ('RAH Raven Now v2.12 · shared Raven Context Snapshot', 'RAH Raven Now v2.13 · shared Raven Context Snapshot'),
]:
    now = replace_once(now, old, new, 'Now version')
old = '''<div id="activationNotice" class="activation-notice">✓ Aktivt prosjekt er oppdatert. Raven Now viser det øverst i Project Switcher.</div>\n<section class="hero">'''
new = '''<div id="activationNotice" class="activation-notice">✓ Aktivt prosjekt er oppdatert. Raven Now viser det øverst i Project Switcher.</div>\n<div id="handoffReturnNotice" class="activation-notice"><strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span></div>\n<section class="hero">'''
now = replace_once(now, old, new, 'Now return notice')
old = '''  const params=new URLSearchParams(location.search);if(params.get('projectActivated')==='1')$('activationNotice').classList.add('show');$('refresh').onclick=refresh;window.addEventListener('storage',render);render();refresh();setInterval(loadSystem,30000)'''
new = '''  const params=new URLSearchParams(location.search);if(params.get('projectActivated')==='1')$('activationNotice').classList.add('show');if(params.get('handoffReturn')==='ready'){const statusReady=params.get('handoffStatus')==='ready',imageReady=params.get('handoffImage')==='ready';$('handoffReturnNotice').classList.add('show');$('handoffReturnMeta').textContent=statusReady?(imageReady?'Status og bilde er markert klare. Raven-data er ikke endret.':'Status er markert klar; bilde var valgfritt. Raven-data er ikke endret.'):'Handoff er returnert uten Raven-stateendring.';}$('refresh').onclick=refresh;window.addEventListener('storage',render);render();refresh();setInterval(loadSystem,30000)'''
now = replace_once(now, old, new, 'Now return parser')
now_path.write_text(now, encoding='utf-8')

# Studio v2.4: read-only URL return feedback; no recent/favorites writes caused by handoff return.
studio_path = Path('RAH-RAVEN-START.html')
studio = studio_path.read_text(encoding='utf-8')
for old, new in [
    ('<title>RAH Raven Studio v2.3</title>', '<title>RAH Raven Studio v2.4</title>'),
    ('Raven Studio v2.3 · Local-first', 'Raven Studio v2.4 · Local-first'),
    ('RAH Raven Studio v2.3 · Raven 2.0.24', 'RAH Raven Studio v2.4 · Raven 2.0.25'),
]:
    studio = replace_once(studio, old, new, 'Studio version')
old = '''</section>\n\n<section class="workspace">'''
new = '''</section>\n<div id="handoffReturnNotice" class="message" hidden><strong>✓ ChatGPT Handoff returnert.</strong> <span id="handoffReturnMeta">Status er klar.</span></div>\n\n<section class="workspace">'''
studio = replace_once(studio, old, new, 'Studio return notice')
old = '''const $=id=>document.getElementById(id);\nconst FAVORITES_KEY='rah-raven-studio-favorites-v1';'''
new = '''const $=id=>document.getElementById(id);\nconst handoffParams=new URLSearchParams(location.search);\nif(handoffParams.get('handoffReturn')==='ready'){const statusReady=handoffParams.get('handoffStatus')==='ready',imageReady=handoffParams.get('handoffImage')==='ready';$('handoffReturnNotice').hidden=false;$('handoffReturnMeta').textContent=statusReady?(imageReady?'Status og bilde er markert klare. Ingen Studio-state er endret.':'Status er markert klar; bilde var valgfritt. Ingen Studio-state er endret.'):'Handoff er returnert uten Studio-stateendring.';}\nconst FAVORITES_KEY='rah-raven-studio-favorites-v1';'''
studio = replace_once(studio, old, new, 'Studio return parser')
studio_path.write_text(studio, encoding='utf-8')

# Align existing semantic tests to surface versions without weakening prior safety checks.
replacements = {
    'tests/raven-now-v2.test.mjs': [('v2\\.12','v2\\.13'),('v2.12','v2.13')],
    'tests/raven-chatgpt-handoff-entry.test.mjs': [('v2\\.12','v2\\.13'),('v2\\.3','v2\\.4'),('Raven 2.0.24','Raven 2.0.25')],
    'tests/raven-chatgpt-handoff-session.test.mjs': [('v1\\.9','v1\\.10'),('v1.9','v1.10'),('Raven 2.0.24','Raven 2.0.25')],
    'tests/raven-chatgpt-handoff-source-return.test.mjs': [('v1\\.9','v1\\.10'),('Raven 2.0.24','Raven 2.0.25')],
    'tests/raven-core-demo.test.mjs': [('v1\\.9','v1\\.10'),('v1.9','v1.10')],
    'tests/raven-core-context.test.mjs': [('v1\\.9','v1\\.10'),('v1.9','v1.10')],
    'tests/raven-core-chatgpt-status.test.mjs': [('v1\\.9','v1\\.10'),('v1.9','v1.10')],
    'tests/raven-core-chatgpt-handoff-center.test.mjs': [('v1\\.9','v1\\.10'),('v1.9','v1.10'),('2\\.0\\.24','2\\.0\\.25'),('2.0.24','2.0.25')],
}
for name, pairs in replacements.items():
    path = Path(name)
    text = path.read_text(encoding='utf-8')
    for old, new in pairs:
        text = text.replace(old, new)
    path.write_text(text, encoding='utf-8')

# New Handoff Resume semantic safety test.
Path('tests/raven-chatgpt-handoff-resume.test.mjs').write_text(r'''import assert from "node:assert/strict";
import fs from "node:fs";
const core=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");
const now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");
const studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");
assert.match(core,/RAH Raven Core Workflow v1\.10/);
assert.match(now,/RAH Raven Now v2\.13/);
assert.match(studio,/RAH Raven Studio v2\.4/);
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
assert.match(now,/params\.get\('handoffReturn'\)==='ready'/);
assert.match(studio,/handoffParams\.get\('handoffReturn'\)==='ready'/);
assert.match(now,/Raven-data er ikke endret/);
assert.match(studio,/Ingen Studio-state er endret/);
const resumeFn=core.split("function handoffResumeHref(session){",2)[1].split("function renderHandoffSession(){",1)[0];
assert.doesNotMatch(resumeFn,/localStorage|sessionStorage|fetch\(|writeState\(|activeMission\s*=|activeProject\s*=|\.done\s*=/);
const nowReturn=now.split("if(params.get('handoffReturn')==='ready')",2)[1].split("$('refresh').onclick",1)[0];
assert.doesNotMatch(nowReturn,/localStorage|sessionStorage|writeState\(|continueButton.*href|activeMission\s*=|activeProject\s*=|\.done\s*=/);
const studioReturn=studio.split("if(handoffParams.get('handoffReturn')==='ready')",2)[1].split("const FAVORITES_KEY",1)[0];
assert.doesNotMatch(studioReturn,/localStorage|sessionStorage|setItem\(|removeItem\(|fetch\(|data-launch/);
assert.match(now,/id="continueButton" href="RAH-RAVEN-MISSION-CONTROL\.html"/);
assert.doesNotMatch(core+now+studio,/api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);
console.log("Raven 2.0.25 Handoff Resume is status-gated, allowlisted, URL-only and navigation-only.");
''', encoding='utf-8')

# Manifest 2.0.25.
manifest_path = Path('RAH-RAVEN-VERSION.json')
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['version'] = '2.0.25'
manifest['released_at'] = '2026-08-13'
manifest['summary'] = 'RAH Raven 2.0.25 adds explicit ChatGPT Handoff Resume. Core v1.10 exposes a source-aware Resume action only after status has been explicitly marked ready. Resume returns to Raven Now v2.13 or Raven Studio v2.4 with URL-only feedback about status and optional image readiness. It writes no Raven or Studio state, does not alter the normal FORTSETT route, and never captures, copies, downloads or sends automatically.'
p = manifest.setdefault('privacy', {})
p['chatgpt_handoff_resume_visible'] = True
p['chatgpt_handoff_resume_requires_status_ready'] = True
p['chatgpt_handoff_resume_source_allowlisted'] = True
p['chatgpt_handoff_resume_url_only'] = True
p['chatgpt_handoff_resume_return_feedback_visible'] = True
p['chatgpt_handoff_resume_no_storage_writes'] = True
p['chatgpt_handoff_resume_does_not_change_continue_route'] = True
p['chatgpt_handoff_resume_navigation_only'] = True
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

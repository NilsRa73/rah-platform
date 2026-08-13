from pathlib import Path
import json

now_path=Path('RAH-RAVEN-NOW-V2.html')
now=now_path.read_text(encoding='utf-8')
for old,new in [
    ('<title>RAH Raven Now v2.11</title>','<title>RAH Raven Now v2.12</title>'),
    ('<span class="badge">v2.11 · READ ONLY</span>','<span class="badge">v2.12 · READ ONLY</span>'),
    ('RAH Raven Now v2.11 · shared Raven Context Snapshot','RAH Raven Now v2.12 · shared Raven Context Snapshot'),
    ('id="nowChatgptHandoff" href="RAH-RAVEN-CORE-DEMO.html#chatgptHandoffCenter"','id="nowChatgptHandoff" href="RAH-RAVEN-CORE-DEMO.html?handoffFrom=now#chatgptHandoffCenter"'),
]:
    if old not in now: raise SystemExit(f'Raven Now marker missing: {old}')
    now=now.replace(old,new,1)
now_path.write_text(now,encoding='utf-8')

studio_path=Path('RAH-RAVEN-START.html')
studio=studio_path.read_text(encoding='utf-8')
for old,new in [
    ('<title>RAH Raven Studio v2.2</title>','<title>RAH Raven Studio v2.3</title>'),
    ('Raven Studio v2.2 · Local-first','Raven Studio v2.3 · Local-first'),
    ('RAH Raven Studio v2.2 · Raven 2.0.23','RAH Raven Studio v2.3 · Raven 2.0.24'),
    ('id="studioChatgptHandoff" href="RAH-RAVEN-CORE-DEMO.html#chatgptHandoffCenter"','id="studioChatgptHandoff" href="RAH-RAVEN-CORE-DEMO.html?handoffFrom=studio#chatgptHandoffCenter"'),
]:
    if old not in studio: raise SystemExit(f'Studio marker missing: {old}')
    studio=studio.replace(old,new,1)
studio_path.write_text(studio,encoding='utf-8')

core_path=Path('RAH-RAVEN-CORE-DEMO.html')
core=core_path.read_text(encoding='utf-8')
for old,new in [
    ('<title>RAH Raven Core Workflow v1.8</title>','<title>RAH Raven Core Workflow v1.9</title>'),
    ('Core v1.8 · HANDOFF SESSION','Core v1.9 · SOURCE RETURN'),
    ('RAH Raven 2.0.22 · Core v1.8 support snapshot','RAH Raven 2.0.24 · Core v1.9 support snapshot'),
    ('RAH-Raven-Core-v1.8-','RAH-Raven-Core-v1.9-'),
    ('Raven Core v1.8 viser en eksplisitt URL-basert handoff-økt','Raven Core v1.9 viser en source-aware URL-basert handoff-økt'),
]:
    if old not in core: raise SystemExit(f'Core marker missing: {old}')
    core=core.replace(old,new,1)
old='''  <div id="handoffSessionSummary" class="handoff-note">Start med status. Bilde er valgfritt. Ingenting sendes automatisk.</div>\n  <div id="supportShareStatus" class="sub" style="margin-top:9px">Økten lagrer ikke status-tekst eller bilde; bare URL-markører viser hvilke manuelle steg som er gjennomført.</div>'''
new='''  <div id="handoffSessionSummary" class="handoff-note">Start med status. Bilde er valgfritt. Ingenting sendes automatisk.</div>\n  <div class="row" style="margin-top:10px"><a class="btn" id="handoffSourceReturn" href="RAH-RAVEN-NOW-V2.html" hidden>← TILBAKE</a></div>\n  <div id="supportShareStatus" class="sub" style="margin-top:9px">Økten lagrer ikke status-tekst eller bilde; bare URL-markører viser hvilke manuelle steg som er gjennomført.</div>'''
if old not in core: raise SystemExit('Core handoff panel marker missing')
core=core.replace(old,new,1)
old='''  function handoffSession(){\n    const params=new URLSearchParams(location.search);\n    return {status:params.get("handoffStatus")==="ready",image:params.get("handoffImage")==="ready"};\n  }'''
new='''  function handoffSource(value){\n    if(value==="now")return Object.freeze({key:"now",href:"RAH-RAVEN-NOW-V2.html",label:"← TILBAKE TIL RAVEN NOW"});\n    if(value==="studio")return Object.freeze({key:"studio",href:"RAH-RAVEN-START.html",label:"← TILBAKE TIL RAVEN STUDIO"});\n    return null;\n  }\n\n  function handoffSession(){\n    const params=new URLSearchParams(location.search);\n    return {status:params.get("handoffStatus")==="ready",image:params.get("handoffImage")==="ready",source:handoffSource(params.get("handoffFrom"))};\n  }'''
if old not in core: raise SystemExit('Core handoffSession marker missing')
core=core.replace(old,new,1)
old='''    $("handoffSessionSummary").textContent=session.status?(session.image?"Status og bilde er markert klare etter eksplisitte handlinger. Lim/dra dem inn i ChatGPT når du vil.":"Status er markert klar. Bilde er fortsatt valgfritt; åpne Vision bare hvis ChatGPT trenger å se skjermen."):"Start med KOPIER STATUS eller STATUS TXT. Bilde er valgfritt. Ingenting sendes automatisk.";\n    $("chatgptHandoffVision").href=`RAH-RAVEN-VISION-CORE.html?mode=chatgpt&return=core${session.status?"&status=ready":""}`;'''
new='''    $("handoffSessionSummary").textContent=session.status?(session.image?"Status og bilde er markert klare etter eksplisitte handlinger. Lim/dra dem inn i ChatGPT når du vil.":"Status er markert klar. Bilde er fortsatt valgfritt; åpne Vision bare hvis ChatGPT trenger å se skjermen."):"Start med KOPIER STATUS eller STATUS TXT. Bilde er valgfritt. Ingenting sendes automatisk.";\n    const sourceReturn=$("handoffSourceReturn");\n    sourceReturn.hidden=!session.source;\n    if(session.source){sourceReturn.href=session.source.href;sourceReturn.textContent=session.source.label;}\n    $("chatgptHandoffVision").href=`RAH-RAVEN-VISION-CORE.html?mode=chatgpt&return=core${session.status?"&status=ready":""}${session.source?`&handoffFrom=${session.source.key}`:""}`;'''
if old not in core: raise SystemExit('Core renderHandoff marker missing')
core=core.replace(old,new,1)
core_path.write_text(core,encoding='utf-8')

vision_path=Path('RAH-RAVEN-VISION-CORE.html')
vision=vision_path.read_text(encoding='utf-8')
for old,new in [
    ('RAH Raven Vision Core v0.4','RAH Raven Vision Core v0.5'),
    ('raven-vision-core.js?v=0.4','raven-vision-core.js?v=0.5'),
]:
    if old not in vision: raise SystemExit(f'Vision marker missing: {old}')
    vision=vision.replace(old,new)
old='''  const returnToCore = query.get("return") === "core";\n  const statusReadyFromCore = query.get("status") === "ready";'''
new='''  const returnToCore = query.get("return") === "core";\n  const handoffFrom = ["now","studio"].includes(query.get("handoffFrom")) ? query.get("handoffFrom") : "";\n  const statusReadyFromCore = query.get("status") === "ready";'''
if old not in vision: raise SystemExit('Vision query marker missing')
vision=vision.replace(old,new,1)
old='''    if(statusReadyFromCore)params.push("handoffStatus=ready");\n    if(imageReady)params.push("handoffImage=ready");'''
new='''    if(statusReadyFromCore)params.push("handoffStatus=ready");\n    if(imageReady)params.push("handoffImage=ready");\n    if(handoffFrom)params.push(`handoffFrom=${handoffFrom}`);'''
if old not in vision: raise SystemExit('Vision return params marker missing')
vision=vision.replace(old,new,1)
vision_path.write_text(vision,encoding='utf-8')

now_test=Path('tests/raven-now-v2.test.mjs')
t=now_test.read_text(encoding='utf-8').replace('v2\\.11','v2\\.12').replace('v2.11','v2.12')
now_test.write_text(t,encoding='utf-8')
entry_test=Path('tests/raven-chatgpt-handoff-entry.test.mjs')
t=entry_test.read_text(encoding='utf-8')
t=t.replace('v2\\.11','v2\\.12').replace('v2\\.2','v2\\.3')
t=t.replace('RAH-RAVEN-CORE-DEMO\\.html#chatgptHandoffCenter','RAH-RAVEN-CORE-DEMO\\.html\\?handoffFrom=now#chatgptHandoffCenter',1)
t=t.replace('RAH-RAVEN-CORE-DEMO\\.html#chatgptHandoffCenter','RAH-RAVEN-CORE-DEMO\\.html\\?handoffFrom=studio#chatgptHandoffCenter',1)
t=t.replace('Raven 2.0.23 exposes navigation-only ChatGPT Handoff entries in Now and Studio.','Raven 2.0.24 exposes source-aware navigation-only ChatGPT Handoff entries in Now and Studio.')
entry_test.write_text(t,encoding='utf-8')
session_test=Path('tests/raven-chatgpt-handoff-session.test.mjs')
t=session_test.read_text(encoding='utf-8').replace('v1\\.8','v1\\.9').replace('v0\\.4','v0\\.5').replace('Raven 2.0.22','Raven 2.0.24')
session_test.write_text(t,encoding='utf-8')

Path('tests/raven-chatgpt-handoff-source-return.test.mjs').write_text('''import assert from "node:assert/strict";\nimport fs from "node:fs";\nconst now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");\nconst studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");\nconst core=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");\nconst vision=fs.readFileSync("RAH-RAVEN-VISION-CORE.html","utf8");\nassert.match(now,/id="nowChatgptHandoff" href="RAH-RAVEN-CORE-DEMO\\.html\\?handoffFrom=now#chatgptHandoffCenter"/);\nassert.match(studio,/id="studioChatgptHandoff" href="RAH-RAVEN-CORE-DEMO\\.html\\?handoffFrom=studio#chatgptHandoffCenter"/);\nassert.match(core,/RAH Raven Core Workflow v1\\.9/);\nassert.match(vision,/RAH Raven Vision Core v0\\.5/);\nassert.match(core,/id="handoffSourceReturn"/);\nassert.match(core,/function handoffSource\\(value\\)/);\nassert.match(core,/value==="now"/);\nassert.match(core,/value==="studio"/);\nassert.match(core,/session\\.source\\.href/);\nassert.match(core,/session\\.source\\.label/);\nassert.match(core,/handoffFrom=\\$\\{session\\.source\\.key\\}/);\nassert.match(vision,/const handoffFrom = \\["now","studio"\\]\\.includes\\(query\\.get\\("handoffFrom"\\)\\)/);\nassert.match(vision,/if\\(handoffFrom\\)params\\.push\\(`handoffFrom=\\$\\{handoffFrom\\}`\\)/);\nconst sourceFn=core.split("function handoffSource(value){",2)[1].split("function handoffSession(){",1)[0];\nassert.doesNotMatch(sourceFn,/localStorage|sessionStorage|fetch\\(|writeState\\(|history\\.replaceState|activeMission\\s*=|activeProject\\s*=/);\nconst sessionFn=core.split("function handoffSession(){",2)[1].split("function renderHandoffSession(){",1)[0];\nassert.doesNotMatch(sessionFn,/localStorage|sessionStorage|fetch\\(|writeState\\(/);\nconst nowTag=(now.match(/<a class="btn" id="nowChatgptHandoff"[^>]*>/)||[])[0]||"";\nconst studioTag=(studio.match(/<a class="btn" id="studioChatgptHandoff"[^>]*>/)||[])[0]||"";\nfor(const tag of [nowTag,studioTag])assert.doesNotMatch(tag,/onclick=|data-launch=|handoffStatus=|handoffImage=/);\nassert.doesNotMatch(core+vision,/api\\.openai\\.com|chatgpt\\.com\\/backend|openai\\.com\\/v1/i);\nconsole.log("Raven 2.0.24 source-aware handoff return is allowlisted, URL-only and navigation-only.");\n''',encoding='utf-8')

manifest_path=Path('RAH-RAVEN-VERSION.json')
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['version']='2.0.24'
manifest['released_at']='2026-08-13'
manifest['summary']='RAH Raven 2.0.24 makes ChatGPT Handoff source-aware. Raven Now v2.12 and Raven Studio v2.3 pass an allowlisted handoffFrom source to Core v1.9; Core shows the correct return link and propagates that source through Vision v0.5 back to Core. The source exists only in the URL, writes no Raven state, does not alter FORTSETT, and never triggers capture, copy, download or sending automatically.'
p=manifest.setdefault('privacy',{})
p['chatgpt_handoff_source_return_visible']=True
p['chatgpt_handoff_source_allowlisted']=True
p['chatgpt_handoff_source_url_only']=True
p['chatgpt_handoff_source_no_storage_writes']=True
p['chatgpt_handoff_source_propagates_through_vision']=True
p['chatgpt_handoff_source_does_not_change_continue_route']=True
p['chatgpt_handoff_source_navigation_only']=True
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

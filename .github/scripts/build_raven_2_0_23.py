from pathlib import Path
import json

# Raven Now v2.11: add a navigation-only ChatGPT Handoff entry.
now_path=Path('RAH-RAVEN-NOW-V2.html')
now=now_path.read_text(encoding='utf-8')
for old,new in [
    ('<title>RAH Raven Now v2.10</title>','<title>RAH Raven Now v2.11</title>'),
    ('<span class="badge">v2.10 · READ ONLY</span>','<span class="badge">v2.11 · READ ONLY</span>'),
    ('RAH Raven Now v2.10 · shared Raven Context Snapshot','RAH Raven Now v2.11 · shared Raven Context Snapshot'),
]:
    if old not in now: raise SystemExit(f'Raven Now marker missing: {old}')
    now=now.replace(old,new,1)
old_header='<a class="btn" href="RAH-RAVEN-CORE-DEMO.html">Raven Core</a></div>'
new_header='<a class="btn" href="RAH-RAVEN-CORE-DEMO.html">Raven Core</a><a class="btn" id="nowChatgptHandoff" href="RAH-RAVEN-CORE-DEMO.html#chatgptHandoffCenter">💬 ChatGPT Handoff</a></div>'
if old_header not in now: raise SystemExit('Raven Now header marker missing')
now=now.replace(old_header,new_header,1)
now_path.write_text(now,encoding='utf-8')

# Studio v2.2: expose the same navigation-only entry from the hero.
studio_path=Path('RAH-RAVEN-START.html')
studio=studio_path.read_text(encoding='utf-8')
for old,new in [
    ('<title>RAH Raven Studio v2.1</title>','<title>RAH Raven Studio v2.2</title>'),
    ('Raven Studio v2.1 · Local-first','Raven Studio v2.2 · Local-first'),
    ('RAH Raven Studio v2.1 · Raven 1.9.10','RAH Raven Studio v2.2 · Raven 2.0.23'),
]:
    if old not in studio: raise SystemExit(f'Studio marker missing: {old}')
    studio=studio.replace(old,new,1)
old_action='''    <button class="primary" data-launch="core">🚀 Start Raven Core</button>\n    <button class="primary" id="test">🔄 Test systemet</button>'''
new_action='''    <button class="primary" data-launch="core">🚀 Start Raven Core</button>\n    <a class="btn" id="studioChatgptHandoff" href="RAH-RAVEN-CORE-DEMO.html#chatgptHandoffCenter">💬 ChatGPT Handoff</a>\n    <button class="primary" id="test">🔄 Test systemet</button>'''
if old_action not in studio: raise SystemExit('Studio hero action marker missing')
studio=studio.replace(old_action,new_action,1)
studio_path.write_text(studio,encoding='utf-8')

# Keep Raven Now semantic test aligned with the surface version.
test_path=Path('tests/raven-now-v2.test.mjs')
test=test_path.read_text(encoding='utf-8')
test=test.replace('v2\\.10','v2\\.11').replace('v2.10','v2.11')
test_path.write_text(test,encoding='utf-8')

# Dedicated entry test: both surfaces must be static navigation only.
Path('tests/raven-chatgpt-handoff-entry.test.mjs').write_text('''import assert from "node:assert/strict";\nimport fs from "node:fs";\nconst now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");\nconst studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");\nconst core=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");\nassert.match(now,/RAH Raven Now v2\\.11/);\nassert.match(studio,/RAH Raven Studio v2\\.2/);\nassert.match(now,/id="nowChatgptHandoff" href="RAH-RAVEN-CORE-DEMO\\.html#chatgptHandoffCenter"/);\nassert.match(studio,/id="studioChatgptHandoff" href="RAH-RAVEN-CORE-DEMO\\.html#chatgptHandoffCenter"/);\nassert.match(core,/id="chatgptHandoffCenter"/);\nconst nowTag=(now.match(/<a class="btn" id="nowChatgptHandoff"[^>]*>/)||[])[0]||"";\nconst studioTag=(studio.match(/<a class="btn" id="studioChatgptHandoff"[^>]*>/)||[])[0]||"";\nfor(const tag of [nowTag,studioTag]){\n  assert.ok(tag);\n  assert.doesNotMatch(tag,/onclick=|data-launch=|handoffStatus=|handoffImage=/);\n}\nassert.equal((now.match(/id="nowChatgptHandoff"/g)||[]).length,1);\nassert.equal((studio.match(/id="studioChatgptHandoff"/g)||[]).length,1);\nassert.doesNotMatch(nowTag,/api\\.openai\\.com|chatgpt\\.com\\/backend/i);\nassert.doesNotMatch(studioTag,/api\\.openai\\.com|chatgpt\\.com\\/backend/i);\nconsole.log("Raven 2.0.23 exposes navigation-only ChatGPT Handoff entries in Now and Studio.");\n''',encoding='utf-8')

manifest_path=Path('RAH-RAVEN-VERSION.json')
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['version']='2.0.23'
manifest['released_at']='2026-08-13'
manifest['summary']='RAH Raven 2.0.23 exposes the existing URL-only ChatGPT Handoff Session directly from Raven Now v2.11 and Raven Studio v2.2. Both entries are static navigation links to the Core handoff panel; they do not change FORTSETT routing, active project, active mission, handoff progress or any Raven state.'
p=manifest.setdefault('privacy',{})
p['raven_now_chatgpt_handoff_entry_visible']=True
p['studio_chatgpt_handoff_entry_visible']=True
p['chatgpt_handoff_entries_navigation_only']=True
p['chatgpt_handoff_entries_no_state_writes']=True
p['chatgpt_handoff_entries_do_not_change_continue_route']=True
p['chatgpt_handoff_entries_do_not_mark_progress']=True
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

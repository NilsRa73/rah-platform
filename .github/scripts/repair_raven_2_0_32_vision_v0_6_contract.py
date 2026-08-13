from pathlib import Path
import json

manifest_path=Path('RAH-RAVEN-VERSION.json')
m=json.loads(manifest_path.read_text(encoding='utf-8'))
assert m['product']=='RAH Raven'
assert m['version']=='2.0.32'
assert m['release_gate']['stage']=='temporary-stable'
assert m['release_gate']['change_policy']=='bugfix-only-until-explicit-reopen'
assert m['release_gate']['component_versions']['raven_vision']=='0.5'

m['summary']='RAH Raven 2.0.32 remains the temporary stable freeze. A bugfix-only Vision Core v0.6 safety patch aligns the Vision helper version and restricts Bridge endpoints to local loopback addresses. No new Raven product features are added; the project remains paused under the bugfix-only change policy.'
files=m['files']
if 'RAH-RAVEN-VISION-VERSION.json' not in files:
    idx=files.index('RAH-RAVEN-VISION-CORE.html')+1
    files.insert(idx,'RAH-RAVEN-VISION-VERSION.json')
privacy=m['privacy']
privacy['vision_local_bridge_only']=True
privacy['vision_external_bridge_addresses_allowed']=False
privacy['vision_helper_version_synced']=True
m['release_gate']['component_versions']['raven_vision']='0.6'
m['release_gate']['bugfix_component_updates']={'raven_vision':'0.6'}
manifest_path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

test_path=Path('tests/raven-release-gate.test.mjs')
t=test_path.read_text(encoding='utf-8')
old='raven_vision:["RAH-RAVEN-VISION-CORE.html","RAH Raven Vision Core v0.5","0.5"],'
new='raven_vision:["RAH-RAVEN-VISION-CORE.html","RAH Raven Vision Core v0.6","0.6"],'
assert old in t
t=t.replace(old,new,1)
anchor='assert.equal(manifest.release_gate?.change_policy,"bugfix-only-until-explicit-reopen");\n'
assert anchor in t
t=t.replace(anchor,anchor+'assert.equal(manifest.release_gate?.bugfix_component_updates?.raven_vision,"0.6");\n',1)
privacy_anchor='for(const key of [\n  "raven_core_continue_navigation_only",\n'
assert privacy_anchor in t
t=t.replace(privacy_anchor,'for(const key of [\n  "vision_local_bridge_only",\n  "vision_helper_version_synced",\n  "raven_core_continue_navigation_only",\n',1)
negative_anchor='const now=read("RAH-RAVEN-NOW-V2.html");\n'
assert negative_anchor in t
t=t.replace(negative_anchor,'assert.equal(privacy.vision_external_bridge_addresses_allowed,false,"Vision external Bridge addresses must stay blocked");\nassert.ok(manifest.files.includes("RAH-RAVEN-VISION-VERSION.json"),"Vision component manifest must ship in Raven package");\nconst visionManifest=JSON.parse(read("RAH-RAVEN-VISION-VERSION.json"));\nassert.equal(visionManifest.version,"0.6.0");\nassert.equal(visionManifest.features.local_bridge_only,true);\n\n'+negative_anchor,1)
test_path.write_text(t,encoding='utf-8')

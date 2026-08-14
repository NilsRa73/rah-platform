from pathlib import Path
import json

manifest_path=Path('RAH-RAVEN-VERSION.json')
council_test_path=Path('tests/raven-council.test.mjs')
release_test_path=Path('tests/raven-release-gate.test.mjs')

manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
assert manifest['version']=='2.0.32'
assert manifest['release_gate']['component_versions']['raven_council']=='0.3'
files=manifest['files']
if 'RAH-RAVEN-COUNCIL-VERSION.json' not in files:
    idx=files.index('RAH-RAVEN-COUNCIL.html')+1
    files.insert(idx,'RAH-RAVEN-COUNCIL-VERSION.json')
manifest['summary']='RAH Raven 2.0.32 remains the temporary stable freeze. Vision Core v0.6 and Council v0.3 are stable local-only components. Council v0.3 keeps its loopback-only Bridge boundary and explicit human approval boundaries; no new Raven product features are added.'
manifest['privacy']['council_stable']=True
manifest['release_gate']['stable_components']={'raven_vision':'0.6','raven_council':'0.3'}
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

ct=council_test_path.read_text(encoding='utf-8')
needle="console.log('Raven Council v0.3 local Bridge boundary and version-sync validation passed.');"
assert needle in ct
block="""const componentManifest=JSON.parse(fs.readFileSync('RAH-RAVEN-COUNCIL-VERSION.json','utf8'));
assert.equal(componentManifest.product,'RAH Raven Council');
assert.equal(componentManifest.version,'0.3.0');
assert.equal(componentManifest.stage,'stable');
assert.equal(componentManifest.helper_version,'0.3.0');
assert.equal(componentManifest.runtime_feature_change,false);
assert.equal(componentManifest.development_paused,true);
assert.equal(componentManifest.change_policy,'bugfix-only-until-explicit-reopen');
assert.equal(componentManifest.features.local_bridge_only,true);
assert.equal(componentManifest.features.external_bridge_addresses_allowed,false);
assert.equal(componentManifest.features.bridge_tools_executed,false);
assert.equal(componentManifest.features.bridge_automatic_actions,false);
assert.equal(componentManifest.features.project_brain_write_requires_explicit_click,true);
assert.equal(componentManifest.features.mission_handoff_requires_explicit_click,true);
assert.equal(componentManifest.stable_release_gate?.status,'passed');
assert.equal(componentManifest.stable_release_gate?.runtime_files_frozen,true);
assert.equal(componentManifest.next_milestone,null);
console.log('Raven Council v0.3 Stable Gate: local boundary, explicit handoff and frozen runtime contract passed.');"""
ct=ct.replace(needle,block,1)
council_test_path.write_text(ct,encoding='utf-8')

rt=release_test_path.read_text(encoding='utf-8')
vision_tail='assert.equal(visionManifest.features.external_bridge_addresses_allowed,false);\n'
assert vision_tail in rt
council_block='''\nassert.ok(manifest.files.includes("RAH-RAVEN-COUNCIL-VERSION.json"),"Council component manifest must ship in Raven package");
assert.equal(privacy.council_stable,true,"Council stable marker must stay true");
assert.equal(manifest.release_gate?.stable_components?.raven_vision,"0.6");
assert.equal(manifest.release_gate?.stable_components?.raven_council,"0.3");
const councilManifest=JSON.parse(read("RAH-RAVEN-COUNCIL-VERSION.json"));
assert.equal(councilManifest.version,"0.3.0");
assert.equal(councilManifest.stage,"stable");
assert.equal(councilManifest.runtime_feature_change,false);
assert.equal(councilManifest.development_paused,true);
assert.equal(councilManifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(councilManifest.features.local_bridge_only,true);
assert.equal(councilManifest.features.external_bridge_addresses_allowed,false);
assert.equal(councilManifest.features.bridge_tools_executed,false);
assert.equal(councilManifest.features.bridge_automatic_actions,false);
assert.equal(councilManifest.features.project_brain_write_requires_explicit_click,true);
assert.equal(councilManifest.features.mission_handoff_requires_explicit_click,true);
assert.equal(councilManifest.stable_release_gate?.status,"passed");
assert.equal(councilManifest.stable_release_gate?.runtime_files_frozen,true);
'''
rt=rt.replace(vision_tail,vision_tail+council_block,1)
rt=rt.replace('component identity, stable Vision v0.6 and safety boundaries OK.','component identity, stable Vision v0.6 + Council v0.3 and safety boundaries OK.',1)
release_test_path.write_text(rt,encoding='utf-8')

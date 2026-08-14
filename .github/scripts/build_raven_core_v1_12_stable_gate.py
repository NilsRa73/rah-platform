from __future__ import annotations

import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def read(path:str)->str:
    return (ROOT/path).read_text(encoding='utf-8')

def write(path:str,text:str)->None:
    (ROOT/path).write_text(text,encoding='utf-8')

def read_json(path:str)->dict:
    return json.loads(read(path))

def write_json(path:str,data:dict)->None:
    write(path,json.dumps(data,indent=2,ensure_ascii=False)+'\n')

def replace_once(text:str,old:str,new:str,label:str)->str:
    if old not in text:
        raise RuntimeError(f'{label} anchor missing')
    return text.replace(old,new,1)

core=read_json('RAH-RAVEN-CORE-VERSION.json')
assert core['version']=='1.12.0'
assert core['stage']=='candidate'
assert core['runtime_feature_change'] is False
assert core['features']['local_bridge_only'] is True
assert core['features']['external_bridge_addresses_allowed'] is False
assert core['features']['capability_set_changed'] is False
core['stage']='stable'
core['next_milestone']=None
core['stable_since']='2026-08-14'
core['development_paused']=True
core['change_policy']='bugfix-only-until-explicit-reopen'
core['stable_release_gate']={
    'status':'passed',
    'gate_version':'1.0.0',
    'runtime_files_frozen':True,
}
write_json('RAH-RAVEN-CORE-VERSION.json',core)

manifest=read_json('RAH-RAVEN-VERSION.json')
assert manifest['version']=='2.0.32'
assert manifest['release_gate']['component_versions']['raven_core']=='1.12'
assert manifest['release_gate']['stable_components']=={
    'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4'
}
manifest['privacy']['raven_core_stable']=True
manifest['release_gate']['bugfix_component_updates']['raven_core']='1.12'
manifest['release_gate']['stable_components']['raven_core']='1.12'
manifest['summary']='RAH Raven 2.0.32 remains the temporary stable freeze. Seven core components are stable, including Raven Core v1.12 with loopback-only Bridge status requests and synced stable dependency identities.'
write_json('RAH-RAVEN-VERSION.json',manifest)

boundary=read('tests/raven-core-local-boundary.test.mjs')
boundary=replace_once(boundary,'assert.equal(manifest.stage,"candidate");','assert.equal(manifest.stage,"stable");','boundary stage')
boundary=replace_once(
    boundary,
    'assert.equal(manifest.next_milestone,"stable-gate");',
    'assert.equal(manifest.next_milestone,null);\nassert.equal(manifest.development_paused,true);\nassert.equal(manifest.change_policy,"bugfix-only-until-explicit-reopen");\nassert.equal(manifest.stable_release_gate?.status,"passed");\nassert.equal(manifest.stable_release_gate?.runtime_files_frozen,true);',
    'boundary stable contract'
)
boundary=boundary.replace('Raven Core v1.12 local Bridge boundary candidate passed.','Raven Core v1.12 stable local Bridge boundary passed.')
write('tests/raven-core-local-boundary.test.mjs',boundary)

release=read('tests/raven-release-gate.test.mjs')
release=replace_once(
    release,
    'assert.equal(manifest.release_gate?.bugfix_component_updates?.project_focus,"2.4");',
    'assert.equal(manifest.release_gate?.bugfix_component_updates?.project_focus,"2.4");\nassert.equal(manifest.release_gate?.bugfix_component_updates?.raven_core,"1.12");',
    'Core bugfix update'
)
release=replace_once(
    release,
    'assert.equal(privacy.raven_core_stable,false,"Raven Core v1.12 remains candidate until stable gate passes");',
    'assert.equal(privacy.raven_core_stable,true,"Raven Core v1.12 stable marker must stay true");',
    'Core stable privacy'
)
release=replace_once(release,'assert.equal(coreManifest.stage,"candidate");','assert.equal(coreManifest.stage,"stable");','Core manifest stage')
release=replace_once(
    release,
    'assert.equal(coreManifest.next_milestone,"stable-gate");',
    'assert.equal(coreManifest.development_paused,true);\nassert.equal(coreManifest.change_policy,"bugfix-only-until-explicit-reopen");\nassert.equal(coreManifest.stable_release_gate?.status,"passed");\nassert.equal(coreManifest.stable_release_gate?.runtime_files_frozen,true);\nassert.equal(coreManifest.next_milestone,null);',
    'Core stable manifest contract'
)
release=replace_once(
    release,
    'assert.equal(manifest.release_gate?.stable_components?.project_focus,"2.4");',
    'assert.equal(manifest.release_gate?.stable_components?.project_focus,"2.4");\nassert.equal(manifest.release_gate?.stable_components?.raven_core,"1.12");',
    'Core stable component'
)
release=release.replace(
    'RAH Raven 2.0.32 Temporary Stable Gate: six stable core components; Raven Core v1.12 candidate local Bridge boundary OK.',
    'RAH Raven 2.0.32 Temporary Stable Gate: seven stable core components including Raven Core v1.12 stable boundaries OK.'
)
write('tests/raven-release-gate.test.mjs',release)

print('Raven Core v1.12 stable metadata/tests built; runtime untouched.')

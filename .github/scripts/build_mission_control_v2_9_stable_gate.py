from __future__ import annotations

import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def read(path): return (ROOT/path).read_text(encoding='utf-8')
def write(path,text): (ROOT/path).write_text(text,encoding='utf-8')
def read_json(path): return json.loads(read(path))
def write_json(path,data): write(path,json.dumps(data,indent=2,ensure_ascii=False)+'\n')
def replace_once(text,old,new,label):
    if old not in text: raise RuntimeError(f'{label} anchor missing')
    return text.replace(old,new,1)

# Freeze component manifest; runtime HTML and shared checkpoint policy remain untouched.
mission=read_json('RAH-RAVEN-MISSION-CONTROL-VERSION.json')
assert mission['version']=='2.9.0'
assert mission['stage']=='candidate'
assert mission['runtime_feature_change'] is False
assert mission['features']['local_bridge_only'] is True
assert mission['features']['external_bridge_addresses_allowed'] is False
assert mission['features']['chronicle_context_read_only'] is True
assert mission['features']['mission_completion_requires_explicit_confirmation'] is True
assert mission['features']['automatic_step_completion'] is False
assert mission['features']['capability_set_changed'] is False
mission['stage']='stable'
mission['stable_since']='2026-08-14'
mission['development_paused']=True
mission['change_policy']='bugfix-only-until-explicit-reopen'
mission['stable_release_gate']={'status':'passed','gate_version':'1.0.0','runtime_files_frozen':True}
mission['next_milestone']=None
write_json('RAH-RAVEN-MISSION-CONTROL-VERSION.json',mission)

# Master Raven freeze stays 2.0.32; only Mission Control is promoted into stable_components.
manifest=read_json('RAH-RAVEN-VERSION.json')
assert manifest['version']=='2.0.32'
assert manifest['release_gate']['runtime_feature_change'] is False
assert manifest['privacy']['mission_control_stable'] is False
assert 'mission_control' not in manifest['release_gate']['stable_components']
manifest['summary']=(
    'RAH Raven 2.0.32 remains the temporary stable freeze. Vision Core v0.6, Council v0.3, '
    'Agent Runner v0.3, Memory Sync v0.2 and Mission Control v2.9 are stable local-only components. '
    'Mission Control keeps its loopback-only Bridge boundary, read-only Chronicle context and explicit mission-step completion.'
)
manifest['privacy']['mission_control_stable']=True
manifest['release_gate']['stable_components']['mission_control']='2.9'
write_json('RAH-RAVEN-VERSION.json',manifest)

# Dedicated Mission Control test gains stable-manifest/freeze assertions without changing runtime tests.
p='tests/raven-mission-control.test.mjs'
s=read(p)
anchor="const agent=fs.readFileSync('RAH-RAVEN-AGENT-RUNNER.html','utf8');\n"
insert="""const missionManifest=JSON.parse(fs.readFileSync('RAH-RAVEN-MISSION-CONTROL-VERSION.json','utf8'));\nassert.equal(missionManifest.version,'2.9.0');\nassert.equal(missionManifest.stage,'stable');\nassert.equal(missionManifest.development_paused,true);\nassert.equal(missionManifest.change_policy,'bugfix-only-until-explicit-reopen');\nassert.equal(missionManifest.stable_release_gate?.status,'passed');\nassert.equal(missionManifest.stable_release_gate?.runtime_files_frozen,true);\nassert.equal(missionManifest.next_milestone,null);\n\n"""
s=replace_once(s,anchor,anchor+insert,'mission test manifest')
s=s.replace('Raven Mission Control v2.9 local Bridge boundary, shared Context Snapshot and safe mission controls passed.',
            'Raven Mission Control v2.9 stable local Bridge boundary, shared Context Snapshot and safe mission controls passed.')
write(p,s)

# Aggregate release gate promotes candidate assertions to stable/frozen assertions.
p='tests/raven-release-gate.test.mjs'
s=read(p)
s=replace_once(s,'assert.equal(privacy.mission_control_stable,false,"Mission Control v2.9 remains candidate until its stable gate passes");',
                  'assert.equal(privacy.mission_control_stable,true,"Mission Control v2.9 stable marker must stay true");','release privacy stable')
s=replace_once(s,'assert.equal(manifest.release_gate?.stable_components?.memory_sync,"0.2");',
                  'assert.equal(manifest.release_gate?.stable_components?.memory_sync,"0.2");\nassert.equal(manifest.release_gate?.stable_components?.mission_control,"2.9");','release stable components')
s=replace_once(s,'assert.equal(missionManifest.stage,"candidate");',
                  'assert.equal(missionManifest.stage,"stable");\nassert.equal(missionManifest.development_paused,true);\nassert.equal(missionManifest.change_policy,"bugfix-only-until-explicit-reopen");','release mission stage')
s=replace_once(s,'assert.equal(missionManifest.next_milestone,"stable-gate");',
                  'assert.equal(missionManifest.stable_release_gate?.status,"passed");\nassert.equal(missionManifest.stable_release_gate?.runtime_files_frozen,true);\nassert.equal(missionManifest.next_milestone,null);','release mission freeze')
s=s.replace('RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 stable; Mission Control v2.9 candidate boundary OK.',
            'RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 stable boundaries OK.')
write(p,s)

print('Mission Control v2.9 stable metadata/tests built; Mission Control HTML and checkpoint policy untouched.')

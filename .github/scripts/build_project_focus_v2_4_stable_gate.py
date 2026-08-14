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

# Freeze Project Focus candidate metadata. Runtime HTML and checkpoint policy remain untouched.
project=read_json('RAH-RAVEN-PROJECT-FOCUS-VERSION.json')
assert project['version']=='2.4.0'
assert project['stage']=='candidate'
assert project['runtime_feature_change'] is False
assert project['features']['explicit_project_activation'] is True
assert project['features']['active_project_write_requires_explicit_confirmation'] is True
assert project['features']['stale_selection_guard'] is True
assert project['features']['project_identity_revalidated_before_write'] is True
assert project['features']['active_mission_write'] is False
assert project['features']['mission_step_completion'] is False
assert project['features']['agent_execution'] is False
assert project['features']['network_requests'] is False
assert project['features']['capability_set_changed'] is False
project['stage']='stable'
project['stable_since']='2026-08-14'
project['development_paused']=True
project['change_policy']='bugfix-only-until-explicit-reopen'
project['stable_release_gate']={'status':'passed','gate_version':'1.0.0','runtime_files_frozen':True}
project['next_milestone']=None
write_json('RAH-RAVEN-PROJECT-FOCUS-VERSION.json',project)

# Raven 2.0.32 remains the temporary stable product freeze; promote only Project Focus metadata.
manifest=read_json('RAH-RAVEN-VERSION.json')
assert manifest['version']=='2.0.32'
assert manifest['release_gate']['component_versions']['project_focus']=='2.4'
assert manifest['privacy']['project_focus_stable'] is False
assert 'project_focus' not in manifest['release_gate']['stable_components']
manifest['summary']=(
    'RAH Raven 2.0.32 remains the temporary stable freeze. Vision Core v0.6, Council v0.3, '
    'Agent Runner v0.3, Memory Sync v0.2, Mission Control v2.9 and Project Focus v2.4 are stable components. '
    'Project Focus keeps explicit project activation, stale-selection revalidation, mission-safe writes and no network requests.'
)
manifest['privacy']['project_focus_stable']=True
manifest['release_gate']['stable_components']['project_focus']='2.4'
manifest['release_gate']['bugfix_component_updates']['project_focus']='2.4'
write_json('RAH-RAVEN-VERSION.json',manifest)

# Dedicated Project Focus test now freezes the stable component contract too.
p='tests/raven-project-focus.test.mjs'
s=read(p)
anchor="const policy=fs.readFileSync('raven-checkpoint-policy.js','utf8');\n"
insert="""const projectManifest=JSON.parse(fs.readFileSync('RAH-RAVEN-PROJECT-FOCUS-VERSION.json','utf8'));\nassert.equal(projectManifest.version,'2.4.0');\nassert.equal(projectManifest.stage,'stable');\nassert.equal(projectManifest.development_paused,true);\nassert.equal(projectManifest.change_policy,'bugfix-only-until-explicit-reopen');\nassert.equal(projectManifest.stable_release_gate?.status,'passed');\nassert.equal(projectManifest.stable_release_gate?.runtime_files_frozen,true);\nassert.equal(projectManifest.next_milestone,null);\n\n"""
s=replace_once(s,anchor,anchor+insert,'project test manifest')
s=s.replace('Raven Project Focus v2.4 explicit activation + stale selection guard passed.',
            'Raven Project Focus v2.4 stable explicit activation + stale selection guard passed.')
write(p,s)

# Aggregate release contract promotes candidate assertions to stable/frozen assertions.
p='tests/raven-release-gate.test.mjs'
s=read(p)
s=replace_once(s,
    'assert.equal(manifest.release_gate?.bugfix_component_updates?.mission_control,"2.9");',
    'assert.equal(manifest.release_gate?.bugfix_component_updates?.mission_control,"2.9");\nassert.equal(manifest.release_gate?.bugfix_component_updates?.project_focus,"2.4");',
    'project bugfix update')
s=replace_once(s,
    'assert.equal(privacy.project_focus_stable,false,"Project Focus v2.4 remains candidate until stable gate passes");',
    'assert.equal(privacy.project_focus_stable,true,"Project Focus v2.4 stable marker must stay true");',
    'project privacy stable')
s=replace_once(s,
    'assert.equal(manifest.release_gate?.stable_components?.mission_control,"2.9");',
    'assert.equal(manifest.release_gate?.stable_components?.mission_control,"2.9");\nassert.equal(manifest.release_gate?.stable_components?.project_focus,"2.4");',
    'project stable component')
s=replace_once(s,
    'assert.equal(projectFocusManifest.stage,"candidate");',
    'assert.equal(projectFocusManifest.stage,"stable");\nassert.equal(projectFocusManifest.development_paused,true);\nassert.equal(projectFocusManifest.change_policy,"bugfix-only-until-explicit-reopen");',
    'project manifest stable')
s=replace_once(s,
    'assert.equal(projectFocusManifest.next_milestone,"stable-gate");',
    'assert.equal(projectFocusManifest.stable_release_gate?.status,"passed");\nassert.equal(projectFocusManifest.stable_release_gate?.runtime_files_frozen,true);\nassert.equal(projectFocusManifest.next_milestone,null);',
    'project manifest freeze')
s=s.replace(
    'RAH Raven 2.0.32 Temporary Stable Gate: five stable core components; Project Focus v2.4 candidate stale-selection boundary OK.',
    'RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 + Project Focus v2.4 stable boundaries OK.'
)
write(p,s)

print('Project Focus v2.4 stable metadata/tests built; Project Focus HTML and checkpoint policy untouched.')

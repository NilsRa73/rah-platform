from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def read(p): return (ROOT/p).read_text(encoding='utf-8')
def write(p,s): (ROOT/p).write_text(s,encoding='utf-8')
def replace_once(s,old,new,label):
    if old not in s: raise RuntimeError(f'{label} anchor missing: {old[:80]}')
    return s.replace(old,new,1)

# Package gate: ensure the component manifest and dedicated test participate.
p='.github/workflows/validate-raven-package.yml'
s=read(p)
s=s.replace('      - "RAH-RAVEN-MEMORY-SYNC-VERSION.json"\n', '      - "RAH-RAVEN-MEMORY-SYNC-VERSION.json"\n      - "RAH-RAVEN-MISSION-CONTROL-VERSION.json"\n')
s=s.replace("'RAH-RAVEN-MEMORY-SYNC-VERSION.json'):", "'RAH-RAVEN-MEMORY-SYNC-VERSION.json','RAH-RAVEN-MISSION-CONTROL-VERSION.json'):")
s=replace_once(s,"          assert gate['component_versions']['memory_sync']=='0.2'\n", "          assert gate['component_versions']['memory_sync']=='0.2'\n          assert gate['component_versions']['mission_control']=='2.9'\n",'package component')
s=replace_once(s,"          assert gate['bugfix_component_updates']['memory_sync']=='0.2'\n", "          assert gate['bugfix_component_updates']['memory_sync']=='0.2'\n          assert gate['bugfix_component_updates']['mission_control']=='2.9'\n",'package bugfix')
s=replace_once(s,"'memory_sync_external_bridge_addresses_allowed','memory_sync_automatic_sync'):", "'memory_sync_external_bridge_addresses_allowed','memory_sync_automatic_sync','mission_control_external_bridge_addresses_allowed','mission_control_automatic_step_completion'):",'package forbidden')
s=replace_once(s,"          assert privacy['memory_sync_stable'] is True\n", "          assert privacy['memory_sync_stable'] is True\n          assert privacy['mission_control_local_bridge_only'] is True\n          assert privacy['mission_control_chronicle_context_read_only'] is True\n          assert privacy['mission_control_stable'] is False\n",'package privacy')
s=replace_once(s,"      - name: Run Memory Sync v0.2 stable test\n        run: node tests/raven-memory-sync.test.mjs\n", "      - name: Run Memory Sync v0.2 stable test\n        run: node tests/raven-memory-sync.test.mjs\n\n      - name: Run Mission Control v2.9 candidate boundary test\n        run: node tests/raven-mission-control.test.mjs\n",'package test')
s=s.replace(' + Memory Sync {gate[\'component_versions\'][\'memory_sync\']} stable")', ' + Memory Sync {gate[\'component_versions\'][\'memory_sync\']} stable; Mission Control {gate[\'component_versions\'][\'mission_control\']} candidate")')
write(p,s)

# One-click gate: exact manifest identity must expect Mission Control 2.9 candidate.
p='.github/workflows/validate-raven-one-click.yml'
s=read(p)
s=s.replace("      - 'RAH-RAVEN-MEMORY-SYNC-VERSION.json'\n", "      - 'RAH-RAVEN-MEMORY-SYNC-VERSION.json'\n      - 'RAH-RAVEN-MISSION-CONTROL-VERSION.json'\n")
s=replace_once(s,"            'mission_control':'2.8','project_focus':'2.4'", "            'mission_control':'2.9','project_focus':'2.4'",'oneclick version')
s=replace_once(s,"          assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2'}", "          assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9'}",'oneclick bugfix')
s=replace_once(s,"'RAH-RAVEN-MEMORY-SYNC-VERSION.json']:", "'RAH-RAVEN-MEMORY-SYNC-VERSION.json','RAH-RAVEN-MISSION-CONTROL-VERSION.json']:",'oneclick required')
s=replace_once(s,"'memory_sync_external_bridge_addresses_allowed','memory_sync_automatic_sync']:", "'memory_sync_external_bridge_addresses_allowed','memory_sync_automatic_sync','mission_control_external_bridge_addresses_allowed','mission_control_automatic_step_completion']:",'oneclick forbidden')
s=replace_once(s,"            'memory_sync_requires_explicit_confirmation','memory_sync_local_bridge_only','memory_sync_explicit_write_only','memory_sync_metadata_only','memory_sync_stable',", "            'memory_sync_requires_explicit_confirmation','memory_sync_local_bridge_only','memory_sync_explicit_write_only','memory_sync_metadata_only','memory_sync_stable',\n            'mission_control_local_bridge_only','mission_control_chronicle_context_read_only',",'oneclick required true')
s=replace_once(s,"          for key in required_true: assert p.get(key) is True, key\n", "          for key in required_true: assert p.get(key) is True, key\n          assert p.get('mission_control_stable') is False\n",'oneclick candidate flag')
s=s.replace('Memory Sync v0.2 stable / launcher 3.0: OK', 'Memory Sync v0.2 stable / Mission Control v2.9 candidate / launcher 3.0: OK')
s=s.replace('Memory Sync v0.2 stable: OK', 'Memory Sync v0.2 stable + Mission Control v2.9 candidate: OK')
write(p,s)

# Release gate: label + direct Windows candidate test.
p='.github/workflows/validate-raven-release-gate.yml'
s=read(p)
s=s.replace("      - 'RAH-RAVEN-MEMORY-SYNC-VERSION.json'\n", "      - 'RAH-RAVEN-MEMORY-SYNC-VERSION.json'\n      - 'RAH-RAVEN-MISSION-CONTROL-VERSION.json'\n")
s=s.replace('Run Raven 2.0.32 gate with Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 stable', 'Run Raven 2.0.32 gate with stable core components + Mission Control v2.9 candidate')
s=replace_once(s,"          node tests/raven-memory-sync.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n", "          node tests/raven-memory-sync.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n          node tests/raven-mission-control.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n",'release windows mission test')
s=s.replace('Memory Sync v0.2 stable: OK', 'Memory Sync v0.2 stable; Mission Control v2.9 candidate: OK')
write(p,s)

# Dedicated candidate validation surface.
workflow='''name: Validate Raven Mission Control\n\non:\n  workflow_dispatch:\n  push:\n    paths:\n      - 'RAH-RAVEN-MISSION-CONTROL.html'\n      - 'RAH-RAVEN-MISSION-CONTROL-VERSION.json'\n      - 'RAH-RAVEN-VERSION.json'\n      - 'raven-checkpoint-policy.js'\n      - 'tests/raven-mission-control.test.mjs'\n      - 'tests/raven-release-gate.test.mjs'\n      - '.github/workflows/validate-raven-mission-control.yml'\n  pull_request:\n    paths:\n      - 'RAH-RAVEN-MISSION-CONTROL.html'\n      - 'RAH-RAVEN-MISSION-CONTROL-VERSION.json'\n      - 'RAH-RAVEN-VERSION.json'\n      - 'raven-checkpoint-policy.js'\n      - 'tests/raven-mission-control.test.mjs'\n      - 'tests/raven-release-gate.test.mjs'\n      - '.github/workflows/validate-raven-mission-control.yml'\n\npermissions:\n  contents: read\n\njobs:\n  validate:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - uses: actions/setup-node@v4\n        with:\n          node-version: '22'\n      - name: Validate Mission Control v2.9 boundary and aggregate contract\n        run: |\n          node tests/raven-mission-control.test.mjs\n          node tests/raven-release-gate.test.mjs\n          node --check raven-checkpoint-policy.js\n'''
write('.github/workflows/validate-raven-mission-control.yml',workflow)

print('Mission Control v2.9 candidate gates synchronized.')

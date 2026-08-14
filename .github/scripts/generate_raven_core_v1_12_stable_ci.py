from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'.ci-generated'
OUT.mkdir(exist_ok=True)

def read(path): return (ROOT/path).read_text(encoding='utf-8')
def write(name,text): (OUT/name).write_text(text,encoding='utf-8')
def rep(text,old,new,label,count=1):
    if text.count(old)<count: raise RuntimeError(f'{label} anchor missing')
    return text.replace(old,new,count)

# Package contract
p=read('.github/workflows/validate-raven-package.yml')
p=rep(p,'      - "RAH-RAVEN-PROJECT-FOCUS-VERSION.json"\n','      - "RAH-RAVEN-PROJECT-FOCUS-VERSION.json"\n      - "RAH-RAVEN-CORE-VERSION.json"\n','package core manifest paths',2)
p=rep(p,'      - "tests/raven-project-focus.test.mjs"\n','      - "tests/raven-project-focus.test.mjs"\n      - "tests/raven-core-local-boundary.test.mjs"\n','package core test paths',2)
p=rep(p,"          assert gate['component_versions']['project_focus']=='2.4'\n","          assert gate['component_versions']['project_focus']=='2.4'\n          assert gate['component_versions']['raven_core']=='1.12'\n",'package core version')
p=rep(p,"          assert gate['bugfix_component_updates']['project_focus']=='2.4'\n","          assert gate['bugfix_component_updates']['project_focus']=='2.4'\n          assert gate['bugfix_component_updates']['raven_core']=='1.12'\n",'package core bugfix')
p=rep(p,"          assert gate['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4'}\n","          assert gate['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12'}\n",'package stable components')
p=rep(p,"'project_focus_network_requests'):\n","'project_focus_network_requests','raven_core_external_bridge_addresses_allowed'):\n",'package forbidden core')
p=rep(p,"'RAH-RAVEN-PROJECT-FOCUS-VERSION.json'):\n","'RAH-RAVEN-PROJECT-FOCUS-VERSION.json','RAH-RAVEN-CORE-VERSION.json'):\n",'package required core')
p=rep(p,"          assert privacy['project_focus_stable'] is True\n","          assert privacy['project_focus_stable'] is True\n          assert privacy['raven_core_local_bridge_only'] is True\n          assert privacy['raven_core_dependency_versions_synced'] is True\n          assert privacy['raven_core_support_snapshot_version_synced'] is True\n          assert privacy['raven_core_report_version_synced'] is True\n          assert privacy['raven_core_stable'] is True\n",'package core privacy')
anchor="          assert project_focus['next_milestone'] is None\n"
core_block="""          core=json.loads(Path('RAH-RAVEN-CORE-VERSION.json').read_text(encoding='utf-8'))
          assert core['version']=='1.12.0'
          assert core['stage']=='stable'
          assert core['runtime_feature_change'] is False
          assert core['development_paused'] is True
          assert core['change_policy']=='bugfix-only-until-explicit-reopen'
          assert core['features']['local_bridge_only'] is True
          assert core['features']['external_bridge_addresses_allowed'] is False
          assert core['features']['dependency_cache_keys_synced'] is True
          assert core['features']['agent_execution'] is False
          assert core['features']['automatic_memory_sync'] is False
          assert core['features']['capability_set_changed'] is False
          assert core['stable_release_gate']['status']=='passed'
          assert core['stable_release_gate']['runtime_files_frozen'] is True
          assert core['next_milestone'] is None
"""
p=rep(p,anchor,anchor+core_block,'package core manifest block')
p=rep(p," + Project Focus {gate['component_versions']['project_focus']} stable\")\n"," + Project Focus {gate['component_versions']['project_focus']} + Core {gate['component_versions']['raven_core']} stable\")\n",'package print')
p=rep(p,'      - name: Run Project Focus v2.4 stable test\n        run: node tests/raven-project-focus.test.mjs\n','      - name: Run Project Focus v2.4 stable test\n        run: node tests/raven-project-focus.test.mjs\n\n      - name: Run Raven Core v1.12 stable boundary test\n        run: node tests/raven-core-local-boundary.test.mjs\n','package core step')
write('validate-raven-package.yml',p)

# Windows one-click contract
o=read('.github/workflows/validate-raven-one-click.yml')
o=rep(o,"      - 'RAH-RAVEN-PROJECT-FOCUS-VERSION.json'\n","      - 'RAH-RAVEN-PROJECT-FOCUS-VERSION.json'\n      - 'RAH-RAVEN-CORE-VERSION.json'\n",'oneclick core paths',2)
o=rep(o,"          assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4'}\n","          assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12'}\n",'oneclick bugfix')
o=rep(o,"          assert m['release_gate']['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4'}\n","          assert m['release_gate']['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12'}\n",'oneclick stable')
o=rep(o,"'RAH-RAVEN-PROJECT-FOCUS-VERSION.json']:\n","'RAH-RAVEN-PROJECT-FOCUS-VERSION.json','RAH-RAVEN-CORE-VERSION.json']:\n",'oneclick required')
anchor="          assert project_focus['next_milestone'] is None\n"
core_block="""          core=json.loads(Path('RAH-RAVEN-CORE-VERSION.json').read_text(encoding='utf-8'))
          assert core['version']=='1.12.0'
          assert core['stage']=='stable'
          assert core['runtime_feature_change'] is False
          assert core['development_paused'] is True
          assert core['change_policy']=='bugfix-only-until-explicit-reopen'
          assert core['features']['local_bridge_only'] is True
          assert core['features']['external_bridge_addresses_allowed'] is False
          assert core['features']['dependency_cache_keys_synced'] is True
          assert core['features']['agent_execution'] is False
          assert core['features']['automatic_memory_sync'] is False
          assert core['stable_release_gate']['status']=='passed'
          assert core['stable_release_gate']['runtime_files_frozen'] is True
          assert core['next_milestone'] is None
"""
o=rep(o,anchor,anchor+core_block,'oneclick core manifest')
o=rep(o,"'project_focus_network_requests']:\n","'project_focus_network_requests','raven_core_external_bridge_addresses_allowed']:\n",'oneclick forbidden')
o=rep(o,"            'project_focus_explicit_activation_only','project_focus_stale_selection_guard','project_focus_stable',\n","            'project_focus_explicit_activation_only','project_focus_stale_selection_guard','project_focus_stable',\n            'raven_core_local_bridge_only','raven_core_dependency_versions_synced','raven_core_support_snapshot_version_synced','raven_core_report_version_synced','raven_core_stable',\n",'oneclick core true')
o=rep(o,"          print('Manifest 2.0.32 / Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 + Project Focus v2.4 stable / launcher 3.0: OK')\n","          print('Manifest 2.0.32 / seven stable core components including Raven Core v1.12 / launcher 3.0: OK')\n",'oneclick print')
o=rep(o,"            'tests/raven-core-demo.test.mjs',\n","            'tests/raven-core-demo.test.mjs',\n            'tests/raven-core-local-boundary.test.mjs',\n",'oneclick core boundary test')
o=o.replace('Temporary Stable 2.0.32 + Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 + Project Focus v2.4 stable: OK','Temporary Stable 2.0.32 + seven stable core components including Raven Core v1.12: OK')
write('validate-raven-one-click.yml',o)

# Cross-platform release gate
r=read('.github/workflows/validate-raven-release-gate.yml')
r=rep(r,"      - 'RAH-RAVEN-PROJECT-FOCUS-VERSION.json'\n","      - 'RAH-RAVEN-PROJECT-FOCUS-VERSION.json'\n      - 'RAH-RAVEN-CORE-VERSION.json'\n",'release core paths',2)
r=r.replace('Run Raven 2.0.32 gate with six stable core components including Project Focus v2.4','Run Raven 2.0.32 gate with seven stable core components including Raven Core v1.12')
r=rep(r,'          node tests/raven-core-demo.test.mjs\n','          node tests/raven-core-demo.test.mjs\n          node tests/raven-core-local-boundary.test.mjs\n','release Linux core boundary')
r=rep(r,'          node tests/raven-project-focus.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n','          node tests/raven-project-focus.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n          node tests/raven-core-local-boundary.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n','release Windows core boundary')
r=r.replace('Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 + Project Focus v2.4 stable: OK','seven stable core components including Raven Core v1.12: OK')
write('validate-raven-release-gate.yml',r)

print('Generated Raven Core v1.12 stable CI copies.')

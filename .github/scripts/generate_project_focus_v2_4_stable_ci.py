from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'.ci-generated'
OUT.mkdir(exist_ok=True)

def read(path): return (ROOT/path).read_text(encoding='utf-8')
def write(name,text): (OUT/name).write_text(text,encoding='utf-8')
def once(text,old,new,label):
    if old not in text: raise RuntimeError(f'{label} anchor missing')
    return text.replace(old,new,1)

# Package gate
s=read('.github/workflows/validate-raven-package.yml')
s=s.replace('      - "RAH-RAVEN-MISSION-CONTROL-VERSION.json"\n','      - "RAH-RAVEN-MISSION-CONTROL-VERSION.json"\n      - "RAH-RAVEN-PROJECT-FOCUS-VERSION.json"\n')
s=s.replace('      - "tests/raven-mission-control.test.mjs"\n','      - "tests/raven-mission-control.test.mjs"\n      - "tests/raven-project-focus.test.mjs"\n')
s=once(s,"          assert gate['component_versions']['mission_control']=='2.9'\n","          assert gate['component_versions']['mission_control']=='2.9'\n          assert gate['component_versions']['project_focus']=='2.4'\n",'package project version')
s=once(s,"          assert gate['bugfix_component_updates']['mission_control']=='2.9'\n","          assert gate['bugfix_component_updates']['mission_control']=='2.9'\n          assert gate['bugfix_component_updates']['project_focus']=='2.4'\n",'package project bugfix')
s=once(s,"          assert gate['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9'}\n","          assert gate['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4'}\n",'package stable components')
s=once(s,"'mission_control_external_bridge_addresses_allowed','mission_control_automatic_step_completion'):","'mission_control_external_bridge_addresses_allowed','mission_control_automatic_step_completion','project_focus_active_mission_write','project_focus_mission_step_completion','project_focus_agent_execution','project_focus_network_requests'):",'package forbidden')
s=once(s,"'RAH-RAVEN-MEMORY-SYNC-VERSION.json','RAH-RAVEN-MISSION-CONTROL-VERSION.json'):","'RAH-RAVEN-MEMORY-SYNC-VERSION.json','RAH-RAVEN-MISSION-CONTROL-VERSION.json','RAH-RAVEN-PROJECT-FOCUS-VERSION.json'):",'package required manifest')
s=once(s,"          assert privacy['mission_control_stable'] is True\n","          assert privacy['mission_control_stable'] is True\n          assert privacy['project_focus_explicit_activation_only'] is True\n          assert privacy['project_focus_stale_selection_guard'] is True\n          assert privacy['project_focus_stable'] is True\n",'package project privacy')
mission_end="""          assert mission['stable_release_gate']['runtime_files_frozen'] is True
          assert mission['next_milestone'] is None
"""
project_block="""          project_focus=json.loads(Path('RAH-RAVEN-PROJECT-FOCUS-VERSION.json').read_text(encoding='utf-8'))
          assert project_focus['version']=='2.4.0'
          assert project_focus['stage']=='stable'
          assert project_focus['runtime_feature_change'] is False
          assert project_focus['development_paused'] is True
          assert project_focus['change_policy']=='bugfix-only-until-explicit-reopen'
          assert project_focus['features']['explicit_project_activation'] is True
          assert project_focus['features']['active_project_write_requires_explicit_confirmation'] is True
          assert project_focus['features']['stale_selection_guard'] is True
          assert project_focus['features']['project_identity_revalidated_before_write'] is True
          assert project_focus['features']['active_mission_write'] is False
          assert project_focus['features']['mission_step_completion'] is False
          assert project_focus['features']['agent_execution'] is False
          assert project_focus['features']['network_requests'] is False
          assert project_focus['features']['reconciliation_navigation_only'] is True
          assert project_focus['features']['capability_set_changed'] is False
          assert project_focus['stable_release_gate']['status']=='passed'
          assert project_focus['stable_release_gate']['runtime_files_frozen'] is True
          assert project_focus['next_milestone'] is None
"""
s=once(s,mission_end,mission_end+project_block,'package project manifest block')
s=s.replace(" + Mission Control {gate['component_versions']['mission_control']} stable\")"," + Mission Control {gate['component_versions']['mission_control']} + Project Focus {gate['component_versions']['project_focus']} stable\")")
s=once(s,"      - name: Run Mission Control v2.9 stable test\n        run: node tests/raven-mission-control.test.mjs\n","      - name: Run Mission Control v2.9 stable test\n        run: node tests/raven-mission-control.test.mjs\n\n      - name: Run Project Focus v2.4 stable test\n        run: node tests/raven-project-focus.test.mjs\n",'package project test')
assert "project_focus':'2.4" in s and 'Run Project Focus v2.4 stable test' in s
write('validate-raven-package.yml',s)

# Windows one-click gate
s=read('.github/workflows/validate-raven-one-click.yml')
s=s.replace("      - 'RAH-RAVEN-MISSION-CONTROL-VERSION.json'\n","      - 'RAH-RAVEN-MISSION-CONTROL-VERSION.json'\n      - 'RAH-RAVEN-PROJECT-FOCUS-VERSION.json'\n")
s=once(s,"          assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9'}\n","          assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4'}\n",'oneclick bugfix')
s=once(s,"          assert m['release_gate']['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9'}\n","          assert m['release_gate']['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4'}\n",'oneclick stable components')
s=once(s,"'RAH-RAVEN-MEMORY-SYNC-VERSION.json','RAH-RAVEN-MISSION-CONTROL-VERSION.json']:","'RAH-RAVEN-MEMORY-SYNC-VERSION.json','RAH-RAVEN-MISSION-CONTROL-VERSION.json','RAH-RAVEN-PROJECT-FOCUS-VERSION.json']:",'oneclick required manifest')
mission_end="""          assert mission['stable_release_gate']['runtime_files_frozen'] is True
          assert mission['next_milestone'] is None
"""
project_block="""          project_focus=json.loads(Path('RAH-RAVEN-PROJECT-FOCUS-VERSION.json').read_text(encoding='utf-8'))
          assert project_focus['version']=='2.4.0'
          assert project_focus['stage']=='stable'
          assert project_focus['runtime_feature_change'] is False
          assert project_focus['development_paused'] is True
          assert project_focus['change_policy']=='bugfix-only-until-explicit-reopen'
          assert project_focus['features']['explicit_project_activation'] is True
          assert project_focus['features']['active_project_write_requires_explicit_confirmation'] is True
          assert project_focus['features']['stale_selection_guard'] is True
          assert project_focus['features']['project_identity_revalidated_before_write'] is True
          assert project_focus['features']['active_mission_write'] is False
          assert project_focus['features']['mission_step_completion'] is False
          assert project_focus['features']['agent_execution'] is False
          assert project_focus['features']['network_requests'] is False
          assert project_focus['features']['capability_set_changed'] is False
          assert project_focus['stable_release_gate']['status']=='passed'
          assert project_focus['stable_release_gate']['runtime_files_frozen'] is True
          assert project_focus['next_milestone'] is None
"""
s=once(s,mission_end,mission_end+project_block,'oneclick project manifest block')
s=once(s,"'mission_control_external_bridge_addresses_allowed','mission_control_automatic_step_completion']:","'mission_control_external_bridge_addresses_allowed','mission_control_automatic_step_completion','project_focus_active_mission_write','project_focus_mission_step_completion','project_focus_agent_execution','project_focus_network_requests']:",'oneclick forbidden')
s=once(s,"            'mission_control_local_bridge_only','mission_control_chronicle_context_read_only','mission_control_stable',\n","            'mission_control_local_bridge_only','mission_control_chronicle_context_read_only','mission_control_stable',\n            'project_focus_explicit_activation_only','project_focus_stale_selection_guard','project_focus_stable',\n",'oneclick required true')
s=s.replace(' + Mission Control v2.9 stable / launcher 3.0: OK',' + Mission Control v2.9 + Project Focus v2.4 stable / launcher 3.0: OK')
s=s.replace(' + Mission Control v2.9 stable: OK',' + Mission Control v2.9 + Project Focus v2.4 stable: OK')
assert "'project_focus':'2.4'" in s and "project_focus_stable" in s
write('validate-raven-one-click.yml',s)

# Release gate
s=read('.github/workflows/validate-raven-release-gate.yml')
s=s.replace("      - 'RAH-RAVEN-MISSION-CONTROL-VERSION.json'\n","      - 'RAH-RAVEN-MISSION-CONTROL-VERSION.json'\n      - 'RAH-RAVEN-PROJECT-FOCUS-VERSION.json'\n")
s=s.replace('Run Raven 2.0.32 gate with Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 stable','Run Raven 2.0.32 gate with six stable core components including Project Focus v2.4')
s=once(s,"          node tests/raven-mission-control.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n","          node tests/raven-mission-control.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n          node tests/raven-project-focus.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }\n",'release windows project test')
s=s.replace(' + Mission Control v2.9 stable: OK',' + Mission Control v2.9 + Project Focus v2.4 stable: OK')
assert 'node tests/raven-project-focus.test.mjs' in s and 'six stable core components' in s
write('validate-raven-release-gate.yml',s)

print('Generated Project Focus v2.4 stable CI contracts.')

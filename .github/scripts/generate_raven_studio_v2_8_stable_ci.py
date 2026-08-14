from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'.ci-generated'
OUT.mkdir(exist_ok=True)

def r(path): return (ROOT/path).read_text(encoding='utf-8')
def w(name,text): (OUT/name).write_text(text,encoding='utf-8')
def rep(text,old,new,label,count=None):
    actual=text.count(old)
    if count is not None and actual!=count:
        raise RuntimeError(f'{label}: expected {count}, got {actual}')
    if actual==0:
        raise RuntimeError(f'{label}: anchor missing')
    return text.replace(old,new)

# Package gate: require Studio as the ninth frozen component.
pkg=r('.github/workflows/validate-raven-package.yml')
pkg=rep(pkg,'      - "RAH-RAVEN-NOW-VERSION.json"\n','      - "RAH-RAVEN-NOW-VERSION.json"\n      - "RAH-RAVEN-STUDIO-VERSION.json"\n','package Studio manifest paths',2)
pkg=rep(pkg,"          assert gate['component_versions']['raven_core']=='1.12'\n","          assert gate['component_versions']['raven_core']=='1.12'\n          assert gate['component_versions']['raven_now']=='2.17'\n          assert gate['component_versions']['raven_studio']=='2.8'\n",'package component pins',1)
pkg=rep(pkg,"          assert gate['bugfix_component_updates']['raven_now']=='2.17'\n","          assert gate['bugfix_component_updates']['raven_now']=='2.17'\n          assert gate['bugfix_component_updates']['raven_studio']=='2.8'\n",'package bugfix Studio pin',1)
pkg=rep(pkg,"          assert gate['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17'}","          assert gate['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17','raven_studio':'2.8'}",'package stable dict',1)
pkg=rep(pkg,"'RAH-RAVEN-CORE-VERSION.json','RAH-RAVEN-NOW-VERSION.json'):","'RAH-RAVEN-CORE-VERSION.json','RAH-RAVEN-NOW-VERSION.json','RAH-RAVEN-STUDIO-VERSION.json'):",'package required manifest tuple',1)
pkg=rep(pkg,"          assert privacy['raven_core_stable'] is True\n","          assert privacy['raven_core_stable'] is True\n          assert privacy['raven_studio_status_polling_loopback_only'] is True\n          assert privacy['raven_studio_external_status_addresses_allowed'] is False\n          assert privacy['raven_studio_raven_state_writes'] is False\n          assert privacy['raven_studio_mission_mutation'] is False\n          assert privacy['raven_studio_mission_step_completion'] is False\n          assert privacy['raven_studio_agent_execution'] is False\n          assert privacy['raven_studio_footer_version_synced'] is True\n          assert privacy['raven_studio_stable'] is True\n",'package Studio privacy',1)
pkg=rep(pkg,"          assert now['next_milestone'] is None\n",'''          assert now['next_milestone'] is None
          studio=json.loads(Path('RAH-RAVEN-STUDIO-VERSION.json').read_text(encoding='utf-8'))
          assert studio['version']=='2.8.0'
          assert studio['stage']=='stable'
          assert studio['runtime_feature_change'] is False
          assert studio['development_paused'] is True
          assert studio['change_policy']=='bugfix-only-until-explicit-reopen'
          assert studio['features']['local_first_launcher'] is True
          assert studio['features']['status_polling_enabled'] is True
          assert studio['features']['status_polling_loopback_only'] is True
          assert studio['features']['external_status_addresses_allowed'] is False
          assert studio['features']['raven_state_writes'] is False
          assert studio['features']['mission_mutation'] is False
          assert studio['features']['mission_step_completion'] is False
          assert studio['features']['agent_execution'] is False
          assert studio['features']['automatic_sending'] is False
          assert studio['features']['footer_raven_version_synced'] is True
          assert studio['stable_release_gate']['status']=='passed'
          assert studio['stable_release_gate']['runtime_files_frozen'] is True
          assert studio['next_milestone'] is None
''','package Studio component contract',1)
pkg=rep(pkg," + Raven Now {gate['component_versions']['raven_now']} stable"," + Raven Now {gate['component_versions']['raven_now']} + Raven Studio {gate['component_versions']['raven_studio']} stable",'package print identity',1)
pkg=rep(pkg,"      - name: Run Raven Now v2.17 stable boundary test\n        run: node tests/raven-now-local-boundary.test.mjs\n","      - name: Run Raven Now v2.17 stable boundary test\n        run: node tests/raven-now-local-boundary.test.mjs\n\n      - name: Run Raven Studio v2.8 stable test\n        run: node tests/raven-studio.test.mjs\n",'package Studio test step',1)
w('validate-raven-package.yml',pkg)

# Windows one-click gate: enforce nine stable component manifests and Studio semantics.
one=r('.github/workflows/validate-raven-one-click.yml')
one=rep(one,"      - 'RAH-RAVEN-NOW-VERSION.json'\n","      - 'RAH-RAVEN-NOW-VERSION.json'\n      - 'RAH-RAVEN-STUDIO-VERSION.json'\n",'one-click Studio manifest paths',2)
one=rep(one,"assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17'}","assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17','raven_studio':'2.8'}",'one-click bugfix dict',1)
one=rep(one,"assert m['release_gate']['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17'}","assert m['release_gate']['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17','raven_studio':'2.8'}",'one-click stable dict',1)
one=rep(one,"'RAH-RAVEN-CORE-VERSION.json','RAH-RAVEN-NOW-VERSION.json']:","'RAH-RAVEN-CORE-VERSION.json','RAH-RAVEN-NOW-VERSION.json','RAH-RAVEN-STUDIO-VERSION.json']:",'one-click required manifest list',1)
one=rep(one,"          assert now['next_milestone'] is None\n",'''          assert now['next_milestone'] is None
          studio=json.loads(Path('RAH-RAVEN-STUDIO-VERSION.json').read_text(encoding='utf-8'))
          assert studio['version']=='2.8.0' and studio['stage']=='stable'
          assert studio['development_paused'] is True
          assert studio['change_policy']=='bugfix-only-until-explicit-reopen'
          assert studio['features']['status_polling_loopback_only'] is True
          assert studio['features']['external_status_addresses_allowed'] is False
          assert studio['features']['raven_state_writes'] is False
          assert studio['features']['mission_mutation'] is False
          assert studio['features']['mission_step_completion'] is False
          assert studio['features']['agent_execution'] is False
          assert studio['features']['footer_raven_version_synced'] is True
          assert studio['stable_release_gate']['runtime_files_frozen'] is True
          assert studio['next_milestone'] is None
''','one-click Studio component contract',1)
one=rep(one,"'raven_core_external_bridge_addresses_allowed']:","'raven_core_external_bridge_addresses_allowed','raven_studio_external_status_addresses_allowed','raven_studio_raven_state_writes','raven_studio_mission_mutation','raven_studio_mission_step_completion','raven_studio_agent_execution']:",'one-click Studio false privacy',1)
one=rep(one,"            'raven_core_local_bridge_only','raven_core_dependency_versions_synced','raven_core_support_snapshot_version_synced','raven_core_report_version_synced','raven_core_stable',\n","            'raven_core_local_bridge_only','raven_core_dependency_versions_synced','raven_core_support_snapshot_version_synced','raven_core_report_version_synced','raven_core_stable',\n            'raven_studio_status_polling_loopback_only','raven_studio_footer_version_synced','raven_studio_stable',\n",'one-click Studio true privacy',1)
one=rep(one,"          print('Manifest 2.0.32 / seven stable core components including Raven Core v1.12 / launcher 3.0: OK')","          print('Manifest 2.0.32 / nine stable core components including Raven Studio v2.8 / launcher 3.0: OK')",'one-click manifest label',1)
one=rep(one,"            'tests/raven-now-local-boundary.test.mjs',\n","            'tests/raven-now-local-boundary.test.mjs',\n            'tests/raven-studio.test.mjs',\n",'one-click Studio semantic test',1)
one=rep(one,"          Write-Host 'RAH Raven one-click -> Temporary Stable 2.0.32 + seven stable core components including Raven Core v1.12: OK'","          Write-Host 'RAH Raven one-click -> Temporary Stable 2.0.32 + nine stable core components including Raven Studio v2.8: OK'",'one-click final label',1)
w('validate-raven-one-click.yml',one)

# Aggregate release gate: run Studio stable semantics on Linux and Windows and correct labels.
rel=r('.github/workflows/validate-raven-release-gate.yml')
rel=rep(rel,"      - 'RAH-RAVEN-NOW-VERSION.json'\n","      - 'RAH-RAVEN-NOW-VERSION.json'\n      - 'RAH-RAVEN-STUDIO-VERSION.json'\n",'release Studio manifest paths',2)
rel=rep(rel,'Run Raven 2.0.32 gate with eight stable core components including Raven Now v2.17','Run Raven 2.0.32 gate with nine stable core components including Raven Studio v2.8','release step identity',1)
rel=rep(rel,'''          node tests/raven-core-demo.test.mjs
          node tests/raven-core-local-boundary.test.mjs
          node tests/raven-now-local-boundary.test.mjs
          node tests/raven-core-context.test.mjs
''','''          node tests/raven-core-demo.test.mjs
          node tests/raven-core-local-boundary.test.mjs
          node tests/raven-now-local-boundary.test.mjs
          node tests/raven-studio.test.mjs
          node tests/raven-core-context.test.mjs
''','release Linux Studio test',1)
rel=rep(rel,'          node tests/raven-core-local-boundary.test.mjs\n          node tests/raven-now-local-boundary.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }','          node tests/raven-core-local-boundary.test.mjs\n          node tests/raven-now-local-boundary.test.mjs\n          node tests/raven-studio.test.mjs\n          if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }','release Windows Studio test',1)
rel=rep(rel,"          Write-Host 'Raven 2.0.32 Windows gate: seven stable core components including Raven Core v1.12: OK'","          Write-Host 'Raven 2.0.32 Windows gate: nine stable core components including Raven Studio v2.8: OK'",'release Windows label',1)
w('validate-raven-release-gate.yml',rel)

for name in ('validate-raven-package.yml','validate-raven-one-click.yml','validate-raven-release-gate.yml'):
    text=(OUT/name).read_text(encoding='utf-8')
    assert 'RAH-RAVEN-STUDIO-VERSION.json' in text, name
    assert 'Raven Studio v2.8' in text or 'raven_studio' in text, name
    assert 'nine stable' in text or "'raven_studio':'2.8'" in text, name

print('Generated Raven Studio v2.8 nine-component stable CI contracts.')

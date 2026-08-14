from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'.ci-generated'; OUT.mkdir(exist_ok=True)

def r(p): return (ROOT/p).read_text(encoding='utf-8')
def w(n,t): (OUT/n).write_text(t,encoding='utf-8')
def rep(t,a,b,label):
    if a not in t: raise RuntimeError(label)
    return t.replace(a,b)

pkg=r('.github/workflows/validate-raven-package.yml')
pkg=pkg.replace('      - "RAH-RAVEN-CORE-VERSION.json"\n','      - "RAH-RAVEN-CORE-VERSION.json"\n      - "RAH-RAVEN-NOW-VERSION.json"\n')
pkg=rep(pkg,"assert gate['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12'}","assert gate['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17'}",'pkg stable dict')
pkg=pkg.replace("          assert gate['bugfix_component_updates']['raven_core']=='1.12'\n","          assert gate['bugfix_component_updates']['raven_core']=='1.12'\n          assert gate['bugfix_component_updates']['raven_now']=='2.17'\n")
pkg=pkg.replace("'RAH-RAVEN-CORE-VERSION.json'):","'RAH-RAVEN-CORE-VERSION.json','RAH-RAVEN-NOW-VERSION.json'):")
pkg=pkg.replace("          assert core['next_milestone'] is None\n",'''          assert core['next_milestone'] is None
          now=json.loads(Path('RAH-RAVEN-NOW-VERSION.json').read_text(encoding='utf-8'))
          assert now['version']=='2.17.0'
          assert now['stage']=='stable'
          assert now['runtime_feature_change'] is False
          assert now['development_paused'] is True
          assert now['change_policy']=='bugfix-only-until-explicit-reopen'
          assert now['features']['read_only_dashboard'] is True
          assert now['features']['local_bridge_only'] is True
          assert now['features']['external_bridge_addresses_allowed'] is False
          assert now['features']['state_writes'] is False
          assert now['features']['agent_execution'] is False
          assert now['stable_release_gate']['status']=='passed'
          assert now['stable_release_gate']['runtime_files_frozen'] is True
          assert now['next_milestone'] is None
''')
pkg=pkg.replace("      - name: Run Raven Core v1.12 stable boundary test\n        run: node tests/raven-core-local-boundary.test.mjs\n","      - name: Run Raven Core v1.12 stable boundary test\n        run: node tests/raven-core-local-boundary.test.mjs\n\n      - name: Run Raven Now v2.17 stable boundary test\n        run: node tests/raven-now-local-boundary.test.mjs\n")
pkg=pkg.replace(' + Core {gate[\'component_versions\'][\'raven_core\']} stable',' + Core {gate[\'component_versions\'][\'raven_core\']} + Raven Now {gate[\'component_versions\'][\'raven_now\']} stable')
w('validate-raven-package.yml',pkg)

one=r('.github/workflows/validate-raven-one-click.yml')
one=one.replace("      - 'RAH-RAVEN-CORE-VERSION.json'\n","      - 'RAH-RAVEN-CORE-VERSION.json'\n      - 'RAH-RAVEN-NOW-VERSION.json'\n")
one=rep(one,"assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12'}","assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17'}",'one bugfix dict')
one=rep(one,"assert m['release_gate']['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12'}","assert m['release_gate']['stable_components']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17'}",'one stable dict')
one=one.replace("'RAH-RAVEN-CORE-VERSION.json']:","'RAH-RAVEN-CORE-VERSION.json','RAH-RAVEN-NOW-VERSION.json']:")
one=one.replace("          assert core['next_milestone'] is None\n",'''          assert core['next_milestone'] is None
          now=json.loads(Path('RAH-RAVEN-NOW-VERSION.json').read_text(encoding='utf-8'))
          assert now['version']=='2.17.0' and now['stage']=='stable'
          assert now['development_paused'] is True
          assert now['features']['local_bridge_only'] is True
          assert now['features']['external_bridge_addresses_allowed'] is False
          assert now['features']['read_only_dashboard'] is True
          assert now['stable_release_gate']['runtime_files_frozen'] is True
          assert now['next_milestone'] is None
''')
one=one.replace("            'tests/raven-core-local-boundary.test.mjs',\n","            'tests/raven-core-local-boundary.test.mjs',\n            'tests/raven-now-local-boundary.test.mjs',\n")
one=one.replace(' + Raven Core v1.12 stable / launcher 3.0',' + Raven Core v1.12 + Raven Now v2.17 stable / launcher 3.0')
w('validate-raven-one-click.yml',one)

rel=r('.github/workflows/validate-raven-release-gate.yml')
rel=rel.replace("      - 'RAH-RAVEN-CORE-VERSION.json'\n","      - 'RAH-RAVEN-CORE-VERSION.json'\n      - 'RAH-RAVEN-NOW-VERSION.json'\n")
rel=rel.replace('Run Raven 2.0.32 gate with seven stable core components including Raven Core v1.12','Run Raven 2.0.32 gate with eight stable core components including Raven Now v2.17')
rel=rel.replace('          node tests/raven-core-local-boundary.test.mjs\n','          node tests/raven-core-local-boundary.test.mjs\n          node tests/raven-now-local-boundary.test.mjs\n')
rel=rel.replace('Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 + Project Focus v2.4 + Raven Core v1.12 stable: OK','Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 + Project Focus v2.4 + Raven Core v1.12 + Raven Now v2.17 stable: OK')
w('validate-raven-release-gate.yml',rel)

for name in ('validate-raven-package.yml','validate-raven-one-click.yml','validate-raven-release-gate.yml'):
    text=(OUT/name).read_text(encoding='utf-8')
    assert 'raven_now' in text and '2.17' in text
print('Generated Raven Now v2.17 stable CI copies.')

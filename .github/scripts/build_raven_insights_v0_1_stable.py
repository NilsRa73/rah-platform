from __future__ import annotations
import json
import subprocess
from pathlib import Path

BASE='270949a5b91cf73c99656bc8270f4404ace83451'
ROOT=Path('.')
MANIFEST=ROOT/'RAH-RAVEN-INSIGHTS-VERSION.json'
MASTER=ROOT/'RAH-RAVEN-VERSION.json'
TEST=ROOT/'tests/raven-insights-v0.1.test.mjs'

frozen=[
 'RAH-RAVEN-INSIGHTS.html','.github/workflows/validate-raven-insights-v0.1.yml',
 'RAH-RAVEN-CHRONICLE-LIVE.html','RAH-RAVEN-CHRONICLE-VERSION.json','desktop-bridge/server_v17.py','desktop-bridge/chronicle_insights.py','desktop-bridge/chronicle_ai.py','desktop-bridge/raven_bridge.py','.github/workflows/validate-chronicle-v17.yml','tests/raven-chronicle-v17.test.mjs',
 'RAH-COMMAND-CENTER-VERSION.json','RAH-COMMAND-CENTER-V0.5.html','rah-command-center-core.js','rah-node-agent.py','DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','UPDATE-RAH-COMMAND-CENTER.ps1','UPDATE-RAH-RAVEN.ps1',
 'RAH-RAVEN-CARE.html','RAH-RAVEN-CARE-VERSION.json','RAH-RAVEN-FRISTVAKT.html','RAH-RAVEN-FRISTVAKT-VERSION.json',
 'RAH-RAVEN-VISION-CORE.html','RAH-RAVEN-VISION-VERSION.json','RAH-RAVEN-COUNCIL.html','RAH-RAVEN-COUNCIL-VERSION.json','RAH-RAVEN-AGENT-RUNNER.html','RAH-RAVEN-AGENT-RUNNER-VERSION.json','RAH-RAVEN-MEMORY-SYNC.html','RAH-RAVEN-MEMORY-SYNC-VERSION.json','RAH-RAVEN-MISSION-CONTROL.html','RAH-RAVEN-MISSION-CONTROL-VERSION.json','RAH-RAVEN-PROJECT.html','RAH-RAVEN-PROJECT-FOCUS-VERSION.json','RAH-RAVEN-CORE-DEMO.html','RAH-RAVEN-CORE-VERSION.json','RAH-RAVEN-NOW.html','RAH-RAVEN-NOW-VERSION.json','RAH-RAVEN-START.html','RAH-RAVEN-STUDIO-VERSION.json','raven-checkpoint-policy.js'
]

def sh(*args): subprocess.run(args,check=True)
def assert_frozen():
    for path in frozen:
        current=Path(path).read_bytes()
        base=subprocess.check_output(['git','show',f'{BASE}:{path}'])
        if current!=base:
            raise SystemExit(f'frozen file changed: {path}')

assert_frozen()
m=json.loads(MANIFEST.read_text(encoding='utf-8'))
if m.get('version')!='0.1.0' or m.get('stage')!='candidate' or m.get('release_gate',{}).get('status')!='candidate':
    raise SystemExit('Insights candidate baseline mismatch')
m['stage']='stable'
m['stable_since']='2026-08-15'
m['development_paused']=True
m['change_policy']='bugfix-only-until-explicit-reopen'
m.pop('next_milestone',None)
m['release_gate']['status']='passed'
m['release_gate']['gate_version']='1.0.0'
m['release_gate']['runtime_files_frozen']=True
m['release_gate']['change_policy']='bugfix-only-until-explicit-reopen'
MANIFEST.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

master=json.loads(MASTER.read_text(encoding='utf-8'))
expected={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17','raven_studio':'2.8'}
if master['release_gate']['stable_components']!=expected:
    raise SystemExit('nine-core Stable set changed')
if master.get('privacy',{}).get('raven_fristvakt_stable') is not True or 'Command Center v0.5.0' not in master.get('summary',''):
    raise SystemExit('expected current Stable platform baseline missing')
master['summary']=('RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, Project Brain Cloud Sync v1.1, Voice Control v1.7, Mission Engine v1.6, Raven Care v0.1, Raven Fristvakt v0.2, RAH Raven Command Center v0.5.0 and Raven Insights v0.1 are stable. Insights reads Chronicle only after explicit refresh from the local Bridge; background polling is disabled and completion requires confirmation.')
for path in ['RAH-RAVEN-INSIGHTS.html','RAH-RAVEN-INSIGHTS-VERSION.json']:
    if path not in master['files']: master['files'].append(path)
p=master.setdefault('privacy',{})
p.update({
 'raven_insights_version_synced':True,
 'raven_insights_explicit_refresh_only':True,
 'raven_insights_startup_network_requests':False,
 'raven_insights_background_polling':False,
 'raven_insights_bridge_base_loopback_only':True,
 'raven_insights_endpoint_allowlist':True,
 'raven_insights_completion_requires_confirmation':True,
 'raven_insights_automatic_completion':False,
 'raven_insights_automatic_sending':False,
 'raven_insights_credentials_sent':False,
 'raven_insights_chronicle_backend_changed':False,
 'raven_insights_runtime_frozen':True,
 'raven_insights_stable':True
})
MASTER.write_text(json.dumps(master,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

t=TEST.read_text(encoding='utf-8')
t=t.replace("assert.equal(manifest.stage,'candidate');","assert.equal(manifest.stage,'stable');\nassert.equal(manifest.stable_since,'2026-08-15');\nassert.equal(manifest.development_paused,true);\nassert.equal(manifest.change_policy,'bugfix-only-until-explicit-reopen');\nassert.equal(manifest.next_milestone,undefined);")
t=t.replace("assert.equal(manifest.release_gate.status,'candidate');","assert.equal(manifest.release_gate.status,'passed');\nassert.equal(manifest.release_gate.gate_version,'1.0.0');\nassert.equal(manifest.release_gate.runtime_files_frozen,true);")
needle="assert.equal(chronicle.development_paused,true);"
extra="""assert.equal(chronicle.development_paused,true);
assert.match(raven.summary,/Raven Insights v0\\.1 are stable/);
for (const file of ['RAH-RAVEN-INSIGHTS.html','RAH-RAVEN-INSIGHTS-VERSION.json']) assert.equal(raven.files.includes(file),true,file);
for (const [key,value] of Object.entries({raven_insights_version_synced:true,raven_insights_explicit_refresh_only:true,raven_insights_startup_network_requests:false,raven_insights_background_polling:false,raven_insights_bridge_base_loopback_only:true,raven_insights_endpoint_allowlist:true,raven_insights_completion_requires_confirmation:true,raven_insights_automatic_completion:false,raven_insights_automatic_sending:false,raven_insights_credentials_sent:false,raven_insights_chronicle_backend_changed:false,raven_insights_runtime_frozen:true,raven_insights_stable:true})) assert.equal(raven.privacy[key],value,key);"""
if needle not in t: raise SystemExit('Insights test baseline mismatch')
t=t.replace(needle,extra)
t=t.replace("console.log('RAH Raven Insights v0.1 candidate explicit-local boundary passed');","console.log('RAH Raven Insights v0.1 Stable explicit-local boundary passed');")
TEST.write_text(t,encoding='utf-8')

assert_frozen()
sh('node','tests/raven-insights-v0.1.test.mjs')
sh('node','tests/raven-chronicle-v17.test.mjs')
sh('node','tests/raven-release-gate.test.mjs')
sh('node','tests/rah-command-center-v05.test.mjs')
sh('node','tests/raven-fristvakt-v0.2.test.mjs')
sh('node','tests/raven-care-v0.1.test.mjs')
sh('git','diff','--check')
allowed={'RAH-RAVEN-INSIGHTS-VERSION.json','RAH-RAVEN-VERSION.json','tests/raven-insights-v0.1.test.mjs','.github/scripts/build_raven_insights_v0_1_stable.py','.github/workflows/build-raven-insights-v0.1-stable-gate.yml'}
paths={line[3:] for line in subprocess.check_output(['git','status','--porcelain']).decode().splitlines()}
if not paths<=allowed: raise SystemExit(f'unexpected diff: {sorted(paths-allowed)}')
sh('git','config','user.name','RAH Raven Builder')
sh('git','config','user.email','actions@users.noreply.github.com')
sh('git','add','RAH-RAVEN-INSIGHTS-VERSION.json','RAH-RAVEN-VERSION.json','tests/raven-insights-v0.1.test.mjs')
sh('git','commit','-m','chore: promote Raven Insights v0.1 to stable')
sh('git','push','origin','HEAD:raven-insights/v0.1-stable-gate')

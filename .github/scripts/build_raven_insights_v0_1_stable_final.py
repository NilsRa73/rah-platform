from __future__ import annotations
import json
import subprocess
from pathlib import Path

BASE='e2aaeed97e00ed03c349187c1e90853b997b4c29'
ROOT=Path('.')
MANIFEST=ROOT/'RAH-RAVEN-INSIGHTS-VERSION.json'
MASTER=ROOT/'RAH-RAVEN-VERSION.json'
TEST=ROOT/'tests/raven-insights-v0.1.test.mjs'

FROZEN=[
 'RAH-RAVEN-INSIGHTS.html','.github/workflows/validate-raven-insights-v0.1.yml',
 'RAH-RAVEN-CHRONICLE-LIVE.html','RAH-RAVEN-CHRONICLE-VERSION.json','desktop-bridge/server_v17.py','desktop-bridge/chronicle_insights.py','desktop-bridge/chronicle_ai.py','desktop-bridge/raven_bridge.py','.github/workflows/validate-chronicle-v17.yml','tests/raven-chronicle-v17.test.mjs',
 'RAH-COMMAND-CENTER-VERSION.json','RAH-COMMAND-CENTER-V0.6.html','RAH-COMMAND-CENTER-V0.5.html','RAH-COMMAND-CENTER-V0.4.html','rah-command-center-core.js','rah-node-agent.py','START-RAH-NODE-AGENT.bat','START-RAH-NODE-AGENT.sh','DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','UPDATE-RAH-COMMAND-CENTER.ps1','UPDATE-RAH-RAVEN.ps1','.github/workflows/validate-rah-command-center.yml','tests/rah-command-center-v06.test.mjs','tests/rah-command-center-v05.test.mjs','tests/rah-command-center-v04.test.mjs','tests/rah-command-center-core.test.mjs','tests/rah-command-center-packaging.test.mjs','tests/test_rah_node_agent.py',
 'RAH-RAVEN-CARE.html','RAH-RAVEN-CARE-VERSION.json','RAH-RAVEN-FRISTVAKT.html','RAH-RAVEN-FRISTVAKT-VERSION.json','.github/workflows/validate-raven-fristvakt-v0.2.yml',
 'RAH-RAVEN-VISION-CORE.html','RAH-RAVEN-VISION-VERSION.json','RAH-RAVEN-COUNCIL.html','RAH-RAVEN-COUNCIL-VERSION.json','RAH-RAVEN-AGENT-RUNNER.html','RAH-RAVEN-AGENT-RUNNER-VERSION.json','RAH-RAVEN-MEMORY-SYNC.html','RAH-RAVEN-MEMORY-SYNC-VERSION.json','RAH-RAVEN-MISSION-CONTROL.html','RAH-RAVEN-MISSION-CONTROL-VERSION.json','RAH-RAVEN-PROJECT.html','RAH-RAVEN-PROJECT-FOCUS-VERSION.json','RAH-RAVEN-CORE-DEMO.html','RAH-RAVEN-CORE-VERSION.json','RAH-RAVEN-NOW.html','RAH-RAVEN-NOW-VERSION.json','RAH-RAVEN-START.html','RAH-RAVEN-STUDIO-VERSION.json','raven-checkpoint-policy.js'
]

def sh(*args): subprocess.run(args,check=True)
def assert_frozen():
    for path in FROZEN:
        current=Path(path).read_bytes()
        base=subprocess.check_output(['git','show',f'{BASE}:{path}'])
        if current != base:
            raise SystemExit(f'frozen file changed: {path}')

assert_frozen()
manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
if manifest.get('version')!='0.1.0' or manifest.get('stage')!='candidate': raise SystemExit('Insights candidate baseline mismatch')
if manifest.get('chronicle_dependency')!='1.7.x' or manifest.get('features',{}).get('chronicle_patch_compatible') is not True: raise SystemExit('Chronicle 1.7.x compatibility missing')
if manifest.get('release_gate',{}).get('status')!='candidate': raise SystemExit('Insights gate baseline mismatch')
manifest['stage']='stable'
manifest['stable_since']='2026-08-15'
manifest['development_paused']=True
manifest['change_policy']='bugfix-only-until-explicit-reopen'
manifest.pop('next_milestone',None)
manifest['release_gate']['status']='passed'
manifest['release_gate']['gate_version']='1.0.0'
manifest['release_gate']['runtime_files_frozen']=True
manifest['release_gate']['change_policy']='bugfix-only-until-explicit-reopen'
MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

master=json.loads(MASTER.read_text(encoding='utf-8'))
expected={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17','raven_studio':'2.8'}
if master['release_gate']['stable_components']!=expected: raise SystemExit('nine-core Stable set changed')
privacy=master.setdefault('privacy',{})
if privacy.get('raven_fristvakt_stable') is not True: raise SystemExit('Fristvakt Stable missing')
if privacy.get('raven_chronicle_stable') is not True: raise SystemExit('Chronicle Stable missing')
if privacy.get('command_center_stable') is not True or 'Command Center v0.6.0' not in master.get('summary',''): raise SystemExit('Command Center v0.6 Stable master baseline missing')
master['summary']=('RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, Project Brain Cloud Sync v1.1, Voice Control v1.7, Mission Engine v1.6, Raven Care v0.1, Raven Fristvakt v0.2 and RAH Raven Command Center v0.6.0 are stable. Command Center v0.6 adds explicitly declared read-only node capabilities from a fixed allowlist; capability scanning, background polling, file access, shell access, device commands and remote control remain disabled. Raven Chronicle v1.7.1 is stable with its local-origin security boundary frozen. Raven Insights v0.1 is stable as a separate platform module; it reads Chronicle only after explicit refresh from the local Bridge, disables background polling, and requires confirmation before append-only completion.')
for path in ['RAH-RAVEN-INSIGHTS.html','RAH-RAVEN-INSIGHTS-VERSION.json']:
    if path not in master['files']: master['files'].append(path)
privacy.update({
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
 'raven_insights_chronicle_patch_compatible':True,
 'raven_insights_runtime_frozen':True,
 'raven_insights_stable':True
})
MASTER.write_text(json.dumps(master,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

t=TEST.read_text(encoding='utf-8')
t=t.replace("assert.equal(manifest.stage,'candidate');","assert.equal(manifest.stage,'stable');\nassert.equal(manifest.stable_since,'2026-08-15');\nassert.equal(manifest.development_paused,true);\nassert.equal(manifest.change_policy,'bugfix-only-until-explicit-reopen');\nassert.equal(manifest.next_milestone,undefined);")
t=t.replace("assert.equal(manifest.release_gate.status,'candidate');","assert.equal(manifest.release_gate.status,'passed');\nassert.equal(manifest.release_gate.gate_version,'1.0.0');\nassert.equal(manifest.release_gate.runtime_files_frozen,true);")
start=t.index("assert.match(chronicle.version,/^1\\.7\\./);")
end=t.index("\n\nconst scripts=",start)
chronicle_block="""assert.equal(chronicle.version,'1.7.1');
assert.equal(chronicle.previous_stable_version,'1.7.0');
assert.equal(chronicle.stage,'stable');
assert.equal(chronicle.development_paused,true);
assert.equal(chronicle.change_policy,'bugfix-only-until-explicit-reopen');
assert.match(raven.summary,/Raven Chronicle v1\\.7\\.1 is stable/);
assert.match(raven.summary,/Raven Insights v0\\.1 is stable/);
for (const file of ['RAH-RAVEN-INSIGHTS.html','RAH-RAVEN-INSIGHTS-VERSION.json']) assert.equal(raven.files.includes(file),true,file);
for (const [key,value] of Object.entries({raven_insights_version_synced:true,raven_insights_explicit_refresh_only:true,raven_insights_startup_network_requests:false,raven_insights_background_polling:false,raven_insights_bridge_base_loopback_only:true,raven_insights_endpoint_allowlist:true,raven_insights_completion_requires_confirmation:true,raven_insights_automatic_completion:false,raven_insights_automatic_sending:false,raven_insights_credentials_sent:false,raven_insights_chronicle_backend_changed:false,raven_insights_chronicle_patch_compatible:true,raven_insights_runtime_frozen:true,raven_insights_stable:true})) assert.equal(raven.privacy[key],value,key);"""
t=t[:start]+chronicle_block+t[end:]
t=t.replace("console.log('RAH Raven Insights v0.1 candidate explicit-local boundary passed across Chronicle 1.7.x patches');","console.log('RAH Raven Insights v0.1 Stable explicit-local boundary passed over Chronicle v1.7.1 Stable');")
TEST.write_text(t,encoding='utf-8')

assert_frozen()
for cmd in [
 ['node','tests/raven-insights-v0.1.test.mjs'],
 ['node','tests/raven-chronicle-v17.test.mjs'],
 ['node','tests/raven-release-gate.test.mjs'],
 ['node','tests/rah-command-center-v06.test.mjs'],
 ['node','tests/rah-command-center-v04.test.mjs'],
 ['node','tests/raven-fristvakt-v0.2.test.mjs'],
 ['node','tests/raven-care-v0.1.test.mjs'],
 ['node','tests/raven-case-center-v16.test.mjs']
]: sh(*cmd)
sh('git','diff','--check')
allowed={'RAH-RAVEN-INSIGHTS-VERSION.json','RAH-RAVEN-VERSION.json','tests/raven-insights-v0.1.test.mjs','.github/scripts/build_raven_insights_v0_1_stable_final.py','.github/workflows/build-raven-insights-v0.1-stable-final.yml'}
paths={line[3:] for line in subprocess.check_output(['git','status','--porcelain']).decode().splitlines()}
if not paths<=allowed: raise SystemExit(f'unexpected diff: {sorted(paths-allowed)}')
sh('git','config','user.name','RAH Raven Builder')
sh('git','config','user.email','actions@users.noreply.github.com')
sh('git','add','RAH-RAVEN-INSIGHTS-VERSION.json','RAH-RAVEN-VERSION.json','tests/raven-insights-v0.1.test.mjs')
sh('git','commit','-m','chore: promote Raven Insights v0.1 to stable')
sh('git','push','origin','HEAD:raven-insights/v0.1-stable-final')

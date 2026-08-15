from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
MASTER=ROOT/'RAH-RAVEN-VERSION.json'
EXPECTED_CORE={
    'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2',
    'mission_control':'2.9','project_focus':'2.4','raven_core':'1.12','raven_now':'2.17','raven_studio':'2.8'
}
FROZEN=[
    'RAH-RAVEN-CHRONICLE-LIVE.html','RAH-RAVEN-CHRONICLE-VERSION.json','desktop-bridge/server_v17.py',
    'desktop-bridge/chronicle_ai.py','desktop-bridge/test_chronicle_ai.py','tests/raven-chronicle-v17.test.mjs',
    'RAH-RAVEN-INSIGHTS.html','RAH-RAVEN-INSIGHTS-VERSION.json','tests/raven-insights-v0.1.test.mjs',
    'RAH-RAVEN-VISION-CORE.html','raven-vision-core.js','RAH-RAVEN-COUNCIL.html','raven-council.js',
    'RAH-RAVEN-AGENT-RUNNER.html','desktop-bridge/agent_runner.py','RAH-RAVEN-MEMORY-SYNC.html',
    'RAH-RAVEN-MISSION-CONTROL.html','RAH-RAVEN-PROJECT.html','RAH-RAVEN-CORE-DEMO.html','RAH-RAVEN-NOW.html'
]

def digest(path:str)->str:
    return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()

def run(*args:str,cwd:Path|None=None)->None:
    subprocess.run(args,cwd=cwd or ROOT,check=True)

before={p:digest(p) for p in FROZEN}
data=json.loads(MASTER.read_text(encoding='utf-8'))
assert data['release_gate']['stable_components']==EXPECTED_CORE
assert data['privacy']['raven_insights_stable'] is True
assert data['privacy']['raven_insights_runtime_frozen'] is True

files=data['files']
if 'RAH-RAVEN-DAILY-BRIEF-VERSION.json' not in files:
    try:
        pos=files.index('RAH-RAVEN-DAILY-BRIEF.html')+1
    except ValueError:
        pos=len(files)
    files.insert(pos,'RAH-RAVEN-DAILY-BRIEF-VERSION.json')

sentence=(' Raven Daily Brief v0.1 is a candidate platform module with no startup read, no background polling, '
          'a fixed loopback Bridge base, explicit local refresh or AI generation, and required human review; '
          'Chronicle and Insights runtimes remain unchanged.')
if 'Raven Daily Brief v0.1 is a candidate platform module' not in data['summary']:
    data['summary']=data['summary'].rstrip()+sentence

privacy=data['privacy']
privacy.update({
    'raven_daily_brief_version_synced':True,
    'raven_daily_brief_explicit_refresh_only':True,
    'raven_daily_brief_explicit_generate_only':True,
    'raven_daily_brief_startup_network_requests':False,
    'raven_daily_brief_selection_change_network_requests':False,
    'raven_daily_brief_background_polling':False,
    'raven_daily_brief_bridge_base_loopback_only':True,
    'raven_daily_brief_endpoint_allowlist':True,
    'raven_daily_brief_local_lm_only':True,
    'raven_daily_brief_human_review_required':True,
    'raven_daily_brief_server_persists_ai_answer':False,
    'raven_daily_brief_automatic_sending':False,
    'raven_daily_brief_credentials_sent':False,
    'raven_daily_brief_chronicle_backend_changed':False,
    'raven_daily_brief_chronicle_patch_compatible':True,
    'raven_daily_brief_runtime_frozen':False,
    'raven_daily_brief_stable':False
})
assert data['release_gate']['stable_components']==EXPECTED_CORE
MASTER.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

after={p:digest(p) for p in FROZEN}
assert before==after,'Frozen Chronicle/Insights/core runtime changed'

run('node','tests/raven-daily-brief-v0.1.test.mjs')
run('node','tests/raven-chronicle-v17.test.mjs')
run('node','tests/raven-insights-v0.1.test.mjs')
run('node','tests/raven-release-gate.test.mjs')
run('python','test_chronicle_ai.py',cwd=ROOT/'desktop-bridge')
run('python','test_raven_bridge_security.py',cwd=ROOT/'desktop-bridge')

changed=subprocess.check_output(['git','diff','--name-only'],cwd=ROOT,text=True).splitlines()
assert changed==['RAH-RAVEN-VERSION.json'],changed
run('git','add','RAH-RAVEN-VERSION.json')
run('git','commit','-m','Sync Daily Brief v0.1 candidate metadata')
run('git','push','origin','HEAD')
print('Daily Brief v0.1 candidate metadata synced and validated')

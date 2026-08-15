from __future__ import annotations
import json
import subprocess
from pathlib import Path

BASE='774eed0035474c039bedd233fc670188011d5be7'
ROOT=Path('.')
MASTER=ROOT/'RAH-RAVEN-VERSION.json'
TEST=ROOT/'tests/rah-command-center-v05.test.mjs'

frozen=[
 'RAH-COMMAND-CENTER-VERSION.json','RAH-COMMAND-CENTER-V0.5.html','rah-command-center-core.js','rah-node-agent.py',
 'START-RAH-NODE-AGENT.bat','START-RAH-NODE-AGENT.sh','DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat',
 'UPDATE-RAH-COMMAND-CENTER.ps1','UPDATE-RAH-RAVEN.ps1','RAH-RAVEN-FRISTVAKT-VERSION.json','RAH-RAVEN-FRISTVAKT.html',
 'RAH-RAVEN-CARE-VERSION.json','RAH-RAVEN-CARE.html','raven-checkpoint-policy.js'
]

def sh(*args):
    subprocess.run(args,check=True)

def assert_frozen():
    for path in frozen:
        current=Path(path).read_bytes()
        base=subprocess.check_output(['git','show',f'{BASE}:{path}'])
        if current!=base:
            raise SystemExit(f'frozen file changed: {path}')

assert_frozen()
master=json.loads(MASTER.read_text(encoding='utf-8'))
expected={
 'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3','memory_sync':'0.2','mission_control':'2.9',
 'project_focus':'2.4','raven_core':'1.12','raven_now':'2.17','raven_studio':'2.8'
}
if master['release_gate']['stable_components'] != expected:
    raise SystemExit('nine-core stable set changed')
if 'Command Center v0.4.1' not in master.get('summary',''):
    raise SystemExit('expected stale v0.4.1 summary baseline not found')
if master.get('privacy',{}).get('raven_fristvakt_stable') is not True:
    raise SystemExit('Fristvakt Stable metadata must already exist')
master['summary']=('RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, Project Brain Cloud Sync v1.1, '
 'Voice Control v1.7, Mission Engine v1.6, Raven Care v0.1, Raven Fristvakt v0.2 and RAH Raven Command Center v0.5 are stable. '
 'Command Center v0.5 adds explicit private-LAN device enrollment through a read-only Node Agent; no discovery, command channel, shell, file API or background polling is enabled.')
p=master.setdefault('privacy',{})
p.update({
 'command_center_explicit_device_enrollment': True,
 'command_center_enrollment_metadata_local_storage_only': True,
 'command_center_node_agent_read_only_health': True,
 'command_center_node_agent_fixed_port': 18766,
 'command_center_node_agent_default_loopback_bind': True,
 'command_center_node_agent_lan_bind_requires_explicit_flag': True,
 'command_center_node_agent_token_memory_only': True,
 'command_center_node_agent_command_endpoints': False,
 'command_center_node_agent_file_endpoints': False,
 'command_center_node_agent_shell_endpoints': False,
 'command_center_enrollment_private_ipv4_only': True,
 'command_center_enrollment_token_local_storage': False,
 'command_center_enrollment_token_url_transport': False,
 'command_center_device_health_check_explicit_only': True,
 'command_center_device_background_polling': False,
 'command_center_network_discovery': False,
 'command_center_remote_control': False,
 'command_center_device_commands': False,
 'command_center_credential_collection': False
})
MASTER.write_text(json.dumps(master,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

t=TEST.read_text(encoding='utf-8')
old="assert.deepEqual(raven.release_gate.stable_components,expected);assert.match(raven.summary,/Command Center v0\\.4\\.1/);assert.equal(raven.privacy.command_center_stable,true);assert.equal(raven.privacy.command_center_runtime_frozen,true);"
new="assert.deepEqual(raven.release_gate.stable_components,expected);assert.match(raven.summary,/Command Center v0\\.5/);assert.match(raven.summary,/read-only Node Agent/);assert.equal(raven.privacy.command_center_stable,true);assert.equal(raven.privacy.command_center_runtime_frozen,true);for(const [k,v] of Object.entries({command_center_explicit_device_enrollment:true,command_center_enrollment_metadata_local_storage_only:true,command_center_node_agent_read_only_health:true,command_center_node_agent_fixed_port:18766,command_center_node_agent_default_loopback_bind:true,command_center_node_agent_lan_bind_requires_explicit_flag:true,command_center_node_agent_token_memory_only:true,command_center_node_agent_command_endpoints:false,command_center_node_agent_file_endpoints:false,command_center_node_agent_shell_endpoints:false,command_center_enrollment_private_ipv4_only:true,command_center_enrollment_token_local_storage:false,command_center_enrollment_token_url_transport:false,command_center_device_health_check_explicit_only:true,command_center_device_background_polling:false,command_center_network_discovery:false,command_center_remote_control:false,command_center_device_commands:false,command_center_credential_collection:false}))assert.equal(raven.privacy[k],v,k);"
if old not in t:
    raise SystemExit('expected v0.5 master assertion baseline not found')
TEST.write_text(t.replace(old,new),encoding='utf-8')

assert_frozen()
sh('node','--test','tests/rah-command-center-v05.test.mjs')
sh('node','--test','tests/raven-release-gate.test.mjs')
sh('node','--test','tests/raven-fristvakt-v0.2.test.mjs')
sh('node','--test','tests/raven-care-v0.1.test.mjs')
allowed={'RAH-RAVEN-VERSION.json','tests/rah-command-center-v05.test.mjs','.github/scripts/build_command_center_v0_5_master_sync.py','.github/workflows/build-command-center-v0.5-master-sync.yml'}
changed=set(subprocess.check_output(['git','status','--porcelain']).decode().splitlines())
paths={line[3:] for line in changed}
if not paths <= allowed:
    raise SystemExit(f'unexpected diff: {sorted(paths-allowed)}')
sh('git','diff','--check')
sh('git','config','user.name','RAH Raven Builder')
sh('git','config','user.email','actions@users.noreply.github.com')
sh('git','add','RAH-RAVEN-VERSION.json','tests/rah-command-center-v05.test.mjs')
sh('git','commit','-m','chore: sync Raven master to Command Center v0.5')
sh('git','push','origin','HEAD:command-center/v0.5-master-sync')

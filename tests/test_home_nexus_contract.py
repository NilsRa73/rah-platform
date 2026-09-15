from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'RAH-HOME-NEXUS.html'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket Nexus-adferd: {label}: {needle!r}')


def extract_model(text: str) -> str:
    match = re.search(r'// RAH_NEXUS_MODEL_START\s*(.*?)\s*// RAH_NEXUS_MODEL_END', text, re.S)
    if not match:
        raise AssertionError('Mangler RAH_NEXUS_MODEL validation block')
    return match.group(1)


def run_node_model(model: str) -> None:
    test_js = r'''
const MAX_HOME_DEVICES=500,MAX_CLUSTER_NODES=16;
''' + model + r'''
function assert(cond,msg){if(!cond)throw new Error(msg)}
const d1={id:'a',ip:'192.168.1.10',name:'Alpha'};
const d2={id:'b',ip:'8.8.8.8',name:'Public'};
const home={devices:[d1,d2]};
const trust={version:1,devices:{}};
trust.devices[fp(d1)]={trusted:true,deviceId:'a',ip:'192.168.1.10'};
trust.devices[fp(d2)]={trusted:true,deviceId:'b',ip:'8.8.8.8'};
let s=deriveNexusStatus(home,trust,{version:1,enabledIds:['a','b','ghost','a'],leaderId:'a'});
assert(s.deviceCount===2,'device count');
assert(s.trustedCount===2,'current trust count');
assert(s.workerCount===1,'only current trusted RFC1918 enabled node counts');
assert(s.leaderName==='Alpha','eligible enabled leader');

const moved={id:'a',ip:'192.168.1.11',name:'Alpha'};
const staleTrust={version:1,devices:{}};
staleTrust.devices[fp(moved)]={trusted:true,deviceId:'a',ip:'192.168.1.10'};
s=deriveNexusStatus({devices:[moved]},staleTrust,{version:1,enabledIds:['a'],leaderId:'a'});
assert(s.trustedCount===0,'stale IP trust must not count');
assert(s.workerCount===0,'stale trust worker must not count');
assert(s.leaderName===null,'stale trust leader must not count');

const validTrust={version:1,devices:{}};
validTrust.devices[fp(d1)]={trusted:true,deviceId:'a',ip:'192.168.1.10'};
s=deriveNexusStatus({devices:[d1]},validTrust,{version:1,enabledIds:[],leaderId:'a'});
assert(s.workerCount===0,'leader not enabled must not count');
assert(s.leaderName===null,'leader must also be active');

s=deriveNexusStatus(null,null,null);
assert(s.deviceCount===0&&s.trustedCount===0&&s.workerCount===0&&s.leaderName===null,'malformed state fallback');
assert(isPrivateIPv4('10.0.0.1')&&isPrivateIPv4('172.31.2.3')&&isPrivateIPv4('192.168.1.1'),'RFC1918 accepted');
assert(!isPrivateIPv4('127.0.0.1')&&!isPrivateIPv4('8.8.8.8')&&!isPrivateIPv4('192.168.001.1'),'non-RFC1918 rejected');
console.log('PASS: RAH Home Nexus v1 model behavior');
'''
    with tempfile.NamedTemporaryFile('w', suffix='.js', encoding='utf-8', delete=False) as handle:
        handle.write(test_js)
        path = Path(handle.name)
    try:
        subprocess.run(['node', '--check', str(path)], check=True)
        subprocess.run(['node', str(path)], check=True)
    finally:
        path.unlink(missing_ok=True)


def main() -> None:
    text = PAGE.read_text(encoding='utf-8')
    for path in (
        'RAH-HOME-CONTROL.html',
        'RAH-HOME-DISCOVERY-INBOX.html',
        'RAH-HOME-TRUST.html',
        'RAH-HOME-CLUSTER.html',
        'RAH-HOME-INSTALL.cmd',
        'RAH-HOME-DISCOVERY-RUN.cmd',
        'RAH-HOME-DISCOVERY-ACTIVE-RUN.cmd',
        'RAH-HOME-PAIR-WIZARD.ps1',
        'RAH-HOME-CLUSTER-CONTROLLER.ps1',
        'RAH-HOME-NODE-AGENT.ps1',
        'RAH-HOME-NODE-CLIENT.ps1',
        'RAH-HOME-NODE-SETUP.cmd',
    ):
        require(text, path, f'launcher-link {path}')

    for needle, label in (
        ('Stable MVP v1.0', 'stable page label'),
        ("HOME_KEY='rah-home-control-v03'", 'Home Control state summary'),
        ("TRUST_KEY='rah-home-trust-v01'", 'Trust state summary'),
        ("CLUSTER_KEY='rah-home-cluster-v01'", 'Cluster state summary'),
        ('trustRecordMatchesDevice', 'current trust binding check'),
        ('eligibleClusterDevices', 'private cluster eligibility'),
        ('deriveNexusStatus', 'pure status derivation'),
        ('MAX_LOCAL_CHARS=2000000', 'bounded local state parsing'),
    ):
        require(text, needle, label)

    for needle, label in (
        ('fetch(', 'background fetch'),
        ('XMLHttpRequest', 'XHR network'),
        ('new WebSocket', 'WebSocket network'),
        ('EventSource(', 'event stream network'),
        ('sendBeacon(', 'beacon network'),
    ):
        forbid(text, needle, label)

    run_node_model(extract_model(text))
    print('PASS: RAH Home Nexus v1 integrated launcher contract')


if __name__ == '__main__':
    main()

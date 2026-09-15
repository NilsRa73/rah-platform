from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
INBOX = ROOT / 'RAH-HOME-DISCOVERY-INBOX.html'
RUNNER = ROOT / 'RAH-HOME-DISCOVERY-RUN.ps1'
ACTIVE_RUNNER = ROOT / 'RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket discovery i inbox: {label}: {needle!r}')


def extract_script(html: str) -> str:
    scripts = re.findall(r'<script>(.*?)</script>', html, flags=re.DOTALL | re.IGNORECASE)
    if not scripts:
        raise AssertionError('Fant ingen inline JavaScript i Discovery Inbox.')
    return '\n'.join(scripts)


def extract_validation_block(script: str) -> str:
    match = re.search(
        r'// RAH_VALIDATION_START(.*?)// RAH_VALIDATION_END',
        script,
        flags=re.DOTALL,
    )
    if not match:
        raise AssertionError('Fant ikke testbar RAH validation block.')
    return match.group(1)


def node_check(script: str) -> None:
    with tempfile.NamedTemporaryFile('w', suffix='.js', encoding='utf-8', delete=False) as handle:
        handle.write(script)
        path = Path(handle.name)
    try:
        result = subprocess.run(
            ['node', '--check', str(path)],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(f'JavaScript syntax check feilet:\n{result.stdout}\n{result.stderr}')
    finally:
        path.unlink(missing_ok=True)


def run_validator_behavior(validation_block: str) -> None:
    behavioral_tests = r'''
function assertRah(condition,message){if(!condition)throw new Error(message)}
function clone(x){return JSON.parse(JSON.stringify(x))}

const adapter={
  ifIndex:7,
  name:'Ethernet',
  interfaceDescription:'Mock Ethernet Adapter',
  status:'Up',
  macAddress:'AA-BB-CC-DD-EE-01',
  linkSpeed:'1 Gbps'
};

const passive={
  schema:'rah-home-discovery-cache',
  version:1,
  scriptVersion:'1.0.0',
  product:'RAH Home Control',
  mode:'passive-neighbor-cache',
  passive:true,
  generatedAt:'2026-09-15T10:00:00.000Z',
  adapters:[adapter],
  devices:[{
    ipAddress:'192.168.1.20',
    macAddress:'AA-BB-CC-DD-EE-20',
    ifIndex:7,
    state:'Reachable',
    source:'windows-neighbor-cache',
    passive:true
  }]
};

assertRah(validDiscovery(passive),'valid passive document rejected');

let t=clone(passive);t.devices[0].ipAddress='8.8.8.8';
assertRah(!validDiscovery(t),'public IPv4 accepted');

t=clone(passive);t.devices[0].ifIndex=99;
assertRah(!validDiscovery(t),'device on unknown adapter accepted');

t=clone(passive);t.devices.push(clone(t.devices[0]));
assertRah(!validDiscovery(t),'duplicate interface/IP accepted');

t=clone(passive);t.passive=false;
assertRah(!validDiscovery(t),'passive mode with false passive flag accepted');

t=clone(passive);t.devices[0].source='<script>';
assertRah(!validDiscovery(t),'unsafe source text accepted');

t=clone(passive);t.devices[0].macAddress='not-a-mac';
assertRah(!validDiscovery(t),'invalid MAC accepted');

t=clone(passive);t.devices[0].state='Unknown';
assertRah(!validDiscovery(t),'unknown neighbor state accepted');

const active=clone(passive);
active.mode='active-local-subnet';
active.passive=false;
active.authorization='explicit-start-local-private-subnet';
active.scan={
  localIp:'192.168.1.10',
  prefixLength:24,
  network:'192.168.1.0',
  maxHosts:254,
  scannedHosts:42,
  timeoutMs:250,
  delayMs:20,
  protocol:'ICMP echo only'
};
active.devices[0].passive=false;
active.devices[0].source='rah-active-icmp-local-subnet';
assertRah(validDiscovery(active),'valid active document rejected');

t=clone(active);delete t.scan;
assertRah(!validDiscovery(t),'active document without scan metadata accepted');

t=clone(active);t.scan.localIp='1.1.1.1';
assertRah(!validDiscovery(t),'active public localIp accepted');

console.log('PASS: validator behavior');
'''
    result = subprocess.run(
        ['node', '-e', validation_block + '\n' + behavioral_tests],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(f'Validator behavior feilet:\n{result.stdout}\n{result.stderr}')


def main() -> None:
    html = INBOX.read_text(encoding='utf-8')
    ps1 = RUNNER.read_text(encoding='utf-8')
    active_ps1 = ACTIVE_RUNNER.read_text(encoding='utf-8')
    script = extract_script(html)
    validation_block = extract_validation_block(script)

    require(html, 'Stable MVP v1.0', 'stable versjonsmerking')
    require(script, "const HOME_KEY='rah-home-control-v03'", 'samme Home Control-lagringsnøkkel')
    require(script, "const DISCOVERY_SCHEMA='rah-home-discovery-cache'", 'discovery schema')
    require(script, "const ALLOWED_MODES=['passive-neighbor-cache','active-local-subnet']", 'kun eksplisitt støttede modes')
    require(script, 'const MAX_JSON_CHARS=2000000', 'importgrense')
    require(script, 'isPrivateIPv4(d.ipAddress)', 'kandidater må være private IPv4')
    require(script, 'adapterIds.has(d.ifIndex)', 'kandidat må høre til kjent adapter')
    require(script, "x.authorization==='explicit-start-local-private-subnet'", 'aktiv discovery krever authorization-markør')
    require(script, "s.protocol==='ICMP echo only'", 'aktiv discovery må være ICMP-only')
    require(script, 'state.devices.push(item)', 'godkjent kandidat legges i register')
    require(script, 'if(!saveHome(state))', 'lagringsfeil håndteres')
    require(script, 'state.devices.pop()', 'rollback ved lagringsfeil')
    require(script, 'state.devices.find(d=>d.ip===device.ipAddress)', 'duplikat-IP avvises')
    require(script, "room:'Ikke valgt'", 'ny kandidat får nøytral romplassering')
    require(script, "role:'Ubestemt'", 'ny kandidat får nøytral rolle')
    require(script, "online:device.state==='Reachable'", 'lokal status avledes konservativt')
    require(script, 'navigator.clipboard.readText()', 'utklippstavleimport')
    require(script, "discovery.passive?'PASSIV KANDIDAT':'AKTIV KANDIDAT'", 'mode vises tydelig')

    for token, label in (
        ('RTCPeerConnection', 'WebRTC'),
        ('new WebSocket', 'WebSocket'),
        ('navigator.bluetooth', 'Bluetooth'),
        ('navigator.usb', 'USB'),
        ('fetch(', 'nettverks-fetch'),
        ('XMLHttpRequest', 'XHR'),
        ('Test-Connection', 'PowerShell ping embedded in page'),
    ):
        forbid(script, token, label)

    require(ps1, 'RAH-HOME-DISCOVERY.ps1', 'passiv runner bruker passiv discovery-script')
    require(ps1, 'RAH-HOME-DISCOVERY-INBOX.html', 'passiv runner åpner inbox')

    # Active runner contract is behavioral/semantic, not tied to one exact UI sentence.
    require(active_ps1, 'RAH-HOME-DISCOVERY-ACTIVE.ps1', 'aktiv runner bruker aktivt discovery-script')
    require(active_ps1, 'Read-Host', 'aktiv runner krever menneskelig input')
    require(active_ps1, 'Type JA to start', 'aktiv runner forklarer eksplisitt JA-krav')
    require(active_ps1, 'Test-RahActiveConsent -Answer $answer', 'aktiv runner validerer menneskelig svar')
    require(active_ps1, 'return ($Answer -ceq \'JA\')', 'kun eksakt JA godtas')
    require(active_ps1, 'Start = $true', 'aktiv discovery får eksplisitt Start')
    require(active_ps1, 'RAH-HOME-DISCOVERY-INBOX.html', 'aktiv runner åpner samme inbox')
    for bypass in ('[switch]$Force', '[switch]$Yes', '[string]$Confirmation'):
        forbid(active_ps1, bypass, 'aktiv runner skal ikke ha samtykke-bypass')

    node_check(script)
    run_validator_behavior(validation_block)
    print('PASS: RAH Home Discovery Inbox v1 contract + validator behavior')


if __name__ == '__main__':
    main()

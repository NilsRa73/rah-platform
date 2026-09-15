from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'RAH-HOME-TRUST.html'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket mekanisme i Home Trust: {label}: {needle!r}')


def extract_script(html: str) -> str:
    scripts = re.findall(r'<script>(.*?)</script>', html, flags=re.DOTALL | re.IGNORECASE)
    if not scripts:
        raise AssertionError('Fant ingen inline JavaScript i Home Trust.')
    return '\n'.join(scripts)


def extract_validation_block(script: str) -> str:
    match = re.search(
        r'// RAH_TRUST_VALIDATION_START(.*?)// RAH_TRUST_VALIDATION_END',
        script,
        flags=re.DOTALL,
    )
    if not match:
        raise AssertionError('Fant ikke testbar RAH Trust validation block.')
    return match.group(1)


def node_check(script: str) -> None:
    with tempfile.NamedTemporaryFile('w', suffix='.js', encoding='utf-8', delete=False) as handle:
        handle.write(script)
        path = Path(handle.name)
    try:
        result = subprocess.run(['node', '--check', str(path)], text=True, capture_output=True, check=False)
        if result.returncode != 0:
            raise AssertionError(f'JavaScript syntax check feilet:\n{result.stdout}\n{result.stderr}')
    finally:
        path.unlink(missing_ok=True)


def run_behavior(validation_block: str) -> None:
    constants = "const MAX_RECEIPT_AGE_MS=24*60*60*1000,CLOCK_SKEW_MS=5*60*1000;\n"
    tests = r'''
function assertRah(condition,message){if(!condition)throw new Error(message)}
function clone(x){return JSON.parse(JSON.stringify(x))}
const now=Date.parse('2026-09-15T11:00:00.000Z');
const receipt={
  schema:'rah-home-pairing-receipt',version:1,nodeAddress:'192.168.1.20',port:18766,
  computerName:'RAH-WORKER',pairedAt:'2026-09-15T10:30:00.000Z',
  source:'explicit-pair-code-and-authenticated-system-info'
};
assertRah(validReceipt(receipt,now),'valid receipt rejected');
let t=clone(receipt);t.nodeAddress='8.8.8.8';assertRah(!validReceipt(t,now),'public IP accepted');
t=clone(receipt);t.port=80;assertRah(!validReceipt(t,now),'privileged port accepted');
t=clone(receipt);t.computerName='<script>';assertRah(!validReceipt(t,now),'unsafe hostname accepted');
t=clone(receipt);t.pairedAt='2026-09-13T10:00:00.000Z';assertRah(!validReceipt(t,now),'stale receipt accepted');
t=clone(receipt);t.pairedAt='2026-09-15T11:06:00.000Z';assertRah(!validReceipt(t,now),'future receipt beyond skew accepted');
t=clone(receipt);t.token='secret';assertRah(!validReceipt(t,now),'unexpected secret field accepted');
const home={devices:[{id:'d1',name:'Worker',ip:'192.168.1.20'}]};
assertRah(receiptMatches(home,receipt).length===1,'unique receipt match failed');
const dup={devices:[...home.devices,{id:'d2',name:'Other',ip:'192.168.1.20'}]};
assertRah(receiptMatches(dup,receipt).length===2,'duplicate IP not surfaced');
const record={trusted:true,deviceId:'d1',ip:'192.168.1.20'};
assertRah(trustRecordMatchesDevice(record,home.devices[0]),'valid trust record rejected');
assertRah(!trustRecordMatchesDevice(record,{id:'d1',name:'Worker',ip:'192.168.1.21'}),'IP-changed device remained trusted');
assertRah(fingerprint(home.devices[0])==='d1|192.168.1.20|Worker','cluster-compatible fingerprint changed');
console.log('PASS: Home Trust validator behavior');
'''
    result = subprocess.run(['node', '-e', constants + validation_block + '\n' + tests], text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise AssertionError(f'Home Trust behavior feilet:\n{result.stdout}\n{result.stderr}')


def main() -> None:
    html = PAGE.read_text(encoding='utf-8')
    script = extract_script(html)
    block = extract_validation_block(script)

    require(html, 'Stable MVP v1.0', 'stable versjonsmerking')
    require(script, "const HOME_KEY='rah-home-control-v03',TRUST_KEY='rah-home-trust-v01'", 'cluster-kompatibel trust-lagring')
    require(script, 'MAX_RECEIPT_CHARS=65536', 'filstørrelse begrenses')
    require(script, 'MAX_RECEIPT_AGE_MS=24*60*60*1000', 'pairing-evidens må være fersk')
    require(script, 'isPrivateIPv4(x.nodeAddress)', 'pairing-evidens må være privat IPv4')
    require(script, "source='explicit-local-user-approval'", 'manuell eksplisitt godkjenning støttes')
    require(script, "'pairing-receipt-user-confirmed'", 'pairing-evidens krever lokal brukerbekreftelse')
    require(script, 'if(!confirm(', 'klarering krever eksplisitt bekreftelse')
    require(script, 'matches.length!==1', 'pairing krever entydig IP-match')
    require(script, 'trustRecordMatchesDevice(record,d)', 'trust-record valideres mot aktuell enhet')
    require(script, "btn.textContent=trusted?'Fjern klarering':'Klarer denne enheten'", 'klarering kan settes og fjernes')
    require(script, 'if(!saveTrust(trust))', 'lagringsfeil håndteres')
    require(script, "pairingSource:x.source", 'pairing metadata beholdes uten hemmelighet')
    require(script, "return[d&&d.id||'',d&&d.ip||'',d&&d.name||''].join('|')", 'fingerprint er kompatibelt med Home Cluster')

    forbid(html, 'verified-pairing-receipt', 'usignert fil må ikke omtales som verifisert proof')
    for token, label in (
        ('fetch(', 'HTTP'),('XMLHttpRequest', 'XHR'),('WebSocket', 'WebSocket'),
        ('RTCPeerConnection', 'WebRTC'),('navigator.bluetooth', 'Bluetooth'),('navigator.usb', 'USB'),
    ):
        forbid(script, token, label)

    node_check(script)
    run_behavior(block)
    print('PASS: RAH Home Trust v1 local approval + receipt-evidence contract')


if __name__ == '__main__':
    main()

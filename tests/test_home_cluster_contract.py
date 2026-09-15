from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'RAH-HOME-CLUSTER.html'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket nettverksadferd i cluster: {label}: {needle!r}')


def extract_script(html: str) -> str:
    scripts = re.findall(r'<script>(.*?)</script>', html, flags=re.DOTALL | re.IGNORECASE)
    if not scripts:
        raise AssertionError('Fant ingen inline JavaScript i Home Cluster.')
    return '\n'.join(scripts)


def extract_validation_block(script: str) -> str:
    match = re.search(r'// RAH_CLUSTER_VALIDATION_START(.*?)// RAH_CLUSTER_VALIDATION_END', script, flags=re.DOTALL)
    if not match:
        raise AssertionError('Fant ikke testbar RAH Cluster validation block.')
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


def run_behavior(block: str) -> None:
    constants = "const MAX_TASKS=200,MAX_PLAN_JOBS=16,NODE_PORT=18766;\n"
    tests = r'''
function assertRah(c,m){if(!c)throw new Error(m)}
function clone(x){return JSON.parse(JSON.stringify(x))}
const d={id:'d1',name:'Worker',ip:'192.168.1.20'};
const h={devices:[d]};
const tr={version:1,devices:{'d1|192.168.1.20|Worker':{trusted:true,deviceId:'d1',ip:'192.168.1.20'}}};
assertRah(eligibleDevices(h,tr).length===1,'valid trusted private node rejected');
let bad=clone(h);bad.devices[0].ip='8.8.8.8';assertRah(eligibleDevices(bad,tr).length===0,'public node accepted');
let badTrust=clone(tr);badTrust.devices['d1|192.168.1.20|Worker'].ip='192.168.1.21';assertRah(eligibleDevices(h,badTrust).length===0,'mismatched trust record accepted');
const c={version:1,leaderId:'d1',enabledIds:['d1'],tasks:[
 {id:'a',name:'health',job:'health',status:'Planlagt',assignedId:'d1',executable:true},
 {id:'b',name:'Render video',kind:'Render',status:'Planlagt',assignedId:'d1',executable:false},
 {id:'c',name:'health',job:'shell',status:'Planlagt',assignedId:'d1',executable:true}
]};
const normalized=normalizeCluster(c);
assertRah(normalized.tasks.length===2,'invalid executable task not removed');
const plan=buildSafePlan(normalized,[d],'2026-09-15T12:00:00.000Z');
assertRah(plan.schema==='rah-home-cluster-plan'&&plan.version===1,'plan contract broken');
assertRah(plan.nodes.length===1&&plan.nodes[0].job==='health'&&plan.nodes[0].nodeAddress==='192.168.1.20','unsafe/local-only task leaked into plan');
let disabled=clone(normalized);disabled.enabledIds=[];assertRah(buildSafePlan(disabled,[d],'2026-09-15T12:00:00.000Z').nodes.length===0,'disabled node exported');
const resultDoc={schema:'rah-home-cluster-results',version:1,createdAt:'2026-09-15T12:00:00.000Z',results:[{nodeAddress:'192.168.1.20',port:18766,job:'health',ok:true,startedAt:'2026-09-15T12:00:01.000Z',finishedAt:'2026-09-15T12:00:02.000Z',result:{ok:true},message:null}]};
assertRah(validResultsDocument(resultDoc),'valid controller result rejected');
let r=clone(resultDoc);r.results[0].nodeAddress='1.1.1.1';assertRah(!validResultsDocument(r),'public result node accepted');
r=clone(resultDoc);r.results[0].job='shell';assertRah(!validResultsDocument(r),'unknown result job accepted');
r=clone(resultDoc);r.results[0].port=80;assertRah(!validResultsDocument(r),'privileged result port accepted');
r=clone(resultDoc);r.results[0].startedAt='not-a-date';assertRah(!validResultsDocument(r),'bad timestamp accepted');
r=clone(resultDoc);r.results=Array.from({length:17},()=>clone(resultDoc.results[0]));assertRah(!validResultsDocument(r),'too many result rows accepted');
console.log('PASS: Home Cluster validator behavior');
'''
    result = subprocess.run(['node', '-e', constants + block + '\n' + tests], text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise AssertionError(f'Cluster behavior feilet:\n{result.stdout}\n{result.stderr}')


def main() -> None:
    html = PAGE.read_text(encoding='utf-8')
    script = extract_script(html)
    block = extract_validation_block(script)

    require(html, 'Stable MVP v1.0', 'stable versjonsmerking')
    require(script, "TRUST_KEY='rah-home-trust-v01'", 'cluster bruker trust-register')
    require(script, "CLUSTER_KEY='rah-home-cluster-v01'", 'egen cluster-lagring')
    require(script, 'trustRecordMatchesDevice(trust.devices[fp(d)],d)', 'trust må være bundet til nåværende device id/IP')
    require(script, 'isPrivateIPv4(d.ip)', 'kun private noder er kvalifisert')
    require(script, "const SAFE_JOBS=['health','systemInfo','benchmark']", 'fast jobb-allowlist')
    require(script, "schema:'rah-home-cluster-plan'", 'eksportplan schema')
    require(script, 'nodes.length>=MAX_PLAN_JOBS', 'eksport begrenses til 16')
    require(script, 'validResultsDocument(x)', 'resultatimport bruker streng validator')
    require(script, 'MAX_RESULT_CHARS=2000000', 'resultatfil har størrelsesgrense')
    require(script, 'if(!save(CLUSTER_KEY,normalized))', 'rollback ved lagringsfeil')
    require(html, 'Nettleseren sender aldri nettverksjobber direkte', 'tydelig controller-grense')

    for token, label in (
        ('fetch(', 'HTTP'),('XMLHttpRequest', 'XHR'),('WebSocket', 'WebSocket'),
        ('RTCPeerConnection', 'WebRTC'),('navigator.bluetooth', 'Bluetooth'),('navigator.usb', 'USB'),
    ):
        forbid(script, token, label)

    node_check(script)
    run_behavior(block)
    print('PASS: RAH Home Cluster v1 secure planner/export/import contract')


if __name__ == '__main__':
    main()

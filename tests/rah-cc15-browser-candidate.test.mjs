import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const core=require('../rah-command-center-core-v1.5-candidate.js');
const loader=fs.readFileSync('RAH-COMMAND-CENTER-V1.5-CANDIDATE.html','utf8');
const baseHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.2.html','utf8');
const core12=fs.readFileSync('rah-command-center-core.js','utf8');
const core13=fs.readFileSync('rah-command-center-core-v1.3.js','utf8');
const core14=fs.readFileSync('rah-command-center-core-v1.4.js','utf8');
const core15=fs.readFileSync('rah-command-center-core-v1.5-candidate.js','utf8');

const CORE_MARKER='<script src="rah-command-center-core.js"></script><script>';
const LOAD_MARKER="function loadDevices(){try{const r=localStorage.getItem(core.DEVICE_STORAGE_KEY);return core.normalizeDeviceRegistry(r?JSON.parse(r):null)}catch(_){return core.normalizeDeviceRegistry(null)}}";
const SAVE_MARKER="function saveDevices(){devices=core.normalizeDeviceRegistry(devices);localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(devices))}";
const INSERT_MARKER="document.getElementById('continueBtn').onclick=()=>openRelative('RAH-RAVEN-NOW-V2.html')";
const RUN_BIND="document.getElementById('runActionBtn').onclick=runApprovedAction;";
const HANDOFF_BIND="document.getElementById('handoffBtn').onclick=runRustDeskHandoff;";

function count(source,needle){return source.split(needle).length-1}

test('loader depends on one fixed same-origin v1.2 surface and unique transform markers',()=>{
  assert.ok(loader.includes("const SOURCE='RAH-COMMAND-CENTER-V1.2.html'"));
  assert.ok(loader.includes('sourceUrl.origin!==window.location.origin'));
  assert.ok(loader.includes('Cross-origin redirect rejected.'));
  assert.equal(count(baseHtml,CORE_MARKER),1);
  assert.equal(count(baseHtml,LOAD_MARKER),1);
  assert.equal(count(baseHtml,SAVE_MARKER),1);
  assert.equal(count(baseHtml,INSERT_MARKER),1);
  assert.equal(count(baseHtml,RUN_BIND),1);
  assert.equal(count(baseHtml,HANDOFF_BIND),1);
  assert.doesNotMatch(loader,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('loader injects Stable 1.3 + 1.4 then CC 1.5 Candidate and aliases only the Candidate core',()=>{
  assert.ok(loader.includes('rah-command-center-core-v1.3.js'));
  assert.ok(loader.includes('rah-command-center-core-v1.4.js'));
  assert.ok(loader.includes('rah-command-center-core-v1.5-candidate.js'));
  assert.ok(loader.includes('window.RAHCommandCenterCore=window.RAHCommandCenterLocalProofCandidate'));
});

test('loader retains Stable 1.4 startup scrub and persistence redaction',()=>{
  assert.ok(loader.includes('core.persistableDeviceRegistry(loaded)'));
  assert.ok(loader.includes('core.persistableDeviceRegistry(devices)'));
  assert.ok(loader.includes('.replace(LOAD_MARKER,LOAD_REPLACEMENT).replace(SAVE_MARKER,SAVE_REPLACEMENT)'));
  const transformed=baseHtml
    .replace(LOAD_MARKER,"function loadDevices(){const loaded=core.normalizeDeviceRegistry(null);localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(core.persistableDeviceRegistry(loaded)));return loaded}")
    .replace(SAVE_MARKER,"function saveDevices(){localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(core.persistableDeviceRegistry(devices)))}");
  assert.ok(transformed.includes('core.persistableDeviceRegistry(loaded)'));
  assert.ok(transformed.includes('core.persistableDeviceRegistry(devices)'));
  assert.ok(!transformed.includes('localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(devices))'));
});

test('browser rewires only execution buttons to v5 handlers',()=>{
  assert.ok(loader.includes("const RUN_BIND_REPLACEMENT=\"document.getElementById('runActionBtn').onclick=runApprovedActionV5\""));
  assert.ok(loader.includes("const HANDOFF_BIND_REPLACEMENT=\"document.getElementById('handoffBtn').onclick=runRustDeskHandoffV5\""));
  const transformed=baseHtml
    .replace("document.getElementById('runActionBtn').onclick=runApprovedAction","document.getElementById('runActionBtn').onclick=runApprovedActionV5")
    .replace("document.getElementById('handoffBtn').onclick=runRustDeskHandoff","document.getElementById('handoffBtn').onclick=runRustDeskHandoffV5");
  assert.ok(transformed.includes("document.getElementById('runActionBtn').onclick=runApprovedActionV5;"));
  assert.ok(transformed.includes("document.getElementById('handoffBtn').onclick=runRustDeskHandoffV5;"));
  assert.ok(!transformed.includes(RUN_BIND));
  assert.ok(!transformed.includes(HANDOFF_BIND));
});

test('v5 browser helper requires CC ephemeral approval before requesting Node-local proof',()=>{
  assert.ok(loader.includes("if(!d||!core.canExecuteAction(d,action)||!token)"));
  assert.ok(loader.includes("if(!d||!core.canHandoffRustDesk(d)||!core.sanitizePeerId(peerId)||!token)"));
  assert.ok(loader.includes('core.localApprovalIntentRequest(d,action,target)'));
  assert.ok(loader.includes('core.localApprovalGrantFromCatalog(res.payload,d.capabilities,action,d.agentSessionId)'));
});

test('network helper accepts only the four fixed v5 security headers',()=>{
  assert.ok(loader.includes('allowed=[core.ACTION_CHALLENGE_HEADER,core.LOCAL_APPROVAL_HEADER,core.APPROVAL_ACTION_HEADER,core.APPROVAL_TARGET_HEADER]'));
  assert.ok(loader.includes("throw new Error('Invalid fixed v5 request header.')"));
  assert.ok(loader.includes("headers['Content-Type']='application/json'"));
  assert.ok(!loader.includes('X-RAH-Command'));
  assert.ok(!loader.includes('X-RAH-Executable'));
  assert.ok(!loader.includes('X-RAH-Arguments'));
});

test('storage uses ordinary v5 challenge while mutating actions use Node-local grant',()=>{
  assert.ok(loader.includes("core.actionChallengeRequest(d,'storage-summary.read')"));
  assert.ok(loader.includes("freshLocalGrantV5(d,action,token)"));
  assert.ok(loader.includes("freshLocalGrantV5(d,'rustdesk.connect',token,peerId)"));
  assert.ok(loader.includes('req.headers'));
  assert.ok(loader.includes('Waiting for local confirmation on the Node Agent host'));
  assert.ok(loader.includes('Waiting for local Node confirmation of this exact RustDesk target'));
});

test('proof, challenge, token and peer target are transient and never written by Candidate loader',()=>{
  const storageWrites=[...loader.matchAll(/localStorage\.setItem\(([^\n]+)/g)].map(m=>m[1]);
  assert.ok(storageWrites.length>=2);
  for(const write of storageWrites){
    assert.ok(!/localApprovalProof|challenge|actionToken|handoffToken|peerId/.test(write));
  }
  assert.ok(loader.includes("finally{document.getElementById('actionToken').value=''}"));
  assert.ok(loader.includes("finally{document.getElementById('handoffPeerId').value='';document.getElementById('handoffToken').value=''}"));
});

test('old mutating challenge API is fail-closed even if an old handler were invoked',()=>{
  const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';
  const caps=['compute','storage','display','remote-desktop'];
  const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
  const payload={protocol:'rah-node-actions-v5',status:'ready',policyId:'rah-capability-allowlist-v1',approvalMode:'command-center-ephemeral-plus-node-local',sessionId,actions:actions.map(id=>{const v={...core.ACTION_CATALOG[id]};if(v.mutating)v.localApprovalRequired=true;if(id==='storage-summary.read'){v.challenge='CHALLENGE-ABCDEFGHIJKLMNOPQRSTUVWXYZ';v.challengeTtlSeconds=30}return v})};
  const records=[core.createDeviceRecord({id:'node',label:'Node',role:'test',platform:'TestOS',kind:'desktop'},[])];
  const health={protocol:core.NODE_AGENT_PROTOCOL,status:'ready',sessionId,agentVersion:'1.0.0-candidate',hostname:'node',platform:'TestOS',platformRelease:'1',machine:'x64',nodeName:'Node',nodeRole:'test',capabilities:caps};
  let d=core.enrollDevice(records,'node','127.0.0.1',health,core.sanitizeActionCatalog(payload,caps,sessionId))[0];
  d=core.approveDeviceAction([d],'node','rustdesk.launch')[0];
  assert.equal(core.actionChallengeRequest(d,'rustdesk.launch'),null);
});

test('challenge and local proof must be distinct in a mutating grant',()=>{
  const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX',caps=['compute','storage','display','remote-desktop'],same='SAMEVALUE-ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const payload={protocol:'rah-node-actions-v5',status:'ready',policyId:'rah-capability-allowlist-v1',approvalMode:'command-center-ephemeral-plus-node-local',sessionId,actions:['storage-summary.read','rustdesk.launch','rustdesk.connect'].map(id=>{const v={...core.ACTION_CATALOG[id]};if(v.mutating)v.localApprovalRequired=true;if(id==='storage-summary.read'){v.challenge='STORAGECHALLENGE-ABCDEFGHIJKLMNOPQ';v.challengeTtlSeconds=30}if(id==='rustdesk.launch'){v.challenge=same;v.challengeTtlSeconds=30;v.localApprovalProof=same;v.localApprovalProofTtlSeconds=30}return v})};
  assert.equal(core.localApprovalGrantFromCatalog(payload,caps,'rustdesk.launch',sessionId),null);
});

test('browser-global composition exposes CC 1.5 Candidate without mutating previous globals',()=>{
  const context={console};context.globalThis=context;vm.createContext(context);
  vm.runInContext(core12,context);assert.ok(context.RAHCommandCenterCore);
  vm.runInContext(core13,context);assert.ok(context.RAHCommandCenterCoreV13);
  vm.runInContext(core14,context);assert.ok(context.RAHCommandCenterCoreV14);
  vm.runInContext(core15,context);assert.ok(context.RAHCommandCenterLocalProofCandidate);
  assert.equal(context.RAHCommandCenterLocalProofCandidate.CC_VERSION,'1.5.0-candidate');
  assert.equal(context.RAHCommandCenterCoreV14.CC_VERSION,'1.4.0');
});

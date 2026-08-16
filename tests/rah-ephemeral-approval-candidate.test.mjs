import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const stable=require('../rah-command-center-core-v1.3.js');
const core=require('../rah-command-center-core-v1.4-candidate.js');
const contract=JSON.parse(fs.readFileSync('RAH-EPHEMERAL-APPROVAL-CANDIDATE.json','utf8'));
const html=fs.readFileSync('RAH-COMMAND-CENTER-V1.4-CANDIDATE.html','utf8');
const rollbackHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.2.html','utf8');

const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';
const caps=['compute','storage','display','remote-desktop'];
const actionIds=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const loadMarker="function loadDevices(){try{const r=localStorage.getItem(core.DEVICE_STORAGE_KEY);return core.normalizeDeviceRegistry(r?JSON.parse(r):null)}catch(_){return core.normalizeDeviceRegistry(null)}}";
const loadReplacement="function loadDevices(){try{const r=localStorage.getItem(core.DEVICE_STORAGE_KEY),loaded=core.normalizeDeviceRegistry(r?JSON.parse(r):null);if(r)localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(core.persistableDeviceRegistry(loaded)));return loaded}catch(_){return core.normalizeDeviceRegistry(null)}}";
const saveMarker="function saveDevices(){devices=core.normalizeDeviceRegistry(devices);localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(devices))}";
const saveReplacement="function saveDevices(){localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(core.persistableDeviceRegistry(devices)))}";

function health(){
  return{protocol:core.NODE_AGENT_PROTOCOL,status:'ready',sessionId,agentVersion:'0.9.0',hostname:'node',platform:'TestOS',platformRelease:'1',machine:'x64',nodeName:'Node',nodeRole:'test',capabilities:caps};
}
function verified(){
  return{protocol:core.NODE_ACTIONS_PROTOCOL,status:'ready',policyId:core.ALLOWLIST_POLICY_ID,sessionId,actions:actionIds};
}
function enrolledDevice(){
  const records=[core.createDeviceRecord({id:'node',label:'Node',role:'test',platform:'TestOS',kind:'desktop'},[])];
  return core.enrollDevice(records,'node','127.0.0.1',health(),verified())[0];
}
function stalePersistedRecord(){
  return{
    id:'node',label:'Node',role:'test',platform:'TestOS',kind:'desktop',status:'unverified',source:'local',
    enrolled:true,endpointIp:'127.0.0.1',agentSessionId:sessionId,agentHostname:'node',agentVersion:'0.9.0',
    capabilities:caps,advertisedActions:actionIds,approvedActions:['rustdesk.launch','rustdesk.connect']
  };
}

test('candidate changes approval lifetime only and keeps Stable authority surface',()=>{
  assert.equal(core.CC_VERSION,'1.4.0-candidate');
  assert.equal(core.APPROVAL_PERSISTENCE,'ephemeral-browser-session');
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(core.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.deepEqual([...core.CAPABILITY_IDS],caps);
  assert.deepEqual([...core.ACTION_IDS],actionIds);
  assert.deepEqual([...core.CAPABILITY_IDS],[...stable.CAPABILITY_IDS]);
  assert.deepEqual([...core.ACTION_IDS],[...stable.ACTION_IDS]);
  assert.equal(contract.authorityDelta,'none');
  assert.equal(contract.nodeAgentVersion,'0.9.0-stable-unchanged');
});

test('persisted approvedActions are ignored during candidate load normalization',()=>{
  const loaded=core.normalizeDeviceRegistry([stalePersistedRecord()])[0];
  assert.deepEqual(loaded.approvedActions,[]);
  assert.equal(core.canExecuteAction(loaded,'rustdesk.launch'),false);
  assert.equal(core.canExecuteAction(loaded,'rustdesk.connect'),false);
});

test('startup scrub physically removes stale approvals from persistable registry',()=>{
  const stale=stalePersistedRecord();
  assert.deepEqual(stale.approvedActions,['rustdesk.launch','rustdesk.connect']);
  const loaded=core.normalizeDeviceRegistry([stale]);
  const scrubbed=core.persistableDeviceRegistry(loaded);
  assert.deepEqual(scrubbed[0].approvedActions,[]);
  assert.equal(core.persistedApprovalCount(scrubbed),0);
  assert.deepEqual(scrubbed[0].advertisedActions,actionIds);
  assert.equal(scrubbed[0].agentSessionId,sessionId);
});

test('local approval works in memory during the active browser session',()=>{
  let device=enrolledDevice();
  assert.deepEqual(device.approvedActions,[]);
  device=core.approveDeviceAction([device],'node','rustdesk.launch')[0];
  assert.deepEqual(device.approvedActions,['rustdesk.launch']);
  assert.equal(core.canExecuteAction(device,'rustdesk.launch'),true);
});

test('persistable registry always strips runtime approvals without mutating the runtime record',()=>{
  let device=enrolledDevice();
  device=core.approveDeviceAction([device],'node','rustdesk.launch')[0];
  assert.equal(core.canExecuteAction(device,'rustdesk.launch'),true);
  const stored=core.persistableDeviceRegistry([device]);
  assert.deepEqual(stored[0].approvedActions,[]);
  assert.equal(core.persistedApprovalCount([device]),0);
  assert.deepEqual(device.approvedActions,['rustdesk.launch']);
});

test('reload simulation loses approval and requires local re-approval',()=>{
  let device=enrolledDevice();
  device=core.approveDeviceAction([device],'node','rustdesk.launch')[0];
  const serialized=JSON.stringify(core.persistableDeviceRegistry([device]));
  const parsed=JSON.parse(serialized)[0];
  assert.deepEqual(parsed.approvedActions,[]);
  assert.ok(parsed.advertisedActions.includes('rustdesk.launch'));
  const reloaded=core.normalizeDeviceRegistry(JSON.parse(serialized))[0];
  assert.deepEqual(reloaded.approvedActions,[]);
  assert.equal(core.canExecuteAction(reloaded,'rustdesk.launch'),false);
  const reapproved=core.approveDeviceAction([reloaded],'node','rustdesk.launch')[0];
  assert.equal(core.canExecuteAction(reapproved,'rustdesk.launch'),true);
});

test('revoke removes the ephemeral grant immediately',()=>{
  let device=enrolledDevice();
  device=core.approveDeviceAction([device],'node','rustdesk.launch')[0];
  assert.equal(core.canExecuteAction(device,'rustdesk.launch'),true);
  device=core.revokeDeviceAction([device],'node','rustdesk.launch')[0];
  assert.deepEqual(device.approvedActions,[]);
  assert.equal(core.canExecuteAction(device,'rustdesk.launch'),false);
});

test('browser loader scrubs startup storage, redacts saves and uses fixed same-origin sources',()=>{
  assert.ok(html.includes("const SOURCE='RAH-COMMAND-CENTER-V1.2.html'"));
  assert.ok(html.includes('rah-command-center-core-v1.3.js'));
  assert.ok(html.includes('rah-command-center-core-v1.4-candidate.js'));
  assert.ok(html.includes('window.RAHCommandCenterCore=window.RAHCommandCenterEphemeralCandidate'));
  assert.ok(html.includes(`const LOAD_MARKER=${JSON.stringify(loadMarker)}`));
  assert.ok(html.includes(`const LOAD_REPLACEMENT=${JSON.stringify(loadReplacement)}`));
  assert.ok(html.includes(`const SAVE_MARKER=${JSON.stringify(saveMarker)}`));
  assert.ok(html.includes(`const SAVE_REPLACEMENT=${JSON.stringify(saveReplacement)}`));
  assert.ok(html.includes('.replace(LOAD_MARKER,LOAD_REPLACEMENT).replace(SAVE_MARKER,SAVE_REPLACEMENT)'));
  assert.equal(rollbackHtml.split(loadMarker).length-1,1);
  assert.equal(rollbackHtml.split(saveMarker).length-1,1);
  const transformed=rollbackHtml.replace(loadMarker,loadReplacement).replace(saveMarker,saveReplacement);
  assert.ok(transformed.includes('if(r)localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(core.persistableDeviceRegistry(loaded)))'));
  assert.ok(transformed.includes('core.persistableDeviceRegistry(devices)'));
  assert.ok(!transformed.includes('return core.normalizeDeviceRegistry(r?JSON.parse(r):null)'));
  assert.ok(!transformed.includes('localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(devices))'));
  assert.ok(html.includes('sourceUrl.origin!==window.location.origin'));
  assert.ok(html.includes('Cross-origin redirect rejected.'));
  assert.ok(html.includes('Expected unique load marker not found.'));
  assert.ok(html.includes('Expected unique persistence marker not found.'));
  assert.doesNotMatch(html,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('candidate contract requires startup scrub and forbids persistence/generic runtime authority',()=>{
  assert.equal(contract.approvalPolicy.persistApprovedActions,false);
  assert.equal(contract.approvalPolicy.acceptPersistedApprovedActions,false);
  assert.equal(contract.approvalPolicy.scrubPersistedApprovedActionsOnLoad,true);
  assert.equal(contract.approvalPolicy.startupStorageScrubBeforeInteraction,true);
  assert.equal(contract.approvalPolicy.reloadRequiresReapproval,true);
  for(const item of ['persisted-approved-actions','shell','generic-command-execution','generic-process-launch','generic-file-api','generic-endpoint-dispatch','native-raven-remote-control-api','network-token-renewal-endpoint'])assert.ok(contract.forbidden.includes(item));
  assert.deepEqual(contract.routes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

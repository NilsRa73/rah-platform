import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const stable=require('../rah-command-center-core-v1.3.js');
const core=require('../rah-command-center-core-v1.4-candidate.js');
const contract=JSON.parse(fs.readFileSync('RAH-EPHEMERAL-APPROVAL-CANDIDATE.json','utf8'));
const html=fs.readFileSync('RAH-COMMAND-CENTER-V1.4-CANDIDATE.html','utf8');

const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';
const caps=['compute','storage','display','remote-desktop'];
const actionIds=['storage-summary.read','rustdesk.launch','rustdesk.connect'];

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
  const malicious={
    id:'node',label:'Node',role:'test',platform:'TestOS',kind:'desktop',status:'unverified',source:'local',
    enrolled:true,endpointIp:'127.0.0.1',agentSessionId:sessionId,agentHostname:'node',agentVersion:'0.9.0',
    capabilities:caps,advertisedActions:actionIds,approvedActions:['rustdesk.launch','rustdesk.connect']
  };
  const loaded=core.normalizeDeviceRegistry([malicious])[0];
  assert.deepEqual(loaded.approvedActions,[]);
  assert.equal(core.canExecuteAction(loaded,'rustdesk.launch'),false);
  assert.equal(core.canExecuteAction(loaded,'rustdesk.connect'),false);
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
  assert.ok(!serialized.includes('rustdesk.launch')||JSON.parse(serialized)[0].advertisedActions.includes('rustdesk.launch'));
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

test('browser loader redacts persistence and uses only fixed same-origin sources',()=>{
  assert.ok(html.includes("const SOURCE='RAH-COMMAND-CENTER-V1.2.html'"));
  assert.ok(html.includes('rah-command-center-core-v1.3.js'));
  assert.ok(html.includes('rah-command-center-core-v1.4-candidate.js'));
  assert.ok(html.includes('window.RAHCommandCenterCore=window.RAHCommandCenterEphemeralCandidate'));
  assert.ok(html.includes('core.persistableDeviceRegistry(devices)'));
  assert.ok(!html.includes('localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(devices))'));
  assert.ok(html.includes('sourceUrl.origin!==window.location.origin'));
  assert.ok(html.includes('Cross-origin redirect rejected.'));
  assert.ok(html.includes('Expected unique persistence marker not found.'));
  assert.doesNotMatch(html,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('candidate contract forbids persistence and all generic runtime authority',()=>{
  assert.equal(contract.approvalPolicy.persistApprovedActions,false);
  assert.equal(contract.approvalPolicy.acceptPersistedApprovedActions,false);
  assert.equal(contract.approvalPolicy.reloadRequiresReapproval,true);
  for(const item of ['persisted-approved-actions','shell','generic-command-execution','generic-process-launch','generic-file-api','generic-endpoint-dispatch','native-raven-remote-control-api','network-token-renewal-endpoint'])assert.ok(contract.forbidden.includes(item));
  assert.deepEqual(contract.routes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

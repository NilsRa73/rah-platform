import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import fs from 'node:fs';
import vm from 'node:vm';

const require=createRequire(import.meta.url);
const stableCore=require('../rah-command-center-core.js');
const core=require('../rah-command-center-core-v1.3-candidate.js');
const stableContract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CANDIDATE.json','utf8'));
const loaderHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.3-CANDIDATE.html','utf8');

const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';
const capabilities=['compute','storage','display','remote-desktop'];
const actionIds=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const challenge='ABCDEFGHIJKLMNOPQRSTUVWXYZabcd';
const MISSING='__missing_policy__';

function actionRows(){
  return actionIds.map(id=>{
    const catalog=core.ACTION_CATALOG[id];
    return{...catalog,challenge,challengeTtlSeconds:core.ACTION_CHALLENGE_TTL_SECONDS};
  });
}
function catalog(policyId=core.ALLOWLIST_POLICY_ID,protocol=core.NODE_ACTIONS_PROTOCOL){
  const value={protocol,status:'ready',sessionId,actions:actionRows()};
  if(policyId!==MISSING)value.policyId=policyId;
  return value;
}
function health(){
  return{protocol:core.NODE_AGENT_PROTOCOL,status:'ready',sessionId,agentVersion:'0.9.0-candidate',hostname:'candidate-node',platform:'TestOS',platformRelease:'1',machine:'x64',nodeName:'Candidate',nodeRole:'test',capabilities};
}

test('candidate versions and authority surface are pinned',()=>{
  assert.equal(core.CC_VERSION,'1.3.0-candidate');
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(core.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.deepEqual([...core.CAPABILITY_IDS],capabilities);
  assert.deepEqual([...core.ACTION_IDS],actionIds);
  assert.equal(contract.authorityDelta,'none');
  assert.deepEqual(contract.capabilities,capabilities);
  assert.deepEqual(contract.actions,actionIds);
  assert.deepEqual(contract.routes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

test('candidate policy ID is anchored to the canonical Stable contract',()=>{
  assert.equal(stableContract.policyId,'rah-capability-allowlist-v1');
  assert.equal(core.ALLOWLIST_POLICY_ID,stableContract.policyId);
  assert.equal(contract.expectedPolicyId,stableContract.policyId);
});

test('correct policy ID is accepted by action catalog sanitizer',()=>{
  const value=core.sanitizeActionCatalog(catalog(),capabilities,sessionId);
  assert.ok(value);
  assert.equal(value.policyId,core.ALLOWLIST_POLICY_ID);
  assert.deepEqual(value.actions,actionIds);
});

test('missing policy ID is rejected',()=>{
  assert.equal(core.sanitizeActionCatalog(catalog(MISSING),capabilities,sessionId),null);
});

test('wrong policy ID is rejected',()=>{
  assert.equal(core.sanitizeActionCatalog(catalog('rah-capability-allowlist-evil'),capabilities,sessionId),null);
});

test('Candidate rejects the Stable v3 actions protocol',()=>{
  assert.equal(core.sanitizeActionCatalog(catalog(core.ALLOWLIST_POLICY_ID,'rah-node-actions-v3'),capabilities,sessionId),null);
});

test('Stable rejects the Candidate v4 actions protocol',()=>{
  assert.equal(stableCore.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v3');
  assert.equal(stableCore.sanitizeActionCatalog(catalog(),capabilities,sessionId),null);
});

test('policy mismatch blocks enrollment catalog normalization',()=>{
  const verified={protocol:core.NODE_ACTIONS_PROTOCOL,status:'ready',policyId:'wrong-policy',sessionId,actions:actionIds};
  assert.equal(core.normalizeVerifiedCatalog(verified,capabilities),null);
});

test('correct policy allows session-bound enrollment without adding approvals',()=>{
  const records=[core.createDeviceRecord({id:'candidate-node',label:'Candidate Node',role:'test',platform:'TestOS',kind:'desktop'},[])];
  const verified={protocol:core.NODE_ACTIONS_PROTOCOL,status:'ready',policyId:core.ALLOWLIST_POLICY_ID,sessionId,actions:actionIds};
  const enrolled=core.enrollDevice(records,'candidate-node','127.0.0.1',health(),verified)[0];
  assert.equal(enrolled.enrolled,true);
  assert.deepEqual(enrolled.advertisedActions,actionIds);
  assert.deepEqual(enrolled.approvedActions,[]);
  assert.equal(enrolled.remoteControlEnabled,false);
  assert.equal(enrolled.commandsEnabled,false);
});

test('fresh execution refresh requires matching policy before challenge extraction',()=>{
  assert.equal(core.actionChallengeFromCatalog(catalog('wrong-policy'),capabilities,'rustdesk.launch',sessionId),'');
  assert.equal(core.actionChallengeFromCatalog(catalog(MISSING),capabilities,'rustdesk.launch',sessionId),'');
  assert.equal(core.actionChallengeFromCatalog(catalog(),capabilities,'rustdesk.launch',sessionId),challenge);
});

test('candidate request builder still requires advertised and locally approved action',()=>{
  const records=[core.createDeviceRecord({id:'candidate-node',label:'Candidate Node',role:'test',platform:'TestOS',kind:'desktop'},[])];
  const verified={protocol:core.NODE_ACTIONS_PROTOCOL,status:'ready',policyId:core.ALLOWLIST_POLICY_ID,sessionId,actions:actionIds};
  let device=core.enrollDevice(records,'candidate-node','127.0.0.1',health(),verified)[0];
  assert.equal(core.actionChallengeRequest(device,'rustdesk.launch'),null);
  device=core.approveDeviceAction([device],'candidate-node','rustdesk.launch')[0];
  const request=core.actionChallengeRequest(device,'rustdesk.launch');
  assert.ok(request);
  assert.equal(request.policyId,core.ALLOWLIST_POLICY_ID);
  assert.equal(request.protocol,core.NODE_ACTIONS_PROTOCOL);
});

test('browser globals compose Stable core then Candidate overlay',()=>{
  const context=vm.createContext({URL,console});
  vm.runInContext(fs.readFileSync('rah-command-center-core.js','utf8'),context,{filename:'rah-command-center-core.js'});
  assert.ok(context.RAHCommandCenterCore);
  assert.equal(context.RAHCommandCenterCore.CC_VERSION,'1.2.0');
  vm.runInContext(fs.readFileSync('rah-command-center-core-v1.3-candidate.js','utf8'),context,{filename:'rah-command-center-core-v1.3-candidate.js'});
  assert.ok(context.RAHCommandCenterCandidateCore);
  assert.equal(context.RAHCommandCenterCandidateCore.CC_VERSION,'1.3.0-candidate');
  assert.equal(context.RAHCommandCenterCandidateCore.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  context.RAHCommandCenterCore=context.RAHCommandCenterCandidateCore;
  assert.equal(context.RAHCommandCenterCore.ALLOWLIST_POLICY_ID,stableContract.policyId);
});

test('Candidate HTML loader is fixed-source, same-origin and fail-closed',()=>{
  assert.ok(loaderHtml.includes("const SOURCE='RAH-COMMAND-CENTER-V1.2.html'"));
  assert.ok(loaderHtml.includes("const MARKER='<script src=\"rah-command-center-core.js\"><\\/script><script>'"));
  assert.ok(loaderHtml.includes('rah-command-center-core-v1.3-candidate.js'));
  assert.ok(loaderHtml.includes('window.RAHCommandCenterCore=window.RAHCommandCenterCandidateCore'));
  assert.ok(loaderHtml.includes('sourceUrl.origin!==window.location.origin'));
  assert.ok(loaderHtml.includes('Cross-origin redirect rejected.'));
  assert.ok(loaderHtml.includes('Expected unique Stable core marker not found.'));
  assert.doesNotMatch(loaderHtml,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

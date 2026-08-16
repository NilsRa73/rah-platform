import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const stable=require('../rah-command-center-core-v1.4.js');
const core=require('../rah-command-center-core-v1.5-candidate.js');

const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const challenge='CHALLENGE-ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const proof='LOCALPROOF-ABCDEFGHIJKLMNOPQRSTUVWXYZ';

function row(id,grant=false){
  const catalog=core.ACTION_CATALOG[id];
  const value={...catalog};
  if(catalog.mutating)value.localApprovalRequired=true;
  if(id==='storage-summary.read'||grant){value.challenge=challenge;value.challengeTtlSeconds=30;}
  if(grant){value.localApprovalProof=proof;value.localApprovalProofTtlSeconds=30;}
  return value;
}
function catalog({protocol='rah-node-actions-v5',policyId='rah-capability-allowlist-v1',grantAction='',session=sessionId}={}){
  return{protocol,status:'ready',policyId,approvalMode:'command-center-ephemeral-plus-node-local',sessionId:session,actions:actions.map(id=>row(id,id===grantAction))};
}
function health(){return{protocol:core.NODE_AGENT_PROTOCOL,status:'ready',sessionId,agentVersion:'1.0.0-candidate',hostname:'candidate-node',platform:'TestOS',platformRelease:'1',machine:'x64',nodeName:'Candidate',nodeRole:'test',capabilities:caps};}
function enrolled(){
  const records=[core.createDeviceRecord({id:'node',label:'Node',role:'test',platform:'TestOS',kind:'desktop'},[])];
  const verified=core.sanitizeActionCatalog(catalog(),caps,sessionId);
  return core.enrollDevice(records,'node','127.0.0.1',health(),verified)[0];
}
function approved(actionId){return core.approveDeviceAction([enrolled()],'node',actionId)[0];}

test('CC 1.5 Candidate advances actions protocol only and preserves Stable authority surface',()=>{
  assert.equal(core.CC_VERSION,'1.5.0-candidate');
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v5');
  assert.equal(core.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.equal(core.APPROVAL_PERSISTENCE,'ephemeral-browser-session');
  assert.deepEqual([...core.CAPABILITY_IDS],caps);
  assert.deepEqual([...core.ACTION_IDS],actions);
  assert.deepEqual([...core.CAPABILITY_IDS],[...stable.CAPABILITY_IDS]);
  assert.deepEqual([...core.ACTION_IDS],[...stable.ACTION_IDS]);
  assert.deepEqual([...core.MUTATING_ACTION_IDS],['rustdesk.launch','rustdesk.connect']);
});

test('normal v5 catalog is accepted for enrollment while Stable 1.4 rejects v5',()=>{
  const value=core.sanitizeActionCatalog(catalog(),caps,sessionId);
  assert.ok(value);
  assert.equal(value.protocol,'rah-node-actions-v5');
  assert.deepEqual(value.actions,actions);
  assert.equal(stable.sanitizeActionCatalog(catalog(),caps,sessionId),null);
});

test('Candidate rejects v4, wrong policy, wrong approval mode and wrong session',()=>{
  assert.equal(core.sanitizeActionCatalog(catalog({protocol:'rah-node-actions-v4'}),caps,sessionId),null);
  assert.equal(core.sanitizeActionCatalog(catalog({policyId:'wrong'}),caps,sessionId),null);
  const wrongMode=catalog();wrongMode.approvalMode='wrong';assert.equal(core.sanitizeActionCatalog(wrongMode,caps,sessionId),null);
  assert.equal(core.sanitizeActionCatalog(catalog({session:'ZYXWVUTSRQPONMLKJIHGFEDC'}),caps,sessionId),null);
});

test('mutating rows require localApprovalRequired and grant challenge/proof must appear as a pair',()=>{
  const missing=catalog();delete missing.actions[1].localApprovalRequired;assert.equal(core.sanitizeActionCatalog(missing,caps,sessionId)?.actions.includes('rustdesk.launch'),false);
  const challengeOnly=catalog();challengeOnly.actions[1].challenge=challenge;challengeOnly.actions[1].challengeTtlSeconds=30;assert.equal(core.sanitizeActionCatalog(challengeOnly,caps,sessionId)?.actions.includes('rustdesk.launch'),false);
  const proofOnly=catalog();proofOnly.actions[1].localApprovalProof=proof;proofOnly.actions[1].localApprovalProofTtlSeconds=30;assert.equal(core.sanitizeActionCatalog(proofOnly,caps,sessionId)?.actions.includes('rustdesk.launch'),false);
  const storageProof=catalog();storageProof.actions[0].localApprovalProof=proof;storageProof.actions[0].localApprovalProofTtlSeconds=30;assert.equal(core.sanitizeActionCatalog(storageProof,caps,sessionId)?.actions.includes('storage-summary.read'),false);
});

test('enrollment advertises exact actions and starts with no runtime approval',()=>{
  const d=enrolled();
  assert.equal(d.enrolled,true);
  assert.equal(d.agentSessionId,sessionId);
  assert.equal(d.agentVersion,'1.0.0-candidate');
  assert.deepEqual(d.advertisedActions,actions);
  assert.deepEqual(d.approvedActions,[]);
  assert.equal(d.remoteControlEnabled,false);
  assert.equal(d.commandsEnabled,false);
});

test('ephemeral CC approval remains required before any request builder works',()=>{
  const d=enrolled();
  assert.equal(core.actionChallengeRequest(d,'storage-summary.read'),null);
  assert.equal(core.localApprovalIntentRequest(d,'rustdesk.launch'),null);
  assert.equal(core.localApprovalIntentRequest(d,'rustdesk.connect','123456789'),null);
});

test('old mutating challenge request path is explicitly fail-closed',()=>{
  const launch=approved('rustdesk.launch'),connect=approved('rustdesk.connect'),storage=approved('storage-summary.read');
  assert.equal(core.actionChallengeRequest(launch,'rustdesk.launch'),null);
  assert.equal(core.actionChallengeRequest(connect,'rustdesk.connect'),null);
  const req=core.actionChallengeRequest(storage,'storage-summary.read');
  assert.ok(req);assert.equal(req.url,'http://127.0.0.1:18766/actions');assert.deepEqual(req.headers,{});
});

test('storage challenge extraction remains normal-catalog only',()=>{
  assert.equal(core.actionChallengeFromCatalog(catalog(),caps,'storage-summary.read',sessionId),challenge);
  assert.equal(core.actionChallengeFromCatalog(catalog({grantAction:'rustdesk.launch'}),caps,'rustdesk.launch',sessionId),'');
  assert.equal(core.actionChallengeFromCatalog(catalog(),caps,'rustdesk.connect',sessionId),'');
});

test('local approval intent builders emit only fixed dedicated headers',()=>{
  const launch=core.localApprovalIntentRequest(approved('rustdesk.launch'),'rustdesk.launch');
  assert.ok(launch);assert.equal(launch.method,'GET');assert.equal(launch.url,'http://127.0.0.1:18766/actions');
  assert.deepEqual(launch.headers,{'X-RAH-Approval-Action':'rustdesk.launch'});
  assert.equal(core.localApprovalIntentRequest(approved('rustdesk.launch'),'rustdesk.launch','unexpected'),null);
  const connect=core.localApprovalIntentRequest(approved('rustdesk.connect'),'rustdesk.connect','123456789');
  assert.deepEqual(connect.headers,{'X-RAH-Approval-Action':'rustdesk.connect','X-RAH-Approval-Target':'123456789'});
  assert.equal(core.localApprovalIntentRequest(approved('rustdesk.connect'),'rustdesk.connect','bad target'),null);
});

test('normal catalog has no mutating grant; locally confirmed v5 catalog yields exact selected grant',()=>{
  assert.equal(core.localApprovalGrantFromCatalog(catalog(),caps,'rustdesk.launch',sessionId),null);
  const launch=core.localApprovalGrantFromCatalog(catalog({grantAction:'rustdesk.launch'}),caps,'rustdesk.launch',sessionId);
  assert.deepEqual(launch,{actionId:'rustdesk.launch',challenge,localApprovalProof:proof,challengeTtlSeconds:30,localApprovalProofTtlSeconds:30});
  assert.equal(core.localApprovalGrantFromCatalog(catalog({grantAction:'rustdesk.launch'}),caps,'rustdesk.connect',sessionId),null);
});

test('launch execution builder requires a complete locally confirmed grant',()=>{
  const d=approved('rustdesk.launch');
  assert.equal(core.actionExecutionRequest(d,'rustdesk.launch',challenge),null);
  assert.equal(core.actionExecutionRequest(d,'rustdesk.launch',{actionId:'rustdesk.launch',challenge,localApprovalProof:'wrong',challengeTtlSeconds:30,localApprovalProofTtlSeconds:29}),null);
  const grant=core.localApprovalGrantFromCatalog(catalog({grantAction:'rustdesk.launch'}),caps,'rustdesk.launch',sessionId);
  const req=core.actionExecutionRequest(d,'rustdesk.launch',grant);
  assert.ok(req);assert.equal(req.url,'http://127.0.0.1:18766/launch/rustdesk');assert.equal(req.method,'POST');
  assert.deepEqual(req.headers,{'X-RAH-Action-Challenge':challenge,'X-RAH-Local-Approval':proof});
});

test('storage execution builder uses challenge only and no local proof',()=>{
  const d=approved('storage-summary.read');
  const req=core.actionExecutionRequest(d,'storage-summary.read',challenge);
  assert.ok(req);assert.equal(req.url,'http://127.0.0.1:18766/storage');assert.equal(req.method,'GET');
  assert.deepEqual(req.headers,{'X-RAH-Action-Challenge':challenge});
});

test('RustDesk handoff builder preserves typed peer-only body and fixed proof headers',()=>{
  const d=approved('rustdesk.connect'),grant=core.localApprovalGrantFromCatalog(catalog({grantAction:'rustdesk.connect'}),caps,'rustdesk.connect',sessionId);
  const req=core.rustDeskHandoffRequest(d,'123456789',grant);
  assert.ok(req);assert.equal(req.url,'http://127.0.0.1:18766/handoff/rustdesk');assert.equal(req.method,'POST');
  assert.deepEqual(req.body,{peerId:'123456789'});assert.deepEqual(req.headers,{'X-RAH-Action-Challenge':challenge,'X-RAH-Local-Approval':proof});
  assert.equal(core.rustDeskHandoffRequest(d,'bad target',grant),null);
});

test('proof, challenge, peer ID and runtime approvals remain outside persistable registry',()=>{
  const d=approved('rustdesk.connect');
  assert.deepEqual(d.approvedActions,['rustdesk.connect']);
  const stored=core.persistableDeviceRegistry([d])[0];
  assert.deepEqual(stored.approvedActions,[]);
  const encoded=JSON.stringify(stored);
  assert.ok(!encoded.includes(proof));assert.ok(!encoded.includes(challenge));assert.ok(!encoded.includes('123456789'));
});

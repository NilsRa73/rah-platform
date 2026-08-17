import test from 'node:test';
import assert from 'node:assert/strict';
import core from '../rah-command-center-core-v1.6-candidate.js';

const session='ABCDEFGHIJKLMNOPQRSTUVWX';
const context='A'.repeat(40);
const caps=['storage','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const record={id:'n',enrolled:true,endpointIp:'127.0.0.1',agentSessionId:session,capabilities:caps,advertisedActions:actions,approvedActions:actions,permissions:{storageRead:true,displayRead:false,remoteDesktopHandoff:true,commands:false,files:false,remoteControl:false}};

function payload(protocol='rah-node-actions-v6'){
  return {
    protocol,status:'ready',sessionId:session,policyId:'rah-capability-allowlist-v1',approvalMode:'command-center-ephemeral-plus-node-local-context',
    actions:[
      {id:'storage-summary.read',capability:'storage',method:'GET',path:'/storage',scope:'system-volume',mutating:false,challenge:'storage-challenge-AAAAAAAA',challengeTtlSeconds:30},
      {id:'rustdesk.launch',capability:'remote-desktop',method:'POST',path:'/launch/rustdesk',scope:'fixed-app',mutating:true,localApprovalRequired:true,requesterContextRequired:true,challenge:'launch-challenge-BBBBBBBB',challengeTtlSeconds:30,localApprovalProof:'launch-proof-CCCCCCCCCCCC',localApprovalProofTtlSeconds:30},
      {id:'rustdesk.connect',capability:'remote-desktop',method:'POST',path:'/handoff/rustdesk',scope:'fixed-app-peer-id',mutating:true,input:'peer-id',localApprovalRequired:true,requesterContextRequired:true,challenge:'connect-challenge-DDDDDDD',challengeTtlSeconds:30,localApprovalProof:'connect-proof-EEEEEEEEEEE',localApprovalProofTtlSeconds:30}
    ]
  };
}

test('Candidate identity is CC 1.6 / Actions v6 with unchanged policy and fixed context header',()=>{
  assert.equal(core.CC_VERSION,'1.6.0-candidate');
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v6');
  assert.equal(core.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.equal(core.REQUESTER_CONTEXT_HEADER,'X-RAH-Requester-Context');
  assert.deepEqual([...core.MUTATING_ACTION_IDS],['rustdesk.launch','rustdesk.connect']);
});

test('requester context sanitizer is strict ASCII base64url-like 32 to 128 chars',()=>{
  assert.equal(core.sanitizeRequesterContext(context),context);
  assert.equal(core.sanitizeRequesterContext('short'),'');
  assert.equal(core.sanitizeRequesterContext('!'.repeat(40)),'');
  assert.equal(core.sanitizeRequesterContext('é'.repeat(40)),'');
});

test('v6 catalog accepts exact fixed rows and rejects Stable v5 fail-closed',()=>{
  const good=core.sanitizeActionCatalog(payload(),caps,session);
  assert.ok(good);
  assert.equal(good.protocol,'rah-node-actions-v6');
  assert.deepEqual(good.actions,actions);
  assert.equal(core.sanitizeActionCatalog(payload('rah-node-actions-v5'),caps,session),null);
});

test('mutating catalog row requires requesterContextRequired true',()=>{
  const bad=payload();
  delete bad.actions[1].requesterContextRequired;
  const sanitized=core.sanitizeActionCatalog(bad,caps,session);
  assert.ok(sanitized);
  assert.ok(!sanitized.actions.includes('rustdesk.launch'));
  assert.ok(sanitized.actions.includes('rustdesk.connect'));
});

test('normal enrollment requires v6 verified catalog and same Node session',()=>{
  const health={protocol:'rah-node-health-v2',status:'ready',sessionId:session,hostname:'node',agentVersion:'1.2.0-candidate',platform:'win32',platformRelease:'11',capabilities:caps,permissions:{storageRead:true,displayRead:false,remoteDesktopHandoff:true,commands:false,files:false,remoteControl:false},apps:{rustdesk:true}};
  const existing=[{id:'n',label:'Node',role:'test',kind:'desktop',source:'local',enrolled:false,endpointIp:'',capabilities:[],advertisedActions:[],approvedActions:[]}];
  const verified=core.sanitizeActionCatalog(payload(),caps,session);
  const enrolled=core.enrollDevice(existing,'n','127.0.0.1',health,verified)[0];
  assert.equal(enrolled.enrolled,true);
  assert.equal(enrolled.agentSessionId,session);
  assert.deepEqual(enrolled.advertisedActions,actions);
  assert.deepEqual(enrolled.approvedActions,[]);
  const wrong={...verified,sessionId:'ZYXWVUTSRQPONMLKJIHGFEDC'};
  assert.equal(core.enrollDevice(existing,'n','127.0.0.1',health,wrong)[0].enrolled,false);
});

test('mutating approval intent requires one valid requester context and fixed target grammar',()=>{
  const launch=core.localApprovalIntentRequest(record,'rustdesk.launch',undefined,context);
  assert.ok(launch);
  assert.equal(launch.headers[core.APPROVAL_ACTION_HEADER],'rustdesk.launch');
  assert.equal(launch.headers[core.REQUESTER_CONTEXT_HEADER],context);
  assert.equal(core.localApprovalIntentRequest(record,'rustdesk.launch',undefined,''),null);
  assert.equal(core.localApprovalIntentRequest(record,'rustdesk.launch','unexpected',context),null);
  const connect=core.localApprovalIntentRequest(record,'rustdesk.connect','123456789',context);
  assert.ok(connect);
  assert.equal(connect.headers[core.APPROVAL_TARGET_HEADER],'123456789');
  assert.equal(connect.headers[core.REQUESTER_CONTEXT_HEADER],context);
});

test('launch execution carries only challenge proof and same fixed requester-context header',()=>{
  const grant=core.localApprovalGrantFromCatalog(payload(),caps,'rustdesk.launch',session);
  assert.ok(grant);
  const req=core.actionExecutionRequest(record,'rustdesk.launch',grant,context);
  assert.ok(req);
  assert.deepEqual(Object.keys(req.headers).sort(),[core.ACTION_CHALLENGE_HEADER,core.LOCAL_APPROVAL_HEADER,core.REQUESTER_CONTEXT_HEADER].sort());
  assert.equal(req.headers[core.REQUESTER_CONTEXT_HEADER],context);
  assert.equal(core.actionExecutionRequest(record,'rustdesk.launch',grant,''),null);
});

test('RustDesk handoff keeps typed peer-only body plus three fixed security headers',()=>{
  const grant=core.localApprovalGrantFromCatalog(payload(),caps,'rustdesk.connect',session);
  const req=core.rustDeskHandoffRequest(record,'123456789',grant,context);
  assert.ok(req);
  assert.deepEqual(req.body,{peerId:'123456789'});
  assert.deepEqual(Object.keys(req.headers).sort(),[core.ACTION_CHALLENGE_HEADER,core.LOCAL_APPROVAL_HEADER,core.REQUESTER_CONTEXT_HEADER].sort());
  assert.equal(core.rustDeskHandoffRequest(record,'bad target',grant,context),null);
  assert.equal(core.rustDeskHandoffRequest(record,'123456789',grant,''),null);
});

test('storage challenge stays context-free and requester context is rejected for storage request construction',()=>{
  const challenge=core.actionChallengeFromCatalog(payload(),caps,'storage-summary.read',session);
  assert.ok(challenge);
  const req=core.actionExecutionRequest(record,'storage-summary.read',challenge);
  assert.ok(req);
  assert.deepEqual(Object.keys(req.headers),[core.ACTION_CHALLENGE_HEADER]);
  assert.equal(core.actionExecutionRequest(record,'storage-summary.read',challenge,context),null);
});
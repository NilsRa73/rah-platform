import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {
  LocalApprovalProofResearchModel,
  CAPABILITIES,ACTIONS,MUTATING_ACTIONS,ROUTES,
  APPROVAL_ACTION_HEADER,APPROVAL_TARGET_HEADER,APPROVAL_PROOF_HEADER,
  canonicalInputDigest,validPeerId
} from '../research/rah-node-local-approval-proof-model.mjs';

const research=JSON.parse(fs.readFileSync('RAH-NODE-LOCAL-APPROVAL-PROOF-RESEARCH.json','utf8'));
const modelSource=fs.readFileSync('research/rah-node-local-approval-proof-model.mjs','utf8');
const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';

function clock(start=100){let value=start;return{now:()=>value,advance:n=>{value+=n}}}
function sequenceRandom(values){let i=0;return()=>values[i++]||`fallback-${i}-ABCDEFGHIJKLMNOPQRSTUVWXYZ`}
function model(options={}){
  const c=options.clock||clock();
  const random=options.random||sequenceRandom([
    'REQUESTID-ABCDEFGHIJKLMNOPQRSTUVWX',
    'CHALLENGE-ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'APPROVALPROOF-ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  ]);
  return{c,m:new LocalApprovalProofResearchModel({sessionId,clock:c.now,random,proofTtlSeconds:30,promptTtlSeconds:30,cooldownSeconds:2})};
}
function approveLaunch(m){
  const intent=m.requestIntent({actionId:'rustdesk.launch'});
  assert.equal(intent.ok,true);
  const confirmation=m.confirmLocal({requestId:intent.localPrompt.requestId,approved:true});
  assert.equal(confirmation.ok,true);
  return confirmation.grant;
}
function approveConnect(m,target='123456789'){
  const intent=m.requestIntent({actionId:'rustdesk.connect',target});
  assert.equal(intent.ok,true);
  const confirmation=m.confirmLocal({requestId:intent.localPrompt.requestId,approved:true});
  assert.equal(confirmation.ok,true);
  return confirmation.grant;
}

test('research contract is research-only and preserves exact 4/3/5 Stable authority surface',()=>{
  assert.equal(research.stage,'research-only');
  assert.equal(research.authorityDelta,'none');
  assert.deepEqual(research.authoritySurface.capabilities,[...CAPABILITIES]);
  assert.deepEqual(research.authoritySurface.actions,[...ACTIONS]);
  assert.deepEqual(research.authoritySurface.routes,[...ROUTES]);
  assert.deepEqual([...MUTATING_ACTIONS],['rustdesk.launch','rustdesk.connect']);
  assert.equal(research.recommendedProtocolShape.newRoute,false);
  assert.equal(research.recommendedProtocolShape.genericDispatch,false);
  assert.equal(research.recommendedProtocolShape.approvalIntentRoute,'/actions');
  assert.equal(research.recommendedProtocolShape.maxPendingLocalConfirmations,1);
  assert.equal(research.recommendedProtocolShape.maxActiveProofPairs,1);
  assert.equal(research.recommendedProtocolShape.newConfirmationInvalidatesOlderUnusedPair,true);
});

test('research uses dedicated fixed headers and proof never replaces existing gates',()=>{
  assert.equal(APPROVAL_ACTION_HEADER,'X-RAH-Approval-Action');
  assert.equal(APPROVAL_TARGET_HEADER,'X-RAH-Approval-Target');
  assert.equal(APPROVAL_PROOF_HEADER,'X-RAH-Local-Approval');
  for(const gate of ['command-center-ephemeral-local-approval','current-process-bearer-token','agent-session-match','exact-policy-id','fresh-action-bound-single-use-challenge'])assert.ok(research.proofScope.proofDoesNotReplace.includes(gate));
});

test('bearer token and origin checks do not produce a local prompt when invalid',()=>{
  const {m}=model();
  assert.deepEqual(m.requestIntent({actionId:'rustdesk.launch',tokenValid:false}),{ok:false,error:'unauthorized'});
  assert.deepEqual(m.requestIntent({actionId:'rustdesk.launch',originAllowed:false}),{ok:false,error:'origin_not_allowed'});
  assert.equal(m.snapshot().pending,null);
});

test('unadvertised action, missing capability and invalid target are rejected before local confirmation',()=>{
  const {m}=model();
  assert.equal(m.requestIntent({actionId:'rustdesk.launch',advertisedActions:['storage-summary.read']}).error,'action_not_advertised');
  assert.equal(m.requestIntent({actionId:'rustdesk.launch',capabilities:['storage']}).error,'remote_desktop_capability_not_enabled');
  assert.equal(m.requestIntent({actionId:'rustdesk.connect',target:'bad target'}).error,'invalid_fixed_action_input');
  assert.equal(m.snapshot().pending,null);
});

test('read-only action cannot be converted into a Node-local mutating approval intent',()=>{
  const {m}=model();
  assert.deepEqual(m.requestIntent({actionId:'storage-summary.read'}),{ok:false,error:'mutating_fixed_action_required'});
});

test('network caller receives no challenge or proof before Node-local confirmation',()=>{
  const {m}=model();
  const intent=m.requestIntent({actionId:'rustdesk.launch'});
  assert.equal(intent.ok,true);
  assert.equal(intent.status,'pending-local-confirmation');
  assert.equal('challenge' in intent,false);
  assert.equal('approvalProof' in intent,false);
  assert.equal(intent.localPrompt.actionId,'rustdesk.launch');
});

test('proof and challenge are distinct, short-lived and only issued after local approval',()=>{
  const {m}=model();
  const grant=approveLaunch(m);
  assert.notEqual(grant.challenge,grant.approvalProof);
  assert.ok(grant.challenge.length>=32);
  assert.ok(grant.approvalProof.length>=32);
  assert.equal(grant.ttlSeconds,30);
  assert.equal(m.snapshot().activePair.actionId,'rustdesk.launch');
});

test('local denial produces no active proof pair',()=>{
  const {m}=model();
  const intent=m.requestIntent({actionId:'rustdesk.launch'});
  const result=m.confirmLocal({requestId:intent.localPrompt.requestId,approved:false});
  assert.equal(result.ok,false);
  assert.equal(result.error,'local_confirmation_denied');
  assert.equal(m.snapshot().activePair,null);
});

test('one pending prompt and cooldown bound approval-fatigue surface',()=>{
  const {m,c}=model();
  const first=m.requestIntent({actionId:'rustdesk.launch'});
  assert.equal(first.ok,true);
  assert.equal(m.requestIntent({actionId:'rustdesk.connect',target:'123456789'}).error,'local_confirmation_busy');
  m.confirmLocal({requestId:first.localPrompt.requestId,approved:false});
  assert.equal(m.requestIntent({actionId:'rustdesk.launch'}).error,'local_confirmation_rate_limited');
  c.advance(2);
  assert.equal(m.requestIntent({actionId:'rustdesk.launch'}).ok,true);
});

test('rustdesk.connect proof state binds digest but stores no raw peer ID',()=>{
  const target='123456789';
  const {m}=model();
  const intent=m.requestIntent({actionId:'rustdesk.connect',target});
  assert.equal(intent.localPrompt.target,target);
  const snapBefore=m.snapshot();
  assert.equal(JSON.stringify(snapBefore).includes(target),false);
  assert.equal(snapBefore.pending.inputDigest,canonicalInputDigest('rustdesk.connect',target));
  const grant=m.confirmLocal({requestId:intent.localPrompt.requestId,approved:true}).grant;
  const snapAfter=m.snapshot();
  assert.equal(JSON.stringify(snapAfter).includes(target),false);
  assert.equal(snapAfter.activePair.inputDigest,canonicalInputDigest('rustdesk.connect',target));
  assert.ok(grant.approvalProof);
});

test('target substitution is rejected even with the correct proof and challenge',()=>{
  const {m}=model();
  const grant=approveConnect(m,'123456789');
  const wrong=m.consume({actionId:'rustdesk.connect',target:'987654321',challenge:grant.challenge,approvalProof:grant.approvalProof});
  assert.equal(wrong.ok,false);
  assert.equal(wrong.error,'local_approval_input_mismatch');
  const right=m.consume({actionId:'rustdesk.connect',target:'123456789',challenge:grant.challenge,approvalProof:grant.approvalProof});
  assert.equal(right.ok,true);
});

test('action substitution and session substitution are rejected',()=>{
  const {m}=model();
  const grant=approveLaunch(m);
  assert.equal(m.consume({actionId:'rustdesk.connect',target:'123456789',challenge:grant.challenge,approvalProof:grant.approvalProof}).error,'local_approval_action_mismatch');
  assert.equal(m.consume({actionId:'rustdesk.launch',sessionId:'ZYXWVUTSRQPONMLKJIHGFEDC',challenge:grant.challenge,approvalProof:grant.approvalProof}).error,'local_approval_session_mismatch');
  assert.equal(m.consume({actionId:'rustdesk.launch',challenge:grant.challenge,approvalProof:grant.approvalProof}).ok,true);
});

test('wrong challenge or wrong proof cannot consume the active pair',()=>{
  const {m}=model();
  const grant=approveLaunch(m);
  assert.equal(m.consume({actionId:'rustdesk.launch',challenge:'wrong',approvalProof:grant.approvalProof}).error,'action_challenge_invalid');
  assert.equal(m.consume({actionId:'rustdesk.launch',challenge:grant.challenge,approvalProof:'wrong'}).error,'local_approval_proof_invalid');
  assert.equal(m.consume({actionId:'rustdesk.launch',challenge:grant.challenge,approvalProof:grant.approvalProof}).ok,true);
});

test('successful proof/challenge pair is single-use and replay fails closed',()=>{
  const {m}=model();
  const grant=approveLaunch(m);
  assert.equal(m.consume({actionId:'rustdesk.launch',challenge:grant.challenge,approvalProof:grant.approvalProof}).ok,true);
  assert.deepEqual(m.consume({actionId:'rustdesk.launch',challenge:grant.challenge,approvalProof:grant.approvalProof}),{ok:false,error:'local_approval_proof_required'});
});

test('expired active proof pair is removed and cannot execute',()=>{
  const c=clock();
  const {m}=model({clock:c});
  const grant=approveLaunch(m);
  c.advance(31);
  assert.equal(m.consume({actionId:'rustdesk.launch',challenge:grant.challenge,approvalProof:grant.approvalProof}).error,'local_approval_proof_expired');
  assert.equal(m.snapshot().activePair,null);
});

test('new successful confirmation invalidates an older unused pair',()=>{
  const c=clock();
  const random=sequenceRandom([
    'REQ1-ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'CHALLENGE1-ABCDEFGHIJKLMNOPQRSTUV',
    'PROOF1-ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'REQ2-ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'CHALLENGE2-ABCDEFGHIJKLMNOPQRSTUV',
    'PROOF2-ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  ]);
  const {m}=model({clock:c,random});
  const first=approveLaunch(m);
  c.advance(2);
  const second=approveConnect(m,'123456789');
  assert.equal(m.consume({actionId:'rustdesk.launch',challenge:first.challenge,approvalProof:first.approvalProof}).error,'local_approval_action_mismatch');
  assert.equal(m.consume({actionId:'rustdesk.connect',target:'123456789',challenge:second.challenge,approvalProof:second.approvalProof}).ok,true);
});

test('peer ID validator stays typed and bounded',()=>{
  assert.equal(validPeerId('123456'),true);
  assert.equal(validPeerId('Raven_01'),true);
  assert.equal(validPeerId(' 123456 '),false);
  assert.equal(validPeerId('../../shell'),false);
  assert.equal(validPeerId(''),false);
});

test('research model has no server, process, filesystem or runtime-control implementation',()=>{
  assert.doesNotMatch(modelSource,/http\.server|ThreadingHTTPServer|BaseHTTPRequestHandler|subprocess|Popen|exec\(|spawn\(|rustdesk\.exe|\/launch\/rustdesk['"`)]|\/handoff\/rustdesk['"`)]/i);
  for(const item of ['runtime-implementation-in-this-research-stage','new-routes','generic-approval-endpoint','generic-command-execution','generic-process-launch','shell','generic-file-api','generic-endpoint-dispatch','native-raven-remote-control-api','approval-proof-persistence','peer-id-persistence'])assert.ok(research.forbidden.includes(item));
});

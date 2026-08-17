import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {CAPABILITIES,ACTIONS,ROUTES,AUTH_PROTOCOL,ACTIONS_PROTOCOL,POLICY_ID,canonicalRequest,signProof,TokenProofResearchModel} from '../research/rah-token-proof-auth-model.mjs';
const research=JSON.parse(fs.readFileSync('RAH-TOKEN-PROOF-AUTH-RESEARCH.json','utf8'));
function gitBlobSha(path){const body=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex')}
const token='FreshNodeToken_abcdefghijklmnopqrstuvwxyz123456';
const session='SessionId_abcdefghijklmnop';
const source='192.168.1.10';
const context='RequesterContext_abcdefghijklmnopqrstuvwxyz1234567890';
const challenge='Challenge_abcdefghijklmnopqrstu';
const localProof='LocalProof_abcdefghijklmnopqrstuv';
const makeModel=(extra={})=>new TokenProofResearchModel({token,sessionId:session,...extra});

test('research is runtime-neutral and pins current Stable CC 1.6 / Node 1.2',()=>{
  assert.equal(research.stage,'research-only');assert.equal(research.runtimeMutationAuthorized,false);assert.equal(research.authorityDelta,'none');
  assert.equal(research.sourceStable.commandCenterVersion,'1.6.0');assert.equal(research.sourceStable.nodeAgentVersion,'1.2.0');
  assert.equal(gitBlobSha(research.sourceStable.stableRelease.path),research.sourceStable.stableRelease.gitBlobSha);
});

test('hypothetical target changes auth/actions protocol but adds no business route or authority',()=>{
  assert.equal(AUTH_PROTOCOL,'rah-node-auth-v2');assert.equal(ACTIONS_PROTOCOL,'rah-node-actions-v7');assert.equal(POLICY_ID,'rah-capability-allowlist-v1');
  assert.deepEqual(CAPABILITIES,research.authoritySurface.capabilities);assert.deepEqual(ACTIONS,research.authoritySurface.actions);assert.deepEqual(ROUTES,research.authoritySurface.businessRoutes);
  assert.deepEqual(research.authoritySurface.newBusinessRoutes,[]);
});

test('auth bootstrap exists only as fixed challenge mode on GET /health and returns challenge-only data',()=>{
  const model=makeModel();
  const good=model.issueChallenge({requesterSource:source});assert.equal(good.ok,true);assert.deepEqual(Object.keys(good.payload).sort(),['nonce','nonceTtlSeconds','protocol','sessionId','status'].sort());assert.equal(good.payload.protocol,AUTH_PROTOCOL);assert.equal(good.payload.status,'challenge');
  assert.equal(model.issueChallenge({method:'POST',requesterSource:source}).error,'auth_init_invalid');
  assert.equal(model.issueChallenge({path:'/actions',requesterSource:source}).error,'auth_init_invalid');
  assert.equal(model.issueChallenge({authInit:'yes',requesterSource:source}).error,'auth_init_invalid');
  assert.equal(model.issueChallenge({authorization:'Bearer secret',requesterSource:source}).error,'authorization_transport_forbidden');
  assert.equal(model.issueChallenge({requesterContext:context,requesterSource:source}).error,'auth_init_security_fields_forbidden');
});

test('valid proof succeeds once and replay fails',()=>{
  const model=makeModel();const issued=model.issueChallenge({requesterSource:source});const nonce=issued.payload.nonce;
  const proof=model.clientProof({nonce,method:'GET',path:'/health'});assert.ok(proof);
  assert.deepEqual(model.verify({nonce,proof,requesterSource:source,method:'GET',path:'/health'}),{ok:true,sessionId:session});
  assert.equal(model.verify({nonce,proof,requesterSource:source,method:'GET',path:'/health'}).error,'auth_nonce_invalid_or_expired');
});

test('method path body and fixed security fields are proof-bound',()=>{
  const cases=[
    {sign:{method:'GET',path:'/health'},verify:{method:'GET',path:'/actions'}},
    {sign:{method:'GET',path:'/actions',fields:{approvalAction:'rustdesk.launch',requesterContext:context}},verify:{method:'GET',path:'/actions',fields:{approvalAction:'rustdesk.launch',requesterContext:context+'X'}}},
    {sign:{method:'GET',path:'/storage',fields:{actionChallenge:challenge}},verify:{method:'GET',path:'/storage',fields:{actionChallenge:challenge+'X'}}},
    {sign:{method:'POST',path:'/launch/rustdesk',fields:{requesterContext:context,actionChallenge:challenge,nodeLocalApprovalProof:localProof}},verify:{method:'POST',path:'/launch/rustdesk',fields:{requesterContext:context,actionChallenge:challenge,nodeLocalApprovalProof:localProof+'X'}}},
    {sign:{method:'POST',path:'/handoff/rustdesk',body:Buffer.from('{"peerId":"123456789"}'),fields:{requesterContext:context,actionChallenge:challenge,nodeLocalApprovalProof:localProof}},verify:{method:'POST',path:'/handoff/rustdesk',body:Buffer.from('{"peerId":"987654321"}'),fields:{requesterContext:context,actionChallenge:challenge,nodeLocalApprovalProof:localProof}}}
  ];
  for(const c of cases){const model=makeModel();const nonce=model.issueChallenge({requesterSource:source}).payload.nonce;const proof=model.clientProof({nonce,...c.sign});const result=model.verify({nonce,proof,requesterSource:source,...c.verify});assert.equal(result.ok,false);assert.equal(result.error,'auth_proof_invalid')}
});

test('wrong requester source does not consume correct nonce',()=>{
  const model=makeModel();const nonce=model.issueChallenge({requesterSource:source}).payload.nonce;const proof=model.clientProof({nonce,method:'GET',path:'/health'});
  assert.equal(model.verify({nonce,proof,requesterSource:'192.168.1.11',method:'GET',path:'/health'}).error,'auth_nonce_requester_mismatch');
  assert.equal(model.verify({nonce,proof,requesterSource:source,method:'GET',path:'/health'}).ok,true);
});

test('wrong proof from correct source burns nonce',()=>{
  const model=makeModel();const nonce=model.issueChallenge({requesterSource:source}).payload.nonce;const proof=model.clientProof({nonce,method:'GET',path:'/health'});
  assert.equal(model.verify({nonce,proof:'wrong-proof',requesterSource:source,method:'GET',path:'/health'}).error,'auth_proof_invalid');
  assert.equal(model.verify({nonce,proof,requesterSource:source,method:'GET',path:'/health'}).error,'auth_nonce_invalid_or_expired');
});

test('canonical grammar rejects queries generic fields and semantically misplaced context',()=>{
  const nonce='Nonce_abcdefghijklmnopqrstuvwxyz123456';
  assert.equal(canonicalRequest({sessionId:session,nonce,method:'GET',path:'/health?x=1'}),'');
  assert.equal(canonicalRequest({sessionId:session,nonce,method:'GET',path:'/health',fields:{requesterContext:context}}),'');
  assert.equal(canonicalRequest({sessionId:session,nonce,method:'GET',path:'/actions',fields:{unknown:'x'}}),'');
  assert.equal(canonicalRequest({sessionId:session,nonce,method:'GET',path:'/storage',fields:{requesterContext:context,actionChallenge:challenge}}),'');
  assert.ok(canonicalRequest({sessionId:session,nonce,method:'GET',path:'/actions',fields:{approvalAction:'rustdesk.launch',requesterContext:context}}));
});

test('nonce state is bounded, memory-only and snapshots expose no token or raw nonce',()=>{
  let i=0;const model=makeModel({random:()=>`Nonce_${String(++i).padStart(30,'0')}`,maxPerSource:2,maxGlobal:3});
  const a=model.issueChallenge({requesterSource:source});const b=model.issueChallenge({requesterSource:source});assert.equal(a.ok,true);assert.equal(b.ok,true);
  assert.equal(model.issueChallenge({requesterSource:source}).error,'auth_nonce_source_capacity');
  const c=model.issueChallenge({requesterSource:'192.168.1.11'});assert.equal(c.ok,true);
  assert.equal(model.issueChallenge({requesterSource:'192.168.1.12'}).error,'auth_nonce_capacity');
  const snapshot=JSON.stringify(model.snapshot());assert.doesNotMatch(snapshot,new RegExp(token));assert.doesNotMatch(snapshot,new RegExp(a.payload.nonce));assert.doesNotMatch(snapshot,new RegExp(b.payload.nonce));
});

test('research explicitly replaces only bearer network transport and preserves independent action gates',()=>{
  assert.equal(research.gateReplacementUnderResearch.replace,'current-process-bearer-token-network-transport');assert.equal(research.gateReplacementUnderResearch.with,'current-process-token-local-HMAC-proof-per-request');
  for(const gate of ['advertised-fixed-action','correct-capability','ephemeral-command-center-session-approval','node-session-match','exact-policy-id','node-local-human-confirmation','fresh-action-challenge','fresh-local-approval-proof','actual-requester-source-match','requester-context-match'])assert.ok(research.existingGatesNotReplaced.includes(gate),gate);
  for(const forbidden of ['new-business-route','new-capability','new-action','generic-auth-endpoint','bearer-token-network-transport','bearer-token-persistence','proof-persistence','nonce-persistence','network-token-renewal-endpoint','shell','generic-command-execution','native-raven-remote-control-api'])assert.ok(research.forbidden.includes(forbidden),forbidden);
});

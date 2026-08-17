import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const candidate=require('../rah-command-center-core-v1.6-candidate.js');
const stable=require('../rah-command-center-core-v1.5.js');
const html=fs.readFileSync('RAH-COMMAND-CENTER-V1.6-CANDIDATE.html','utf8');
const readiness=JSON.parse(fs.readFileSync('RAH-REQUESTER-CONTEXT-CANDIDATE-GATE.json','utf8'));
const manifest=JSON.parse(fs.readFileSync('RAH-CC16-REQUESTER-CONTEXT-CANDIDATE.json','utf8'));
function gitBlobSha(path){const body=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex')}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}

const session='SessionId_abcdefghijklmnop';
const context='RequesterContext_abcdefghijklmnopqrstuvwxyz1234567890';
const otherContext='RequesterContext_ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210';
const challenge='Challenge_abcdefghijklmnopqrstu';
const proof='ProofValue_abcdefghijklmnopqrstuv';
const caps=['storage','remote-desktop'];
const baseRow=id=>({...candidate.ACTION_CATALOG[id],...(candidate.ACTION_CATALOG[id].mutating?{localApprovalRequired:true}:{})});
const v6={protocol:'rah-node-actions-v6',status:'ready',policyId:'rah-capability-allowlist-v1',approvalMode:'command-center-ephemeral-plus-node-local',sessionId:session,actions:[baseRow('storage-summary.read'),baseRow('rustdesk.launch'),baseRow('rustdesk.connect')]};
const v5={...v6,protocol:'rah-node-actions-v5'};
const device={id:'node',label:'Node',role:'Test',platform:'Linux',kind:'laptop',status:'unverified',source:'local',enrolled:true,endpointIp:'192.168.1.44',agentHostname:'node',agentVersion:'1.2.0-candidate',agentProtocol:'rah-node-health-v2',agentSessionId:session,capabilities:caps,permissions:{},advertisedActions:['storage-summary.read','rustdesk.launch','rustdesk.connect'],approvedActions:['storage-summary.read','rustdesk.launch','rustdesk.connect']};

test('candidate manifest pins Stable baseline and exact Candidate runtime blobs',()=>{
  assert.equal(manifest.stage,'feature-candidate');assert.equal(manifest.authorityDelta,'none');assert.equal(manifest.runtimeMutationScope,'versioned-candidate-files-only');
  for(const ref of [manifest.sourceStable.stableReleaseManifest,manifest.sourceStable.commandCenterCore,manifest.sourceStable.commandCenterHtml,manifest.sourceStable.nodeAgent,manifest.readiness,manifest.candidateRuntime.commandCenterCore,manifest.candidateRuntime.commandCenterHtml,manifest.candidateRuntime.nodeAgent])verify(ref);
  assert.deepEqual(manifest.authoritySurface,readiness.authoritySurface);
  assert.ok(manifest.existingGatesRetained.includes('current-process-bearer-token'));
});

test('candidate identity matches readiness and authority stays frozen',()=>{
  assert.equal(candidate.CC_VERSION,'1.6.0-candidate');
  assert.equal(candidate.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v6');
  assert.equal(candidate.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.equal(candidate.REQUESTER_CONTEXT_HEADER,'X-RAH-Requester-Context');
  assert.deepEqual([...candidate.CAPABILITY_IDS],readiness.authoritySurface.capabilities);
  assert.deepEqual([...candidate.ACTION_IDS],readiness.authoritySurface.actions);
  assert.deepEqual(readiness.authoritySurface.routes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

test('requester context is strict, transient-format-only data',()=>{
  assert.equal(candidate.sanitizeRequesterContext(context),context);
  for(const bad of['','short','bad context','../RequesterContext_abcdefghijklmnopqrstuvwxyz123456','A'.repeat(31),'A'.repeat(129)])assert.equal(candidate.sanitizeRequesterContext(bad),'');
  assert.notEqual(context,otherContext);
});

test('v6 accepts exact policy/protocol and rejects v5 while Stable v1.5 rejects v6',()=>{
  assert.ok(candidate.sanitizeActionCatalog(v6,caps,session));
  assert.equal(candidate.sanitizeActionCatalog(v5,caps,session),null);
  assert.equal(stable.sanitizeActionCatalog(v6,caps,session),null);
  assert.ok(stable.sanitizeActionCatalog(v5,caps,session));
  assert.equal(candidate.sanitizeActionCatalog({...v6,policyId:'other-policy'},caps,session),null);
});

test('normal storage flow cannot carry requester context',()=>{
  const pre=candidate.actionChallengeRequest(device,'storage-summary.read');
  assert.ok(pre);assert.deepEqual(pre.headers,{});
  const req=candidate.actionExecutionRequest(device,'storage-summary.read',challenge);
  assert.ok(req);assert.equal(req.headers[candidate.REQUESTER_CONTEXT_HEADER],undefined);
  assert.equal(candidate.actionExecutionRequest(device,'storage-summary.read',challenge,context),null);
});

test('mutating intent and execution require the same caller-supplied context field',()=>{
  assert.equal(candidate.localApprovalIntentRequest(device,'rustdesk.launch',undefined,''),null);
  const intent=candidate.localApprovalIntentRequest(device,'rustdesk.launch',undefined,context);
  assert.ok(intent);assert.equal(intent.headers[candidate.REQUESTER_CONTEXT_HEADER],context);
  const grant={actionId:'rustdesk.launch',challenge,localApprovalProof:proof,challengeTtlSeconds:30,localApprovalProofTtlSeconds:30};
  assert.equal(candidate.actionExecutionRequest(device,'rustdesk.launch',grant,''),null);
  const exec=candidate.actionExecutionRequest(device,'rustdesk.launch',grant,context);
  assert.ok(exec);assert.equal(exec.headers[candidate.REQUESTER_CONTEXT_HEADER],context);
  assert.equal(exec.headers[candidate.ACTION_CHALLENGE_HEADER],challenge);
  assert.equal(exec.headers[candidate.LOCAL_APPROVAL_HEADER],proof);
});

test('handoff binds validated peer ID plus requester context without generic arguments',()=>{
  const peer='123456789';
  const grant={actionId:'rustdesk.connect',challenge,localApprovalProof:proof,challengeTtlSeconds:30,localApprovalProofTtlSeconds:30};
  const intent=candidate.localApprovalIntentRequest(device,'rustdesk.connect',peer,context);
  assert.ok(intent);assert.equal(intent.headers[candidate.APPROVAL_TARGET_HEADER],peer);assert.equal(intent.headers[candidate.REQUESTER_CONTEXT_HEADER],context);
  const req=candidate.rustDeskHandoffRequest(device,peer,grant,context);
  assert.ok(req);assert.deepEqual(req.body,{peerId:peer});assert.equal(req.headers[candidate.REQUESTER_CONTEXT_HEADER],context);
  assert.equal(candidate.rustDeskHandoffRequest(device,peer,grant,''),null);
});

test('Candidate browser generates CSPRNG context per mutating flow and never persists it',()=>{
  assert.match(html,/crypto\.getRandomValues/);
  assert.match(html,/newRequesterContextV6\(\)/);
  assert.match(html,/core\.sanitizeRequesterContext/);
  assert.match(html,/freshLocalGrantV6\(d,action,token,target,requesterContext\)/);
  assert.match(html,/core\.actionExecutionRequest\(d,action,grant,requesterContext\)/);
  assert.match(html,/core\.rustDeskHandoffRequest\(d,peerId,grant,requesterContext\)/);
  assert.match(html,/requesterContext=''\s*;document\.getElementById\('actionToken'\)/);
  assert.doesNotMatch(html,/localStorage\.setItem\([^)]*(?:RequesterContext|requesterContext)/i);
  assert.doesNotMatch(html,/sessionStorage\.setItem\([^)]*(?:RequesterContext|requesterContext)/i);
});

test('Stable artifacts remain separate and candidate uses only fixed header grammar',()=>{
  assert.ok(fs.existsSync('rah-command-center-core-v1.5.js'));
  assert.ok(fs.existsSync('RAH-COMMAND-CENTER-V1.5.html'));
  assert.ok(fs.existsSync('rah-node-agent-v1.1.py'));
  assert.deepEqual(readiness.protocolGrammar.allowedOnlyFor,['mutating-local-approval-intent','mutating-fixed-action-execution']);
  assert.equal(readiness.protocolGrammar.genericHeaderNamesAllowed,false);
  assert.equal(readiness.protocolGrammar.genericMetadataMapAllowed,false);
});

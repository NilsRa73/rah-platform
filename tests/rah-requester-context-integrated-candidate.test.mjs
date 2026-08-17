import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const stable=require('../rah-command-center-core-v1.5.js');
const candidate=require('../rah-command-center-core-v1.6-candidate.js');
const contract=JSON.parse(fs.readFileSync('RAH-REQUESTER-CONTEXT-CANDIDATE.json','utf8'));
const readiness=JSON.parse(fs.readFileSync('RAH-REQUESTER-CONTEXT-CANDIDATE-GATE.json','utf8'));
const nodeSource=fs.readFileSync('rah-node-agent-v1.2-candidate.py','utf8');
const browser=fs.readFileSync('RAH-COMMAND-CENTER-V1.6-CANDIDATE.html','utf8');

const session='ABCDEFGHIJKLMNOPQRSTUVWX';
const caps=['storage','remote-desktop'];
const authority={capabilities:['compute','storage','display','remote-desktop'],actions:['storage-summary.read','rustdesk.launch','rustdesk.connect'],routes:['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']};

function v6Payload(){return{protocol:'rah-node-actions-v6',status:'ready',sessionId:session,policyId:'rah-capability-allowlist-v1',approvalMode:'command-center-ephemeral-plus-node-local-context',actions:[{id:'storage-summary.read',capability:'storage',method:'GET',path:'/storage',scope:'system-volume',mutating:false},{id:'rustdesk.launch',capability:'remote-desktop',method:'POST',path:'/launch/rustdesk',scope:'fixed-app',mutating:true,localApprovalRequired:true,requesterContextRequired:true},{id:'rustdesk.connect',capability:'remote-desktop',method:'POST',path:'/handoff/rustdesk',scope:'fixed-app-peer-id',mutating:true,input:'peer-id',localApprovalRequired:true,requesterContextRequired:true}]}}
function v5Payload(){return{...v6Payload(),protocol:'rah-node-actions-v5',approvalMode:'command-center-ephemeral-plus-node-local',actions:v6Payload().actions.map(row=>{const copy={...row};delete copy.requesterContextRequired;return copy})}}

test('integrated Candidate manifest matches readiness target and preserves exact authority',()=>{
  assert.equal(contract.stage,'integrated-runtime-candidate');
  assert.equal(contract.authorityDelta,'none');
  assert.equal(contract.commandCenter.candidateVersion,'1.6.0-candidate');
  assert.equal(contract.nodeAgent.candidateVersion,'1.2.0-candidate');
  assert.equal(contract.protocol.candidateActionsProtocol,'rah-node-actions-v6');
  assert.equal(contract.protocol.healthProtocol,'rah-node-health-v2');
  assert.equal(contract.protocol.policyId,'rah-capability-allowlist-v1');
  assert.deepEqual(contract.authoritySurface,authority);
  assert.equal(readiness.targetCandidate.commandCenterVersion,contract.commandCenter.candidateVersion);
  assert.equal(readiness.targetCandidate.nodeAgentVersion,contract.nodeAgent.candidateVersion);
  assert.equal(readiness.targetCandidate.nodeActionsProtocol,contract.protocol.candidateActionsProtocol);
});

test('Stable v5 and Candidate v6 reject each other catalogs fail-closed',()=>{
  assert.equal(stable.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v5');
  assert.equal(candidate.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v6');
  assert.equal(stable.sanitizeActionCatalog(v6Payload(),caps,session),null);
  assert.equal(candidate.sanitizeActionCatalog(v5Payload(),caps,session),null);
  assert.ok(candidate.sanitizeActionCatalog(v6Payload(),caps,session));
});

test('Candidate adds only one fixed requester-context header and no generic authority',()=>{
  assert.equal(candidate.REQUESTER_CONTEXT_HEADER,'X-RAH-Requester-Context');
  assert.ok(nodeSource.includes("REQUESTER_CONTEXT_HEADER='X-RAH-Requester-Context'"));
  assert.ok(browser.includes('core.REQUESTER_CONTEXT_HEADER'));
  for(const forbidden of ['/shell','/exec','/command','/files','/remote-control'])assert.ok(!nodeSource.includes(forbidden));
  for(const forbidden of ['generic-endpoint','generic-command-execution','generic-process-launch','shell','generic-file-api','generic-endpoint-dispatch','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api'])assert.ok(contract.forbidden.includes(forbidden));
});

test('requester context is flow-memory-only while Node keeps digest in active pair only',()=>{
  const p=contract.requesterContextPolicy;
  assert.equal(p.commandCenterGeneration,'crypto.getRandomValues-per-mutating-flow');
  assert.equal(p.commandCenterLifetime,'single-mutating-flow-memory-only');
  assert.equal(p.commandCenterPersistence,'forbidden');
  assert.equal(p.nodeRawContextPersistence,'forbidden');
  assert.equal(p.nodeContextDigest,'sha256');
  assert.equal(p.nodeContextDigestLifetime,'active-pair-only');
  assert.equal(p.wrongContextDoesNotConsumeCorrectPair,true);
  assert.equal(p.sourceMismatchRemainsIndependent,true);
});

test('all prior security gates stay mandatory and Candidate cannot self-promote',()=>{
  for(const gate of ['advertised-fixed-action','correct-capability','ephemeral-command-center-session-approval','current-process-bearer-token','node-session-match','exact-policy-id','node-local-human-confirmation','fresh-action-challenge','fresh-local-approval-proof','requester-source-match'])assert.ok(contract.existingGatesRemainMandatory.includes(gate),gate);
  assert.equal(contract.promotion.allowed,false);
  assert.equal(contract.promotion.requiresSeparateStableReadiness,true);
  assert.equal(contract.promotion.stableRuntimeFilesMustRemainUntouched,true);
});

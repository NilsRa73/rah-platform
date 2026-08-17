import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';

const gate=JSON.parse(fs.readFileSync('RAH-REQUESTER-CONTEXT-CANDIDATE-GATE.json','utf8'));
const stable=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC15-NODE11-STABLE-RELEASE.json','utf8'));
const research=JSON.parse(fs.readFileSync('RAH-REQUESTER-CONTEXT-BINDING-RESEARCH.json','utf8'));

function gitBlobSha(path){
  const body=fs.readFileSync(path);
  return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex');
}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('readiness is implementation-only, authority-neutral and pins current Stable plus research evidence',()=>{
  assert.equal(gate.schemaVersion,1);
  assert.equal(gate.stage,'implementation-readiness');
  assert.equal(gate.authorityDelta,'none');
  assert.equal(gate.runtimeMutationAuthorized,false);
  for(const ref of Object.values(gate.sourceStable).filter(v=>v&&typeof v==='object'&&v.path))verify(ref);
  for(const ref of Object.values(gate.researchEvidence))verify(ref);
  assert.equal(release.nodeAgentVersion,'1.1.0');
  assert.equal(research.stage,'research-only');
});

test('target Candidate explicitly advances only CC/Node versions and Actions v6 while policy and health stay pinned',()=>{
  assert.deepEqual(gate.targetCandidate,{commandCenterVersion:'1.6.0-candidate',nodeAgentVersion:'1.2.0-candidate',nodeHealthProtocol:'rah-node-health-v2',nodeActionsProtocol:'rah-node-actions-v6',policyId:'rah-capability-allowlist-v1'});
  assert.equal(gate.sourceStable.commandCenterVersion,'1.5.0');
  assert.equal(gate.sourceStable.nodeAgentVersion,'1.1.0');
  assert.equal(gate.sourceStable.nodeActionsProtocol,'rah-node-actions-v5');
  assert.equal(gate.sourceStable.policyId,gate.targetCandidate.policyId);
  assert.equal(gate.sourceStable.nodeHealthProtocol,gate.targetCandidate.nodeHealthProtocol);
});

test('authority remains exactly frozen 4 capabilities, 3 actions and 5 routes',()=>{
  assert.deepEqual(gate.authoritySurface,{capabilities:caps,actions,routes});
  assert.deepEqual(stable.capabilities,caps);
  assert.deepEqual(stable.actions.map(row=>row.id),actions);
  assert.deepEqual(stable.routes,routes);
  assert.deepEqual(research.authoritySurface,{capabilities:caps,actions,routes});
});

test('v6 grammar adds exactly one fixed requester-context header with no generic metadata channel',()=>{
  const p=gate.protocolGrammar;
  assert.equal(p.requesterContextHeader,'X-RAH-Requester-Context');
  assert.deepEqual(p.allowedOnlyFor,['mutating-local-approval-intent','mutating-fixed-action-execution']);
  assert.equal(p.storageSummaryContextRule,'must-be-absent');
  assert.equal(p.normalActionsCatalogContextRule,'must-be-absent');
  assert.equal(p.healthContextRule,'must-be-absent');
  assert.equal(p.genericHeaderNamesAllowed,false);
  assert.equal(p.genericMetadataMapAllowed,false);
  assert.equal(p.contextGeneration,'command-center-csprng-per-mutating-flow');
  assert.equal(p.contextFormat,'base64url-like-32-to-128-characters');
});

test('Node may retain context digest only inside active pair and raw context is never stored, echoed or logged',()=>{
  const p=gate.protocolGrammar;
  assert.equal(p.nodeRawContextStorage,'forbidden');
  assert.equal(p.nodeContextDigestStorage,'active-in-memory-pair-only');
  assert.equal(p.nodeContextDigest,'sha256');
  assert.equal(p.nodeRawContextEcho,'forbidden');
  assert.equal(p.nodeRawContextLogging,'forbidden');
  assert.ok(p.pairBindings.includes('requester-context-digest'));
  assert.ok(p.pairBindings.includes('actual-requester-source-ipv4'));
  assert.equal(p.wrongContextFailsClosed,true);
  assert.equal(p.wrongContextDoesNotConsumeCorrectPair,true);
  assert.equal(p.wrongSourceRemainsIndependentGate,true);
  assert.equal(p.reloadOrNewFlowRequiresNewContextAndApproval,true);
});

test('v5 and v6 are explicitly incompatible while policy and health protocol remain unchanged',()=>{
  assert.equal(gate.compatibility.stableV5RejectsCandidateV6,true);
  assert.equal(gate.compatibility.candidateV6RejectsStableV5,true);
  assert.equal(gate.compatibility.silentProtocolUpgradeAllowed,false);
  assert.equal(gate.compatibility.policyIdUnchanged,true);
  assert.equal(gate.compatibility.healthProtocolUnchanged,true);
});

test('implementation conditions require separate versioned Candidate files and full fail-closed regression coverage',()=>{
  for(const condition of ['candidate-runtime-files-are-versioned-and-separate-from-stable','stable-command-center-1.5-files-remain-untouched','stable-node-agent-1.1-file-remains-untouched','candidate-requires-actions-v6-and-exact-policy-id','correct-context-succeeds-once','missing-context-fails-closed','wrong-context-fails-without-consuming-correct-pair','wrong-source-remains-independent-failure','raw-context-never-enters-node-snapshot-or-persistence','v5-v6-mismatch-fails-closed-both-directions','exact-4-capability-3-action-5-route-authority-remains','existing-token-session-policy-human-confirmation-challenge-proof-gates-remain','stable-and-candidate-gates-must-be-green-before-promotion'])assert.ok(gate.implementationConditions.includes(condition),condition);
});

test('generic authority and all sensitive persistence remain forbidden',()=>{
  for(const forbidden of ['new-capabilities','new-actions','new-routes','generic-endpoint','generic-approval-endpoint','generic-command-execution','generic-process-launch','shell','generic-file-api','generic-endpoint-dispatch','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api','forwarding-header-identity','bearer-token-persistence','action-challenge-persistence','node-local-approval-proof-persistence','raw-requester-context-persistence','password-persistence','peer-id-persistence','network-token-renewal-endpoint'])assert.ok(gate.forbiddenExpansion.includes(forbidden),forbidden);
  for(const forbidden of ['bearer-token','action-challenge','node-local-approval-proof','raw-requester-context','password','rustdesk-peer-id','executable-path','arbitrary-arguments'])assert.ok(gate.persistence.forbidden.includes(forbidden),forbidden);
});
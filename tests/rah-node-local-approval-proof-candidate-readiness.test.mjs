import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';

const gate=JSON.parse(fs.readFileSync('RAH-NODE-LOCAL-APPROVAL-PROOF-CANDIDATE-GATE.json','utf8'));
const research=JSON.parse(fs.readFileSync('RAH-NODE-LOCAL-APPROVAL-PROOF-RESEARCH.json','utf8'));
const stableRelease=JSON.parse(fs.readFileSync('RAH-CC14-STABLE-RELEASE.json','utf8'));
const design=fs.readFileSync('RAH-NODE-LOCAL-APPROVAL-PROOF-CANDIDATE-DESIGN.md','utf8');

function gitBlobSha(path){
  const body=fs.readFileSync(path);
  return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex');
}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('readiness stage pins frozen Stable 1.4 / Node 0.9 and research evidence',()=>{
  assert.equal(gate.schemaVersion,1);
  assert.equal(gate.stage,'implementation-readiness');
  assert.equal(gate.authorityDelta,'none');
  for(const ref of [gate.sourceStable.releaseManifest,gate.sourceStable.commandCenterCore,gate.sourceStable.commandCenterHtml,gate.sourceStable.nodeAgent,gate.researchEvidence.contract,gate.researchEvidence.threatModel,gate.researchEvidence.referenceModel])verify(ref);
  assert.equal(gate.sourceStable.commandCenterVersion,'1.4.0');
  assert.equal(gate.sourceStable.nodeAgentVersion,'0.9.0');
  assert.equal(stableRelease.commandCenterVersion,'1.4.0');
  assert.equal(stableRelease.nodeAgentVersion,'0.9.0');
  assert.equal(research.stage,'research-only');
});

test('Candidate labels advance protocol only while policy and health protocol stay pinned',()=>{
  assert.equal(gate.candidate.commandCenterVersion,'1.5.0-candidate');
  assert.equal(gate.candidate.nodeAgentVersion,'1.0.0-candidate');
  assert.equal(gate.candidate.nodeHealthProtocol,'rah-node-health-v2');
  assert.equal(gate.candidate.nodeActionsProtocol,'rah-node-actions-v5');
  assert.equal(gate.candidate.policyId,'rah-capability-allowlist-v1');
  assert.equal(gate.sourceStable.nodeActionsProtocol,'rah-node-actions-v4');
  assert.equal(gate.sourceStable.policyId,gate.candidate.policyId);
});

test('Candidate authority surface is exactly the frozen Stable 4/3/5 surface',()=>{
  assert.deepEqual(gate.authoritySurface.capabilities,caps);
  assert.deepEqual(gate.authoritySurface.actions,actions);
  assert.deepEqual(gate.authoritySurface.routes,routes);
  assert.deepEqual(gate.authoritySurface,stableRelease.authoritySurface);
  assert.deepEqual(gate.authoritySurface,research.authoritySurface);
});

test('v5 approval intent reuses GET /actions and adds no route or generic argument channel',()=>{
  const p=gate.protocolGrammar;
  assert.equal(p.catalogRoute,'/actions');
  assert.equal(p.catalogMethod,'GET');
  assert.equal(p.approvalActionHeader,'X-RAH-Approval-Action');
  assert.equal(p.approvalTargetHeader,'X-RAH-Approval-Target');
  assert.equal(p.approvalProofHeader,'X-RAH-Local-Approval');
  assert.equal(p.actionChallengeHeader,'X-RAH-Action-Challenge');
  assert.deepEqual(p.approvalActionAllowedValues,['rustdesk.launch','rustdesk.connect']);
  assert.equal(p.launchTargetHeaderRule,'must-be-absent');
  assert.equal(p.connectTargetHeaderRule,'required-and-must-pass-existing-peer-id-validator');
  assert.equal(p.genericHeadersOrBodyArguments,false);
  assert.equal(p.newRoute,false);
});

test('normal catalog may advertise but cannot mint a mutating local proof without explicit intent',()=>{
  assert.match(gate.protocolGrammar.catalogWithoutApprovalIntent,/must-not-issue-mutating-local-approval-proof/);
  assert.match(gate.protocolGrammar.approvalIntentWithInvalidHeaderShape,/fail-closed-before-local-prompt/);
  assert.match(gate.protocolGrammar.approvalIntentWithValidHeaderShape,/local-node-confirmation/);
});

test('mutating proof is strictly additive to every existing security gate',()=>{
  const required=gate.executionRequirementsMutating;
  for(const item of ['fixed-action','advertised-action','required-capability','cc-ephemeral-local-approval','current-process-bearer-token','agent-session-match','exact-policy-id','node-local-human-confirmation','fresh-action-bound-single-use-challenge','fresh-node-local-single-use-approval-proof','proof-challenge-action-session-input-digest-pair-match'])assert.ok(required.includes(item),`missing ${item}`);
  assert.equal(gate.mutatingProofPolicy.additionalToExistingGates,true);
  assert.deepEqual(gate.mutatingProofPolicy.requiredFor,['rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(gate.mutatingProofPolicy.notRequiredFor,['storage-summary.read']);
});

test('proof pair is bounded, short-lived, single-use and target-digest bound',()=>{
  const p=gate.mutatingProofPolicy;
  assert.equal(p.proofTtlSeconds,30);
  assert.equal(p.challengeTtlSeconds,30);
  assert.ok(p.proofRandomBitsMinimum>=192);
  assert.equal(p.challengeAndProofDistinct,true);
  assert.equal(p.singleUse,true);
  assert.equal(p.atomicPairConsumption,true);
  assert.equal(p.maxPendingLocalConfirmations,1);
  assert.equal(p.maxActiveUnusedPairs,1);
  assert.equal(p.newSuccessfulConfirmationInvalidatesOlderUnusedPair,true);
  assert.equal(p.proofStorage,'process-memory-only');
  assert.equal(p.challengeStorage,'process-memory-only');
  assert.equal(p.rawPeerIdProofState,'forbidden');
  assert.equal(p.connectProofState,'sha256-canonical-peer-id-digest-only');
  assert.deepEqual(p.boundTo,['fixed-action-id','node-agent-session-id','canonical-action-input-digest','paired-challenge']);
});

test('console coordinator keeps local input out of network threads and fails closed headless',()=>{
  const c=gate.consoleCoordinator;
  assert.equal(c.interactiveConsoleRequiredForMutatingProof,true);
  assert.equal(c.headlessBehavior,'fail-closed-for-mutating-proof-intent');
  assert.equal(c.networkThreadReadsStdin,false);
  assert.equal(c.dedicatedLocalCoordinatorOwnsStdin,true);
  assert.equal(c.pendingQueueCapacity,1);
  assert.equal(c.networkWaitSeconds,30);
  assert.ok(c.promptCooldownSecondsMinimum>=2);
  assert.equal(c.attackerFreeTextInPrompt,false);
  assert.equal(c.approvalInput,'local-y-or-n-only');
  assert.equal(c.remoteFallback,false);
});

test('design explicitly forbids HTTP threads reading stdin and defines fixed prompts only',()=>{
  assert.match(design,/HTTP worker threads never call `input\(\)`, read stdin/);
  assert.match(design,/coordinator owns all stdin reads/);
  assert.match(design,/queue capacity: one pending confirmation/);
  assert.match(design,/one active unused challenge\/proof pair/);
  assert.match(design,/No remote confirmation fallback is allowed/);
  assert.match(design,/RAH local approval: Launch RustDesk\? \[y\/N\]/);
  assert.match(design,/RAH local approval: Connect RustDesk to <validated-peer-id>\? \[y\/N\]/);
});

test('rollback remains byte-pinned Stable 1.4 / Node 0.9 with no migration',()=>{
  assert.equal(gate.rollback.commandCenterVersion,'1.4.0');
  assert.equal(gate.rollback.nodeAgentVersion,'0.9.0');
  assert.equal(gate.rollback.nodeActionsProtocol,'rah-node-actions-v4');
  assert.equal(gate.rollback.policyId,'rah-capability-allowlist-v1');
  assert.equal(gate.rollback.deviceRegistryKey,'rah.cc.devices.v1');
  assert.equal(gate.rollback.dataMigration,'none');
  assert.equal(gate.rollback.secretMigration,'none');
  assert.equal(gate.rollback.candidateRuntimeMustBeVersionedSeparately,true);
});

test('readiness explicitly forbids runtime files and every generic authority expansion',()=>{
  for(const item of ['new-capabilities','new-actions','new-routes','generic-approval-endpoint','generic-command-execution','generic-process-launch','shell','generic-file-api','generic-endpoint-dispatch','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api','password-persistence','bearer-token-persistence','challenge-persistence','approval-proof-persistence','peer-id-persistence','network-token-renewal-endpoint','runtime-files-in-readiness-pr'])assert.ok(gate.forbidden.includes(item),`missing forbidden ${item}`);
  assert.match(gate.implementationAuthorization,/separate Candidate runtime branch/);
});

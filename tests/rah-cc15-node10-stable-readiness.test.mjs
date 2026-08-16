import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const gate=JSON.parse(fs.readFileSync('RAH-CC15-NODE10-STABLE-PROMOTION-GATE.json','utf8'));
const candidateManifest=JSON.parse(fs.readFileSync('RAH-NODE-LOCAL-APPROVAL-PROOF-CANDIDATE.json','utf8'));
const stableRelease=JSON.parse(fs.readFileSync('RAH-CC14-STABLE-RELEASE.json','utf8'));
const candidate=require('../rah-command-center-core-v1.5-candidate.js');
const stable=require('../rah-command-center-core-v1.4.js');
const nodeSource=fs.readFileSync('rah-node-agent-v1.0-candidate.py','utf8');
const browser=fs.readFileSync('RAH-COMMAND-CENTER-V1.5-CANDIDATE.html','utf8');

function gitBlobSha(path){const body=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex')}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('readiness pins integrated Candidate, Stable rollback and research/readiness evidence',()=>{
  assert.equal(gate.stage,'stable-promotion-readiness');
  assert.equal(gate.authorityDelta,'none');
  for(const ref of [gate.candidate.commandCenterCore,gate.candidate.commandCenterHtml,gate.candidate.nodeAgent,gate.candidate.integratedManifest,gate.currentStable.releaseManifest,gate.currentStable.commandCenterCore,gate.currentStable.commandCenterHtml,gate.currentStable.nodeAgent,gate.evidence.researchContract,gate.evidence.threatModel,gate.evidence.referenceModel,gate.evidence.implementationGate,gate.evidence.implementationDesign])verify(ref);
});

test('Candidate and Stable preserve identical exact 4/3/5 authority surface',()=>{
  assert.deepEqual(gate.authoritySurface.capabilities,caps);
  assert.deepEqual(gate.authoritySurface.actions,actions);
  assert.deepEqual(gate.authoritySurface.routes,routes);
  assert.deepEqual(gate.authoritySurface,stableRelease.authoritySurface);
  assert.deepEqual(gate.authoritySurface,candidateManifest.authoritySurface);
  assert.deepEqual([...candidate.CAPABILITY_IDS],caps);
  assert.deepEqual([...candidate.ACTION_IDS],actions);
  assert.deepEqual([...candidate.CAPABILITY_IDS],[...stable.CAPABILITY_IDS]);
  assert.deepEqual([...candidate.ACTION_IDS],[...stable.ACTION_IDS]);
  assert.match(nodeSource,/ROUTES=\('\/health','\/actions','\/storage','\/launch\/rustdesk','\/handoff\/rustdesk'\)/);
});

test('v5 transition is isolated and policy ID is unchanged',()=>{
  assert.equal(gate.protocolTransition.stable,'rah-node-actions-v4');
  assert.equal(gate.protocolTransition.candidate,'rah-node-actions-v5');
  assert.equal(gate.protocolTransition.policyIdUnchanged,true);
  assert.equal(gate.protocolTransition.candidateRejectsV4,true);
  assert.equal(gate.protocolTransition.stableRejectsV5,true);
  assert.equal(candidate.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v5');
  assert.equal(stable.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(candidate.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.equal(candidate.ALLOWLIST_POLICY_ID,stable.ALLOWLIST_POLICY_ID);
  assert.match(nodeSource,/ACTIONS_PROTOCOL='rah-node-actions-v5'/);
  assert.match(nodeSource,/ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'/);
});

test('Node-local proof is additive to all existing mutating action gates',()=>{
  const required=gate.stableRequirementsIfPromoted.mutating;
  for(const item of ['fixed-action','advertised-action','remote-desktop-capability','cc-ephemeral-local-approval','current-process-bearer-token','agent-session-match','exact-policy-id','node-local-human-confirmation','fresh-action-bound-single-use-challenge','fresh-node-local-single-use-approval-proof','proof-challenge-action-session-input-digest-pair-match'])assert.ok(required.includes(item),`missing ${item}`);
  const storage=gate.stableRequirementsIfPromoted.storage;
  for(const item of ['fixed-action','advertised-action','storage-capability','cc-ephemeral-local-approval','current-process-bearer-token','agent-session-match','exact-policy-id','fresh-action-bound-single-use-challenge'])assert.ok(storage.includes(item),`missing storage ${item}`);
});

test('proof policy is bounded, fail-closed and never persistent',()=>{
  const p=gate.proofPolicy;
  assert.deepEqual(p.requiredFor,['rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(p.notRequiredFor,['storage-summary.read']);
  assert.equal(p.intentRoute,'/actions');assert.equal(p.newRoute,false);
  assert.equal(p.proofTtlSeconds,30);assert.equal(p.challengeTtlSeconds,30);assert.equal(p.proofRandomBytes,24);
  assert.equal(p.proofAndChallengeDistinct,true);assert.equal(p.singleUse,true);assert.equal(p.atomicPairConsumption,true);
  assert.deepEqual(p.boundTo,['fixed-action-id','node-agent-session-id','canonical-action-input-digest','paired-challenge']);
  assert.equal(p.maxPendingLocalConfirmations,1);assert.equal(p.maxActiveUnusedPairs,1);assert.equal(p.newSuccessfulConfirmationInvalidatesOlderUnusedPair,true);
  assert.equal(p.interactiveConsoleOnly,true);assert.equal(p.headlessMutatingIntent,'fail-closed');assert.equal(p.networkThreadReadsStdin,false);assert.equal(p.remoteFallback,false);
  assert.equal(p.connectInputBinding,'sha256-canonical-peer-id');assert.equal(p.rawPeerIdInProofState,false);
  assert.equal(p.proofPersistence,'forbidden');assert.equal(p.challengePersistence,'forbidden');
});

test('browser preserves ephemeral CC approval and fixed security-header boundary',()=>{
  const p=gate.browserPolicy;
  assert.equal(p.ephemeralCcApprovalPersists,false);assert.equal(p.startupScrubsPersistedApprovals,true);assert.equal(p.oldMutatingChallengePathFailsClosed,true);assert.equal(p.mutatingButtonsUseOnlyV5Handlers,true);
  assert.deepEqual(p.fixedSecurityHeaders,['X-RAH-Action-Challenge','X-RAH-Local-Approval','X-RAH-Approval-Action','X-RAH-Approval-Target']);
  assert.equal(p.tokenChallengeProofPeerPersistence,'forbidden');
  assert.match(browser,/core\.persistableDeviceRegistry\(loaded\)/);assert.match(browser,/runApprovedActionV5/);assert.match(browser,/runRustDeskHandoffV5/);
  assert.match(browser,/allowed=\[core\.ACTION_CHALLENGE_HEADER,core\.LOCAL_APPROVAL_HEADER,core\.APPROVAL_ACTION_HEADER,core\.APPROVAL_TARGET_HEADER\]/);
});

test('Node Candidate retains fixed RustDesk ownership and no generic runtime authority',()=>{
  assert.match(nodeSource,/launcher=app_launcher or _base\.launch_executable/);
  assert.match(nodeSource,/handoff=handoff_launcher or _base\.launch_rustdesk_connect/);
  assert.doesNotMatch(nodeSource,/subprocess\.Popen|shell=True/);
  assert.doesNotMatch(nodeSource,/["']\/(?:exec|shell|commands|files|remote-control|remote_control)(?:\/|["'?])/i);
  assert.match(nodeSource,/def log_message\(self,fmt,\*args\):return/);
});

test('rollback remains Stable 1.4 / Node 0.9 / v4 with no data or secret migration',()=>{
  assert.equal(gate.rollback.commandCenterVersion,'1.4.0');assert.equal(gate.rollback.nodeAgentVersion,'0.9.0');assert.equal(gate.rollback.nodeActionsProtocol,'rah-node-actions-v4');assert.equal(gate.rollback.policyId,'rah-capability-allowlist-v1');
  assert.equal(gate.rollback.deviceRegistryKey,'rah.cc.devices.v1');assert.equal(gate.rollback.dataMigration,'none');assert.equal(gate.rollback.secretMigration,'none');assert.equal(gate.rollback.candidateAndStableRuntimeVersionedSeparately,true);
});

test('readiness forbids every authority and secret-persistence expansion',()=>{
  for(const item of ['new-capabilities','new-actions','new-routes','generic-approval-endpoint','generic-command-execution','generic-process-launch','shell','generic-file-api','generic-endpoint-dispatch','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api','password-persistence','bearer-token-persistence','challenge-persistence','approval-proof-persistence','peer-id-persistence','network-token-renewal-endpoint'])assert.ok(gate.forbiddenExpansion.includes(item),`missing forbidden ${item}`);
  assert.match(gate.promotionAuthorization,/separate PR/);
});

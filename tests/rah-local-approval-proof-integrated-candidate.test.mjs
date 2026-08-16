import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const manifest=JSON.parse(fs.readFileSync('RAH-NODE-LOCAL-APPROVAL-PROOF-CANDIDATE.json','utf8'));
const core=require('../rah-command-center-core-v1.5-candidate.js');
const stable=require('../rah-command-center-core-v1.4.js');
const nodeSource=fs.readFileSync('rah-node-agent-v1.0-candidate.py','utf8');
const browser=fs.readFileSync('RAH-COMMAND-CENTER-V1.5-CANDIDATE.html','utf8');

function gitBlobSha(path){const body=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex')}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('integrated Candidate pins CC, Node, Stable rollback and readiness evidence blobs',()=>{
  assert.equal(manifest.stage,'integrated-runtime-candidate');
  assert.equal(manifest.authorityDelta,'none');
  for(const ref of [manifest.commandCenter.core,manifest.commandCenter.browser,manifest.nodeAgent.runtime,manifest.sourceStable.releaseManifest,manifest.sourceStable.commandCenterCore,manifest.sourceStable.commandCenterHtml,manifest.sourceStable.nodeAgent,manifest.readinessEvidence.gate,manifest.readinessEvidence.design,manifest.readinessEvidence.researchContract,manifest.readinessEvidence.threatModel])verify(ref);
});

test('integrated Candidate remains exact 4 capabilities / 3 actions / 5 routes',()=>{
  assert.deepEqual(manifest.authoritySurface.capabilities,caps);
  assert.deepEqual(manifest.authoritySurface.actions,actions);
  assert.deepEqual(manifest.authoritySurface.routes,routes);
  assert.deepEqual([...core.CAPABILITY_IDS],caps);
  assert.deepEqual([...core.ACTION_IDS],actions);
  assert.deepEqual([...core.CAPABILITY_IDS],[...stable.CAPABILITY_IDS]);
  assert.deepEqual([...core.ACTION_IDS],[...stable.ACTION_IDS]);
  assert.match(nodeSource,/ROUTES=\('\/health','\/actions','\/storage','\/launch\/rustdesk','\/handoff\/rustdesk'\)/);
});

test('protocol isolation is explicit and policy ID stays unchanged',()=>{
  assert.equal(manifest.protocol.stableActionsProtocol,'rah-node-actions-v4');
  assert.equal(manifest.protocol.candidateActionsProtocol,'rah-node-actions-v5');
  assert.equal(manifest.protocol.policyId,'rah-capability-allowlist-v1');
  assert.equal(manifest.protocol.stableRejectsCandidateProtocol,true);
  assert.equal(manifest.protocol.candidateRejectsStableProtocol,true);
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v5');
  assert.equal(core.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.match(nodeSource,/ACTIONS_PROTOCOL='rah-node-actions-v5'/);
  assert.match(nodeSource,/ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'/);
});

test('mutating execution boundary adds Node-local proof without removing existing gates',()=>{
  const required=manifest.executionBoundary.mutating;
  for(const gate of ['advertised-action','remote-desktop-capability','cc-ephemeral-local-approval','current-process-token','session-match','exact-policy-id','node-local-human-confirmation','fresh-single-use-challenge','fresh-single-use-local-approval-proof','action-session-input-digest-pair-match'])assert.ok(required.includes(gate),`missing ${gate}`);
  assert.deepEqual(manifest.localProofPolicy.requiredFor,['rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(manifest.localProofPolicy.notRequiredFor,['storage-summary.read']);
  assert.equal(manifest.localProofPolicy.challengeAndProofMustBeDistinct,true);
  assert.equal(manifest.localProofPolicy.atomicPairConsumption,true);
  assert.equal(manifest.localProofPolicy.rawPeerIdInProofState,false);
});

test('browser policy preserves Stable 1.4 ephemeral approval and fixed header surface',()=>{
  assert.equal(manifest.browserPolicy.ephemeralCcApprovalInheritedFromStable14,true);
  assert.equal(manifest.browserPolicy.startupApprovalStorageScrubInherited,true);
  assert.equal(manifest.browserPolicy.oldMutatingChallengeRequestFailsClosed,true);
  assert.equal(manifest.browserPolicy.mutatingButtonsBoundOnlyToV5Handlers,true);
  assert.deepEqual(manifest.browserPolicy.fixedSecurityHeaderWhitelist,['X-RAH-Action-Challenge','X-RAH-Local-Approval','X-RAH-Approval-Action','X-RAH-Approval-Target']);
  assert.match(browser,/core\.persistableDeviceRegistry\(loaded\)/);
  assert.match(browser,/core\.persistableDeviceRegistry\(devices\)/);
  assert.match(browser,/runApprovedActionV5/);
  assert.match(browser,/runRustDeskHandoffV5/);
});

test('rollback remains Stable CC 1.4 / Node 0.9 without migration',()=>{
  assert.equal(manifest.rollback.commandCenterVersion,'1.4.0');
  assert.equal(manifest.rollback.nodeAgentVersion,'0.9.0');
  assert.equal(manifest.rollback.actionsProtocol,'rah-node-actions-v4');
  assert.equal(manifest.rollback.registryKey,'rah.cc.devices.v1');
  assert.equal(manifest.rollback.dataMigration,'none');
  assert.equal(manifest.rollback.secretMigration,'none');
});

test('integrated Candidate forbids generic authority and all secret/proof persistence',()=>{
  for(const item of ['new-capabilities','new-actions','new-routes','generic-approval-endpoint','generic-command-execution','generic-process-launch','shell','generic-file-api','generic-endpoint-dispatch','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api','password-persistence','bearer-token-persistence','challenge-persistence','approval-proof-persistence','peer-id-persistence','network-token-renewal-endpoint'])assert.ok(manifest.forbidden.includes(item),`missing forbidden ${item}`);
  assert.doesNotMatch(nodeSource,/subprocess\.Popen|shell=True/);
});

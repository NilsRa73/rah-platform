import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const sync=JSON.parse(fs.readFileSync('RAH-CC161-NODE121-CANONICAL-MASTER-SYNC.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC161-NODE121-STABLE-RELEASE.json','utf8'));
const core=require('../rah-command-center-core-v1.6.1.js');
const nodeWrapper=fs.readFileSync('rah-node-agent-v1.2.1.py','utf8');
const nodePromoted=fs.readFileSync('rah-node-agent-v1.2-promoted.py','utf8');
const coreWrapper=fs.readFileSync('rah-command-center-core-v1.6.1.js','utf8');
const htmlWrapper=fs.readFileSync('RAH-COMMAND-CENTER-V1.6.1.html','utf8');

function gitBlobSha(path){const b=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${b.length}\0`)).update(b).digest('hex')}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('canonical baseline is Stable CC 1.6.1 / Node 1.2.1 / Actions v6',()=>{
  assert.equal(contract.status,'stable-requester-context-bound-immutable-promoted-runtime');
  assert.equal(contract.policyId,'rah-capability-allowlist-v1');
  assert.deepEqual(contract.baseline,{ravenVersion:'2.0.32',commandCenterVersion:'1.6.1',nodeAgentVersion:'1.2.1',nodeHealthProtocol:'rah-node-health-v2',nodeActionsProtocol:'rah-node-actions-v6'});
  assert.equal(core.CC_VERSION,'1.6.1');assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v6');assert.equal(core.ALLOWLIST_POLICY_ID,contract.policyId);
  assert.equal(release.commandCenterVersion,'1.6.1');assert.equal(release.nodeAgentVersion,'1.2.1');assert.equal(release.nodeActionsProtocol,'rah-node-actions-v6');
});

test('canonical authority remains exactly 4 capabilities, 3 fixed actions and 5 routes',()=>{
  assert.deepEqual(contract.capabilities,caps);assert.deepEqual(contract.actions.map(x=>x.id),actions);assert.deepEqual(contract.routes,routes);
  assert.deepEqual([...core.CAPABILITY_IDS],caps);assert.deepEqual([...core.ACTION_IDS],actions);
  assert.deepEqual(sync.authoritySurface,{capabilities:caps,actions,routes});assert.deepEqual(release.authoritySurface,{capabilities:caps,actions,routes});
});

test('canonical Stable runtime uses immutable promoted implementation rather than current Candidate paths',()=>{
  assert.deepEqual(contract.runtimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.6.1.html',commandCenterCore:'rah-command-center-core-v1.6.1.js',nodeAgent:'rah-node-agent-v1.2.1.py'});
  assert.equal(contract.promotedImplementation.commandCenter,'RAH-COMMAND-CENTER-V1.6-PROMOTED.html');assert.equal(contract.promotedImplementation.commandCenterCore,'rah-command-center-core-v1.6-promoted.js');assert.equal(contract.promotedImplementation.nodeAgent,'rah-node-agent-v1.2-promoted.py');
  assert.equal(contract.promotedImplementation.topLevelCandidatePathsAreStableRuntimeDependencies,false);assert.equal(contract.promotedImplementation.mutation,'requires-explicit-new-version-and-release-gate');
  assert.match(nodeWrapper,/rah-node-agent-v1\.2-promoted\.py/);assert.doesNotMatch(nodeWrapper,/with_name\('rah-node-agent-v1\.2-candidate\.py'\)/);
  assert.match(coreWrapper,/rah-command-center-core-v1\.6-promoted\.js/);assert.doesNotMatch(coreWrapper,/require\('\.\/rah-command-center-core-v1\.6-candidate\.js'\)/);
  assert.ok(htmlWrapper.includes("const SOURCE='RAH-COMMAND-CENTER-V1.6-PROMOTED.html'"));
  for(const ref of Object.values(release.runtime))verify(ref);for(const ref of [release.promotedImplementation.commandCenterCore,release.promotedImplementation.commandCenterHtml,release.promotedImplementation.nodeAgent])verify(ref);
});

test('mutating actions retain all prior gates plus source and strict ASCII requester-context binding',()=>{
  const req=contract.executionRequirements['mutating-fixed-actions'];
  for(const gate of ['action-is-in-fixed-catalog','action-is-advertised-by-node','required-capability-is-advertised','ephemeral-local-per-device-action-approval-exists','current-in-memory-bearer-token-is-present','enrolled-node-session-matches-current-agent-session','actions-catalog-policy-id-matches-rah-capability-allowlist-v1','node-local-human-confirmation-is-present','fresh-action-bound-single-use-challenge-is-present','fresh-node-local-single-use-approval-proof-is-present','proof-challenge-action-session-input-digest-pair-matches','requester-source-matches-node-local-approval-pair','requester-context-digest-matches-node-local-approval-pair'])assert.ok(req.includes(gate),gate);
  assert.deepEqual(contract.approvalPolicy.requesterContextBindingRequiredFor,['rustdesk.launch','rustdesk.connect']);
  assert.equal(contract.approvalPolicy.requesterContextHeader,'X-RAH-Requester-Context');assert.equal(contract.approvalPolicy.requesterContextFormat,'strict-ascii-base64url-like-32-to-128-characters');assert.equal(contract.approvalPolicy.requesterContextDigest,'sha256');assert.equal(contract.approvalPolicy.requesterContextDigestLifetime,'active-pair-only');assert.equal(contract.approvalPolicy.requesterContextSnapshotExposure,'forbidden');assert.equal(contract.approvalPolicy.wrongRequesterContextDoesNotConsumeValidPair,true);
  assert.ok(nodePromoted.includes('value.isascii()'));
});

test('requester source, token, proof and persistence boundaries remain closed',()=>{
  assert.equal(contract.approvalPolicy.requesterSourceOfTruth,'actual-server-socket-peer-ipv4');assert.equal(contract.approvalPolicy.trustForwardedRequesterHeaders,false);assert.equal(contract.approvalPolicy.requesterSourceIpv6Allowed,false);assert.equal(contract.approvalPolicy.wrongRequesterDoesNotConsumeValidPair,true);
  assert.equal(contract.tokenPolicy.storage,'forbidden');assert.equal(contract.tokenPolicy.networkRenewalEndpoint,'forbidden');assert.equal(contract.approvalPolicy.proofPersistence,'forbidden');
  for(const x of ['local-approved-action-ids','bearer-token','action-challenge','node-local-approval-proof','raw-requester-context','requester-context-digest-after-active-pair','password','rustdesk-peer-id','executable-path','arbitrary-arguments'])assert.ok(contract.persistence.forbidden.includes(x),x);
});

test('approval header grammar is fixed and storage remains context-free',()=>{
  assert.deepEqual(contract.approvalHeaders,{intentAction:'X-RAH-Approval-Action',intentTarget:'X-RAH-Approval-Target',executionProof:'X-RAH-Local-Approval',actionChallenge:'X-RAH-Action-Challenge',requesterContext:'X-RAH-Requester-Context'});
  assert.deepEqual(contract.approvalPolicy.requesterContextForbiddenFor,['health','normal-actions-catalog','storage-summary.read']);
  assert.deepEqual(contract.approvalPolicy.nodeLocalProofNotRequiredFor,['storage-summary.read']);
});

test('direct rollback remains clean CC 1.5 / Node 1.1 / Actions v5 with no migration',()=>{
  assert.deepEqual(contract.rollbackRuntimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.5.html',commandCenterCore:'rah-command-center-core-v1.5.js',nodeAgent:'rah-node-agent-v1.1.py'});
  assert.equal(contract.rollback.commandCenterVersion,'1.5.0');assert.equal(contract.rollback.nodeAgentVersion,'1.1.0');assert.equal(contract.rollback.nodeActionsProtocol,'rah-node-actions-v5');assert.equal(contract.rollback.dataMigration,'none');assert.equal(contract.rollback.secretMigration,'none');assert.equal(contract.rollback.registryMigration,'none');
  for(const ref of [release.directRollback.commandCenterCore,release.directRollback.commandCenterHtml,release.directRollback.nodeAgent,release.directRollback.releaseManifest])verify(ref);
});

test('master-sync and generic runtime authority remain fail-closed',()=>{
  assert.equal(sync.authorityDelta,'none');assert.equal(sync.sourcePatchRelease.releaseId,release.releaseId);assert.equal(sync.workflowLifecycle.historicalReferencesMustNotTreatMutableCanonicalAsOldStable,true);
  for(const key of ['promotedImplementationMutation','catalogExpansion','capabilityExpansion','endpointExpansion','tokenPolicyChange','approvalPolicyChange'])assert.equal(contract.masterSyncBoundary[key],'requires-explicit-new-version-and-stable-gate');
  for(const x of ['shell','generic-command-execution','generic-process-launch','arbitrary-executable-path','arbitrary-arguments','generic-file-api','generic-endpoint-dispatch','generic-approval-endpoint','native-remote-control-api'])assert.ok(contract.forbiddenRuntimePower.includes(x),x);
});

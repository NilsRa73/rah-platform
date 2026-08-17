import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const gate=JSON.parse(fs.readFileSync('RAH-CC161-NODE121-STABLE-PATCH-GATE.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC161-NODE121-STABLE-RELEASE.json','utf8'));
const core=require('../rah-command-center-core-v1.6.1.js');
const nodeWrapper=fs.readFileSync('rah-node-agent-v1.2.1.py','utf8');
const coreWrapper=fs.readFileSync('rah-command-center-core-v1.6.1.js','utf8');
const htmlWrapper=fs.readFileSync('RAH-COMMAND-CENTER-V1.6.1.html','utf8');

function gitBlobSha(path){const body=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex')}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}
const authority={capabilities:['compute','storage','display','remote-desktop'],actions:['storage-summary.read','rustdesk.launch','rustdesk.connect'],routes:['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']};

test('patch release identity is CC 1.6.1 / Node 1.2.1 / Actions v6 with no authority delta',()=>{
  assert.equal(release.stage,'stable-release');assert.equal(release.authorityDelta,'none');assert.equal(release.ravenVersion,'2.0.32');
  assert.equal(release.commandCenterVersion,'1.6.1');assert.equal(release.nodeAgentVersion,'1.2.1');assert.equal(release.nodeHealthProtocol,'rah-node-health-v2');assert.equal(release.nodeActionsProtocol,'rah-node-actions-v6');assert.equal(release.policyId,'rah-capability-allowlist-v1');
  assert.equal(core.CC_VERSION,'1.6.1');assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v6');assert.equal(core.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.deepEqual(release.authoritySurface,authority);assert.deepEqual(gate.authoritySurface,authority);
});

test('runtime wrappers, promoted implementation and promotion gate are blob-pinned',()=>{
  for(const ref of Object.values(release.runtime))verify(ref);
  for(const ref of [release.promotedImplementation.commandCenterCore,release.promotedImplementation.commandCenterHtml,release.promotedImplementation.nodeAgent])verify(ref);
  verify(release.promotionGate);
  assert.equal(release.freezeAfterPromotion,true);assert.equal(release.promotedImplementation.mutationRequiresNewVersionAndReleaseGate,true);
});

test('promoted blobs equal hardened Candidate evidence at promotion without making Candidate a runtime dependency',()=>{
  assert.equal(release.promotedImplementation.commandCenterCore.gitBlobSha,gate.hardenedCandidateEvidence.commandCenterCore.gitBlobSha);
  assert.equal(release.promotedImplementation.commandCenterHtml.gitBlobSha,gate.hardenedCandidateEvidence.commandCenterHtml.gitBlobSha);
  assert.equal(release.promotedImplementation.nodeAgent.gitBlobSha,gate.hardenedCandidateEvidence.nodeAgent.gitBlobSha);
  assert.match(nodeWrapper,/PROMOTED_PATH=Path\(__file__\)\.with_name\('rah-node-agent-v1\.2-promoted\.py'\)/);
  assert.doesNotMatch(nodeWrapper,/with_name\('rah-node-agent-v1\.2-candidate\.py'\)/);
  assert.match(coreWrapper,/require\('\.\/rah-command-center-core-v1\.6-promoted\.js'\)/);
  assert.doesNotMatch(coreWrapper,/require\('\.\/rah-command-center-core-v1\.6-candidate\.js'\)/);
  assert.ok(htmlWrapper.includes("const SOURCE='RAH-COMMAND-CENTER-V1.6-PROMOTED.html'"));
  assert.ok(htmlWrapper.includes('rah-command-center-core-v1.6-promoted.js'));
});

test('superseded 1.6.0 / 1.2.0 release is historical evidence and not rollback',()=>{
  verify(release.supersedes.release);
  assert.equal(release.supersedes.commandCenterVersion,'1.6.0');assert.equal(release.supersedes.nodeAgentVersion,'1.2.0');
  assert.equal(gate.supersededRelease.rollbackEligible,false);assert.equal(gate.supersededRelease.status,'historical-superseded-lifecycle-evidence');
});

test('direct rollback is clean CC 1.5 / Node 1.1 with no migration',()=>{
  const rb=release.directRollback;for(const ref of [rb.commandCenterCore,rb.commandCenterHtml,rb.nodeAgent,rb.releaseManifest])verify(ref);
  assert.equal(rb.commandCenterVersion,'1.5.0');assert.equal(rb.nodeAgentVersion,'1.1.0');assert.equal(rb.nodeActionsProtocol,'rah-node-actions-v5');assert.equal(rb.policyId,'rah-capability-allowlist-v1');
  assert.equal(rb.dataMigration,'none');assert.equal(rb.secretMigration,'none');assert.equal(rb.registryMigration,'none');
});

test('canonical master-sync is intentionally separate and pending',()=>{
  assert.equal(gate.canonicalMasterSync.performedInThisPatch,false);assert.equal(gate.canonicalMasterSync.requiredAfterPatchStableGate,true);assert.equal(gate.canonicalMasterSync.mustBeSeparateExplicitGate,true);
  assert.equal(release.canonicalMasterSync.status,'pending-separate-gate');assert.equal(release.canonicalMasterSync.targetAfterPatchGate,'CC 1.6.1 / Node 1.2.1 / Actions v6');
});

test('generic authority and sensitive persistence remain forbidden',()=>{
  for(const x of ['new-capabilities','new-actions','new-routes','generic-endpoint','generic-approval-endpoint','generic-command-execution','generic-process-launch','shell','generic-file-api','generic-endpoint-dispatch','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api','forwarding-header-identity','network-token-renewal-endpoint'])assert.ok(gate.forbiddenExpansion.includes(x),x);
  for(const x of ['bearer-token','action-challenge','node-local-approval-proof','raw-requester-context','password','rustdesk-peer-id'])assert.ok(release.forbiddenPersistence.includes(x),x);
});
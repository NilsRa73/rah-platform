import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';

const release=JSON.parse(fs.readFileSync('RAH-CC15-NODE11-STABLE-RELEASE.json','utf8'));
const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const readiness=JSON.parse(fs.readFileSync('RAH-NODE11-STABLE-PROMOTION-GATE.json','utf8'));
const candidateContract=JSON.parse(fs.readFileSync('RAH-NODE-REQUESTER-SOURCE-BINDING-CANDIDATE.json','utf8'));

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

function gitBlobSha(path){
  const body=fs.readFileSync(path);
  return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex');
}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}

test('release pins Stable CC 1.5 / Node 1.1 runtime and canonical contract',()=>{
  assert.equal(release.stage,'stable-release');
  assert.equal(release.authorityDelta,'none');
  assert.equal(release.ravenVersion,'2.0.32');
  assert.equal(release.commandCenterVersion,'1.5.0');
  assert.equal(release.nodeAgentVersion,'1.1.0');
  assert.equal(release.nodeHealthProtocol,'rah-node-health-v2');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v5');
  assert.equal(release.policyId,'rah-capability-allowlist-v1');
  for(const ref of Object.values(release.runtime))verify(ref);
});

test('release pins atomic Candidate implementation and readiness evidence',()=>{
  for(const ref of Object.values(release.pinnedImplementation))verify(ref);
  verify(release.readiness.manifest);
  assert.equal(readiness.targetStable.nodeAgentVersion,'1.1.0');
  assert.equal(readiness.targetStable.commandCenterVersion,'1.5.0');
  assert.equal(readiness.targetStable.nodeActionsProtocol,'rah-node-actions-v5');
  assert.equal(readiness.targetStable.policyId,'rah-capability-allowlist-v1');
});

test('direct rollback is CC 1.5 plus Node 1.0 with no migration',()=>{
  const rb=release.directRollback;
  for(const ref of [rb.commandCenterCore,rb.commandCenterHtml,rb.nodeAgent,rb.previousStableRelease])verify(ref);
  assert.equal(rb.commandCenterVersion,'1.5.0');
  assert.equal(rb.nodeAgentVersion,'1.0.0');
  assert.equal(rb.nodeHealthProtocol,'rah-node-health-v2');
  assert.equal(rb.nodeActionsProtocol,'rah-node-actions-v5');
  assert.equal(rb.policyId,'rah-capability-allowlist-v1');
  assert.equal(rb.dataMigration,'none');
  assert.equal(rb.secretMigration,'none');
  assert.equal(rb.registryMigration,'none');
});

test('release authority is exactly 4 capabilities, 3 actions and 5 routes',()=>{
  assert.deepEqual(release.authoritySurface,{capabilities:caps,actions,routes});
  assert.deepEqual(contract.capabilities,caps);
  assert.deepEqual(contract.actions.map(row=>row.id),actions);
  assert.deepEqual(contract.routes,routes);
  assert.deepEqual(candidateContract.authoritySurface,{capabilities:caps,actions,routes});
});

test('requester-source hardening is authority-neutral and atomically published',()=>{
  assert.equal(contract.approvalPolicy.requesterSourceOfTruth,'actual-server-socket-peer-ipv4');
  assert.deepEqual(contract.approvalPolicy.requesterSourceBindingRequiredFor,['rustdesk.launch','rustdesk.connect']);
  assert.equal(contract.approvalPolicy.requesterSourceIpv6Allowed,false);
  assert.equal(contract.approvalPolicy.trustForwardedRequesterHeaders,false);
  assert.equal(contract.approvalPolicy.wrongRequesterDoesNotConsumeValidPair,true);
  assert.equal(contract.approvalPolicy.atomicPairPublicationBeforeGrantSignal,true);
  assert.equal(contract.approvalPolicy.requesterSourcePersistence,'in-memory-active-pair-only');
  assert.equal(candidateContract.requesterSourcePolicy.atomicPairPublicationBeforeGrantSignal,true);
  assert.ok(contract.executionRequirements['mutating-fixed-actions'].includes('requester-source-matches-node-local-approval-pair'));
});

test('release keeps secret persistence and generic runtime authority forbidden',()=>{
  for(const key of ['bearer-token','action-challenge','node-local-approval-proof','password','rustdesk-peer-id'])assert.ok(release.forbiddenPersistence.includes(key));
  for(const key of ['shell','generic-command-execution','generic-process-launch','arbitrary-executable-path','arbitrary-arguments','generic-file-api','generic-endpoint-dispatch','generic-approval-endpoint','native-remote-control-api'])assert.ok(contract.forbiddenRuntimePower.includes(key));
  assert.equal(contract.tokenPolicy.networkRenewalEndpoint,'forbidden');
  assert.equal(release.freezeAfterPromotion,true);
});
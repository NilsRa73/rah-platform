import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';

const gate=JSON.parse(fs.readFileSync('RAH-NODE11-STABLE-PROMOTION-GATE.json','utf8'));
const stableRelease=JSON.parse(fs.readFileSync('RAH-CC15-NODE10-STABLE-RELEASE.json','utf8'));
const candidate=JSON.parse(fs.readFileSync('RAH-NODE-REQUESTER-SOURCE-BINDING-CANDIDATE.json','utf8'));
const canonical=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));

function gitBlobSha(path){
  const body=fs.readFileSync(path);
  return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex');
}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('readiness is authority-neutral and pins source Stable plus atomic Candidate evidence',()=>{
  assert.equal(gate.schemaVersion,1);
  assert.equal(gate.stage,'stable-readiness');
  assert.equal(gate.authorityDelta,'none');
  for(const ref of [gate.sourceStable.releaseManifest,gate.sourceStable.canonicalContract,gate.sourceStable.nodeAgent,gate.candidate.runtime,gate.candidate.contract])verify(ref);
});

test('promotion changes only Node Agent version while protocol, policy and CC stay fixed',()=>{
  assert.equal(gate.commandCenter.currentStableVersion,'1.5.0');
  assert.equal(gate.commandCenter.targetStableVersion,'1.5.0');
  assert.equal(gate.commandCenter.mustRemainUnchanged,true);
  assert.equal(gate.sourceStable.nodeAgentVersion,'1.0.0');
  assert.equal(gate.candidate.nodeAgentVersion,'1.1.0-candidate');
  assert.equal(gate.targetStable.nodeAgentVersion,'1.1.0');
  assert.equal(gate.sourceStable.nodeActionsProtocol,'rah-node-actions-v5');
  assert.equal(gate.candidate.nodeActionsProtocol,gate.sourceStable.nodeActionsProtocol);
  assert.equal(gate.targetStable.nodeActionsProtocol,gate.sourceStable.nodeActionsProtocol);
  assert.equal(gate.candidate.policyId,gate.sourceStable.policyId);
  assert.equal(gate.targetStable.policyId,gate.sourceStable.policyId);
});

test('authority remains exactly 4 capabilities, 3 actions and 5 routes',()=>{
  assert.deepEqual(gate.authoritySurface.capabilities,caps);
  assert.deepEqual(gate.authoritySurface.actions,actions);
  assert.deepEqual(gate.authoritySurface.routes,routes);
  assert.deepEqual(gate.authoritySurface,stableRelease.authoritySurface);
  assert.deepEqual(gate.authoritySurface,candidate.authoritySurface);
  assert.deepEqual(canonical.capabilities,caps);
  assert.deepEqual(canonical.actions.map(row=>row.id),actions);
  assert.deepEqual(canonical.routes,routes);
});

test('requester-source hardening is socket-derived, fail-closed and atomically published',()=>{
  const p=gate.securityDelta;
  assert.equal(p.type,'authority-neutral-hardening');
  assert.equal(p.requesterSourceTruth,'actual-server-socket-peer-ipv4');
  assert.equal(p.forwardedHeadersTrusted,false);
  assert.equal(p.pairRequiresRequesterSourceMatch,true);
  assert.equal(p.wrongRequesterDoesNotConsumeValidPair,true);
  assert.equal(p.atomicPairPublicationBeforeGrantSignal,true);
  assert.equal(candidate.requesterSourcePolicy.atomicPairPublicationBeforeGrantSignal,true);
  assert.equal(candidate.requesterSourcePolicy.trustXForwardedFor,false);
  assert.equal(candidate.requesterSourcePolicy.trustForwarded,false);
});

test('rollback is CC 1.5 plus Node 1.0 with no data, secret or registry migration',()=>{
  assert.equal(gate.rollback.commandCenterVersion,'1.5.0');
  assert.equal(gate.rollback.nodeAgentVersion,'1.0.0');
  assert.equal(gate.rollback.nodeActionsProtocol,'rah-node-actions-v5');
  assert.equal(gate.rollback.policyId,'rah-capability-allowlist-v1');
  assert.equal(gate.rollback.dataMigration,'none');
  assert.equal(gate.rollback.secretMigration,'none');
  assert.equal(gate.rollback.registryMigration,'none');
  assert.equal(stableRelease.nodeAgentVersion,'1.0.0');
});

test('readiness explicitly forbids generic authority and secret persistence',()=>{
  for(const forbidden of ['new-capabilities','new-actions','new-routes','generic-approval-endpoint','generic-command-execution','generic-process-launch','shell','generic-file-api','generic-endpoint-dispatch','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api','bearer-token-persistence','challenge-persistence','node-local-approval-proof-persistence','password-persistence','peer-id-persistence','network-token-renewal-endpoint']){
    assert.ok(gate.forbiddenExpansion.includes(forbidden),`missing forbidden boundary: ${forbidden}`);
  }
});
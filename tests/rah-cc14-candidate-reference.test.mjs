import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';

const ref=JSON.parse(fs.readFileSync('RAH-CC14-CANDIDATE-REFERENCE.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC14-STABLE-RELEASE.json','utf8'));

function gitBlobSha(path){
  const body=fs.readFileSync(path);
  return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex');
}
function verify(item){assert.equal(gitBlobSha(item.path),item.gitBlobSha,`${item.path} reference drifted`)}

test('reference sidecar marks Candidate lifecycle without authorizing runtime use',()=>{
  assert.equal(ref.schemaVersion,1);
  assert.equal(ref.stage,'promoted-reference');
  assert.equal(ref.referenceOnly,true);
  assert.equal(ref.candidateId,'rah-ephemeral-local-approval-v1');
  assert.equal(ref.runtimeUse,'forbidden-reference-only');
  assert.equal(ref.authorityDelta,'none');
});

test('reference sidecar pins the exact Stable release manifest and promotion commit',()=>{
  verify(ref.promotedTo.releaseManifest);
  assert.equal(ref.promotedTo.mainCommit,'6a37dd9e21be7d60e2c9397b91b598069b304c7e');
  assert.equal(ref.promotedTo.ravenVersion,'2.0.32');
  assert.equal(ref.promotedTo.commandCenterVersion,'1.4.0');
  assert.equal(ref.promotedTo.nodeAgentVersion,'0.9.0');
  assert.equal(release.commandCenterVersion,'1.4.0');
  assert.equal(release.nodeAgentVersion,'0.9.0');
});

test('Candidate source evidence remains byte-identical to Stable release references',()=>{
  for(const item of Object.values(ref.immutableCandidateEvidence))verify(item);
  assert.equal(ref.immutableCandidateEvidence.core.gitBlobSha,release.candidateReference.commandCenterCore.gitBlobSha);
  assert.equal(ref.immutableCandidateEvidence.html.gitBlobSha,release.candidateReference.commandCenterHtml.gitBlobSha);
  assert.equal(ref.immutableCandidateEvidence.contract.gitBlobSha,release.candidateReference.candidateContract.gitBlobSha);
  assert.equal(ref.immutableCandidateEvidence.readiness.gitBlobSha,release.candidateReference.readinessManifest.gitBlobSha);
});

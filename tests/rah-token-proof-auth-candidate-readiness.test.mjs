import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
const gate=JSON.parse(fs.readFileSync('RAH-TOKEN-PROOF-AUTH-CANDIDATE-GATE.json','utf8'));
const research=JSON.parse(fs.readFileSync('RAH-TOKEN-PROOF-AUTH-RESEARCH.json','utf8'));
const stable=JSON.parse(fs.readFileSync('RAH-CC16-NODE12-STABLE-RELEASE.json','utf8'));
function gitBlobSha(path){const body=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex')}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}

test('readiness authorizes only three versioned Candidate runtime files',()=>{
  assert.equal(gate.stage,'implementation-readiness');assert.equal(gate.authorityDelta,'none');assert.equal(gate.runtimeMutationAuthorized,true);assert.equal(gate.runtimeMutationScope,'versioned-candidate-files-only');
  assert.deepEqual(gate.authorizedCandidateFiles,['rah-command-center-core-v1.7-candidate.js','RAH-COMMAND-CENTER-V1.7-CANDIDATE.html','rah-node-agent-v1.3-candidate.py']);
  for(const forbidden of ['stable-runtime-mutation','canonical-root-package-mutation','raven-master-metadata-mutation'])assert.ok(gate.forbidden.includes(forbidden),forbidden);
});

test('readiness pins current Stable and all merged research evidence',()=>{
  verify(gate.sourceStable.stableRelease);for(const ref of Object.values(gate.researchEvidence))verify(ref);
  assert.equal(gate.sourceStable.commandCenterVersion,'1.6.0');assert.equal(gate.sourceStable.nodeAgentVersion,'1.2.0');assert.equal(gate.sourceStable.nodeActionsProtocol,'rah-node-actions-v6');
  assert.equal(gate.sourceStable.stableRelease.gitBlobSha,'c14719f9c4a2fbefad35fdd8d211df98a105ef89');assert.equal(stable.commandCenterVersion,'1.6.0');
  assert.equal(research.researchId,'rah-token-proof-auth-no-sixth-route-v2');assert.equal(research.runtimeMutationAuthorized,false);
});

test('authority remains exact and no sixth business route exists',()=>{
  assert.deepEqual(gate.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);assert.deepEqual(gate.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);assert.deepEqual(gate.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);assert.deepEqual(gate.authoritySurface.newBusinessRoutes,[]);
  assert.equal(gate.authBootstrap.path,'/health');assert.equal(gate.authBootstrap.method,'GET');assert.equal(gate.authBootstrap.header,'X-RAH-Auth-Init');assert.equal(gate.authBootstrap.normalHealthMetadataAllowed,false);
});

test('auth proof must precede every authority/action consume gate',()=>{
  assert.deepEqual(gate.requiredImplementationOrder,['cors-and-origin-boundary','reject-authorization-header-with-no-fallback','auth-init-or-token-proof-verification','fixed-request-shape-validation','existing-capability-action-session-policy-gates','node-local-human-confirmation-for-mutating-intent','requester-source-context-action-input-challenge-local-proof-consumption','fixed-action-effect']);
  for(const field of ['sessionId','nonce','httpMethod','exactBusinessPath','sha256ExactBodyBytes','approvalAction','approvalTarget','requesterContext','actionChallenge','nodeLocalApprovalProof'])assert.ok(gate.proofCanonicalFields.includes(field),field);
});

test('handoff body must be read once and proof/hash/parse identical bytes',()=>{
  assert.equal(gate.bodyHandling.handoff,'read-exact-bytes-once-cache-in-handler-proof-hash-then-parse-same-cached-bytes');assert.equal(gate.bodyHandling.doubleReadAllowed,false);assert.equal(gate.bodyHandling.transferEncodingAllowed,false);assert.equal(gate.bodyHandling.maxHandoffBytes,256);assert.equal(gate.bodyHandling.handoffSchema,'peerId-only-json');
});

test('nonce state and browser token handling are strictly bounded and no-fallback',()=>{
  assert.equal(gate.nonceState.memoryOnly,true);assert.equal(gate.nonceState.singleUse,true);assert.equal(gate.nonceState.ttlSeconds,30);assert.equal(gate.nonceState.maxOutstandingPerSource,8);assert.equal(gate.nonceState.maxOutstandingGlobal,64);assert.equal(gate.nonceState.wrongSourceConsumesNonce,false);assert.equal(gate.nonceState.correctSourceInvalidProofConsumesNonce,true);assert.equal(gate.nonceState.corsPreflightAllocatesNonce,false);
  assert.equal(gate.browserRequirements.webCryptoRequired,true);assert.equal(gate.browserRequirements.tokenNetworkTransport,false);assert.equal(gate.browserRequirements.bearerFallback,false);assert.equal(gate.browserRequirements.tokenPersistence,false);
});

test('existing independent action gates cannot be replaced by auth proof',()=>{
  for(const item of ['advertised-fixed-action','correct-capability','ephemeral-command-center-session-approval','node-session-match','exact-policy-id','node-local-human-confirmation','fresh-action-challenge','fresh-local-approval-proof','actual-requester-source-match','requester-context-match'])assert.ok(gate.existingIndependentGatesRetained.includes(item),item);
});

test('mandatory negative matrix covers bearer, nonce, tamper, ordering, body caching and protocol mismatch',()=>{
  for(const item of ['authorization-header-rejected-no-fallback','auth-init-health-does-not-return-normal-health-metadata','nonce-source-bound-single-use-bounded-and-expiring','wrong-source-does-not-consume-correct-nonce','invalid-proof-correct-source-consumes-nonce','proof-replay-rejected','method-path-body-tamper-rejected','approval-action-target-context-challenge-local-proof-tamper-rejected','proof-verification-precedes-action-challenge-or-local-pair-consumption','handoff-body-hashed-and-parsed-from-identical-cached-bytes','v16-bearer-client-to-node13-fails-closed','v17-proof-client-to-node12-fails-closed','options-never-allocates-nonce','no-new-capability-action-or-business-route'])assert.ok(gate.mandatoryNegativeTests.includes(item),item);
});

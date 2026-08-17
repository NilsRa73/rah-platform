import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';

const read = path => fs.readFileSync(path);
const json = path => JSON.parse(fs.readFileSync(path, 'utf8'));
const blobSha = bytes => crypto.createHash('sha1').update(Buffer.from(`blob ${bytes.length}\0`)).update(bytes).digest('hex');

const readiness = json('RAH-RAVEN-CARE-HUB-V0.5-STABLE-READINESS.json');
const rollbackManifestObject = json('RAH-RAVEN-CARE-HUB-V0.4-STABLE.json');
const candidateManifest = json('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.json');
const rollbackHtml = read('RAH-RAVEN-CARE-HUB-V0.4-STABLE.html');
const rollbackManifest = read('RAH-RAVEN-CARE-HUB-V0.4-STABLE.json');
const candidateHtml = read('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.html');
const candidateManifestBytes = read('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.json');

assert.equal(readiness.product, 'RAH Raven Care Hub');
assert.equal(readiness.stage, 'stable-readiness');
assert.equal(readiness.targetVersion, '0.5.0');
assert.equal(readiness.sourceCandidateVersion, '0.5.0-candidate');
assert.equal(readiness.sourceMainCommit, '755a66797d2c02e97679921000ea550abdf5d62b');
assert.equal(readiness.authorityDelta, 'none');
assert.equal(readiness.runtimeChangesInReadiness, false);
assert.equal(readiness.canonicalStableModifiedInReadiness, false);
assert.equal(readiness.stablePromotionIncluded, false);

// Historical readiness pins are validated against immutable versioned rollback/Candidate files,
// never against the mutable canonical Care Hub after a later Stable promotion.
assert.equal(rollbackManifestObject.version, '0.4.0');
assert.equal(rollbackManifestObject.stage, 'stable');
assert.equal(rollbackManifestObject.release_gate.status, 'passed');
assert.equal(rollbackManifestObject.release_gate.runtime_files_frozen, true);
assert.equal(rollbackManifestObject.development_paused, true);
assert.equal(candidateManifest.version, '0.5.0-candidate');
assert.equal(candidateManifest.stage, 'candidate');
assert.equal(candidateManifest.authority_delta, 'none');
assert.equal(candidateManifest.candidate_gate.stable_promotion_included, false);

assert.equal(blobSha(rollbackHtml), readiness.pins.currentStableHtml.gitBlob);
assert.equal(blobSha(rollbackManifest), readiness.pins.currentStableManifest.gitBlob);
assert.equal(blobSha(candidateHtml), readiness.pins.candidateHtml.gitBlob);
assert.equal(blobSha(candidateManifestBytes), readiness.pins.candidateManifest.gitBlob);

assert.equal(readiness.rollback.version, '0.4.0');
assert.equal(readiness.rollback.html, 'RAH-RAVEN-CARE-HUB-V0.4-STABLE.html');
assert.equal(readiness.rollback.manifest, 'RAH-RAVEN-CARE-HUB-V0.4-STABLE.json');
assert.equal(readiness.rollback.mustByteMatchCurrentCanonicalStable, true);
assert.equal(readiness.rollback.dataMigrationRequired, false);

assert.equal(readiness.promotionPlan.allowedCanonicalFilesChanged, 2);
assert.equal(readiness.promotionPlan.canonicalHtml, 'RAH-RAVEN-CARE-HUB.html');
assert.equal(readiness.promotionPlan.canonicalManifest, 'RAH-RAVEN-CARE-HUB-VERSION.json');
assert.equal(readiness.promotionPlan.preserveCandidateFiles, true);
assert.equal(readiness.promotionPlan.preserveRollbackFiles, true);
assert.equal(readiness.promotionPlan.preserveCareV0_1Stable, true);
assert.equal(readiness.promotionPlan.preserveCaseCenterV1_6Stable, true);
assert.equal(readiness.promotionPlan.preserveFristvaktV0_2Stable, true);
assert.equal(readiness.promotionPlan.preserveHealthFatigueV0_2Stable, true);
assert.equal(readiness.promotionPlan.preserveFastlegeV0_3Stable, true);
assert.equal(readiness.promotionPlan.preserveRavenStable, true);
assert.equal(readiness.promotionPlan.preserveCommandCenterNodeAuthority, true);
assert.equal(readiness.promotionPlan.stableHtmlAllowedDifferenceFromCandidate, 'stage-label-and-snapshot-version-only');
assert.equal(readiness.promotionPlan.stablePromotionRequiresSeparatePr, true);

assert.equal(readiness.securityBoundary.caseCenterNetwork, 'explicit-click-get-health-only');
assert.equal(readiness.securityBoundary.caseCenterOrigin, 'http://127.0.0.1:18765');
assert.deepEqual(readiness.securityBoundary.allowedNetworkPaths, ['/health']);
assert.equal(readiness.securityBoundary.fristvaktImport, 'explicit-user-selected-v0.2-json-only');
for (const key of ['browserPersistence','backgroundPolling','automaticSending','automaticCalling','medicalDecisionAutomation','legalDecisionAutomation','aiExecution','fileUploadToNetwork']) {
  assert.equal(readiness.securityBoundary[key], false, `${key} must remain false`);
}

console.log('Raven Care Hub v0.5 historical Stable readiness PASS');

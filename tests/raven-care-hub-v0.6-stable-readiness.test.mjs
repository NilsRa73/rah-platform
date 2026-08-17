import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';

const bytes=path=>fs.readFileSync(path);
const json=path=>JSON.parse(fs.readFileSync(path,'utf8'));
const blobSha=b=>crypto.createHash('sha1').update(Buffer.from(`blob ${b.length}\0`)).update(b).digest('hex');

const readiness=json('RAH-RAVEN-CARE-HUB-V0.6-STABLE-READINESS.json');
const stable=json('RAH-RAVEN-CARE-HUB-VERSION.json');
const candidate=json('RAH-RAVEN-CARE-HUB-V0.6-CANDIDATE.json');
const rollback=json('RAH-RAVEN-CARE-HUB-V0.5-STABLE.json');

assert.equal(readiness.product,'RAH Raven Care Hub');
assert.equal(readiness.stage,'stable-readiness');
assert.equal(readiness.targetVersion,'0.6.0');
assert.equal(readiness.sourceCandidateVersion,'0.6.0-candidate');
assert.equal(readiness.sourceCandidateCommit,'5bee67344faa15b1f70cf066c66a61c536963a22');
assert.equal(readiness.authorityDelta,'none');
assert.equal(readiness.runtimeChangesInReadiness,false);
assert.equal(readiness.canonicalStableModifiedInReadiness,false);
assert.equal(readiness.stablePromotionIncluded,false);
assert.equal(readiness.dataMigrationRequired,false);

assert.equal(stable.version,'0.5.0');
assert.equal(stable.stage,'stable');
assert.equal(stable.release_gate.status,'passed');
assert.equal(stable.release_gate.runtime_files_frozen,true);
assert.equal(stable.development_paused,true);
assert.equal(candidate.version,'0.6.0-candidate');
assert.equal(candidate.stage,'candidate');
assert.equal(candidate.authority_delta,'none');
assert.equal(candidate.candidate_gate.stable_promotion_included,false);
assert.equal(rollback.version,'0.5.0');
assert.equal(rollback.stage,'stable');

for(const [name,pin] of Object.entries(readiness.pins)){
  assert.equal(fs.existsSync(pin.path),true,`${name} path missing`);
  assert.equal(blobSha(bytes(pin.path)),pin.gitBlob,`${name} blob pin mismatch`);
}

assert.deepEqual(bytes('RAH-RAVEN-CARE-HUB-V0.5-STABLE.html'),bytes('RAH-RAVEN-CARE-HUB.html'),'v0.5 HTML rollback must byte-match canonical Stable during readiness');
assert.deepEqual(bytes('RAH-RAVEN-CARE-HUB-V0.5-STABLE.json'),bytes('RAH-RAVEN-CARE-HUB-VERSION.json'),'v0.5 manifest rollback must byte-match canonical Stable during readiness');
assert.equal(readiness.rollback.version,'0.5.0');
assert.equal(readiness.rollback.mustByteMatchCurrentCanonicalStable,true);
assert.equal(readiness.rollback.dataMigrationRequired,false);

const boundary=readiness.candidateBoundary;
assert.equal(boundary.caseCenterNetwork,'explicit-click-get-health-only');
assert.equal(boundary.caseCenterOrigin,'http://127.0.0.1:18765');
assert.deepEqual(boundary.allowedNetworkPaths,['/health']);
assert.equal(boundary.fristvaktImport,'explicit-user-selected-v0.2-schema1-json-only');
assert.equal(boundary.healthFatigueImport,'explicit-user-selected-v0.2-exact-csv-only');
assert.equal(boundary.healthFatigueMaxFileBytes,2097152);
assert.equal(boundary.healthFatigueMaxRows,2000);
assert.equal(boundary.healthFatigueRawRowsRetained,false);
assert.equal(boundary.snapshotContainsRawHealthRows,false);
assert.equal(boundary.healthSummaryDescriptiveOnly,true);
for(const key of ['medicalThresholds','diagnosticInference','treatmentRecommendations','doseRecommendations','causalityClaims','alerts','legalHealthCrossInference','browserPersistence','backgroundPolling','automaticSending','automaticCalling','aiExecution','fileUploadToNetwork','microphoneCapture','cameraCapture','sensorSync'])assert.equal(boundary[key],false,key);

const plan=readiness.promotionPlan;
assert.equal(plan.allowedCanonicalRuntimeFilesChanged,2);
assert.equal(plan.preserveCandidateFiles,true);
assert.equal(plan.preserveRollbackFiles,true);
assert.equal(plan.preserveHealthFatigueV0_2Stable,true);
assert.equal(plan.preserveCaseCenterV1_6Stable,true);
assert.equal(plan.preserveFristvaktV0_2Stable,true);
assert.equal(plan.preserveFastlegeV0_3Stable,true);
assert.equal(plan.preserveRavenCareV0_1Stable,true);
assert.equal(plan.preserveProjectRegistryRuntime,true);
assert.equal(plan.preserveRavenStable,true);
assert.equal(plan.preserveCommandCenterNodeAuthority,true);
assert.equal(plan.stablePromotionRequiresSeparatePr,true);

console.log('Raven Care Hub v0.6 Stable readiness PASS');

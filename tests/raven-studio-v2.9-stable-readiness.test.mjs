import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const readiness = JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-STABLE-READINESS.json','utf8'));
const candidate = JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json','utf8'));
const stable = JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-VERSION.json','utf8'));
const cc = JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const raven = JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));

const candidateHtml = fs.readFileSync('RAH-RAVEN-START-V2.9-CANDIDATE.html','utf8');
const acceptance = fs.readFileSync('ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.ps1','utf8');

test('Studio 2.9 readiness pins the current Candidate and frozen bases', () => {
  assert.equal(readiness.product, 'RAH Raven Studio');
  assert.equal(readiness.version, '2.9.0');
  assert.equal(readiness.review_type, 'stable-readiness');
  assert.equal(candidate.version, '2.9.0');
  assert.equal(candidate.stage, 'candidate');
  assert.equal(stable.version, '2.8.0');
  assert.equal(stable.stage, 'stable');
  assert.equal(stable.development_paused, true);
  assert.equal(stable.stable_release_gate.status, 'passed');
  assert.equal(cc.version, '2.3.0');
  assert.equal(cc.stage, 'stable');
  assert.equal(Number(cc.canonical_package_generation), 8);
  assert.equal(raven.version, '2.0.32');
});

test('Stable readiness preserves zero authority delta', () => {
  assert.equal(candidate.authority_delta, 'none');
  assert.equal(candidate.stable_runtime_files_modified, false);
  assert.equal(readiness.authority_delta, 'none');
  assert.equal(readiness.stable_runtime_files_modified, false);
  assert.equal(candidate.features.external_status_addresses_allowed, false);
  assert.equal(candidate.features.status_polling_loopback_only, true);
  assert.equal(candidate.features.automatic_actions, false);
  assert.equal(candidate.features.raven_state_writes, false);
  assert.equal(candidate.features.mission_mutation, false);
  assert.equal(candidate.features.agent_execution, false);
  assert.equal(candidate.features.shell_access, false);
  assert.equal(candidate.features.network_discovery, false);
  assert.equal(candidate.features.remote_control_authority, false);
});

test('Readiness never claims machine evidence or performs promotion', () => {
  assert.equal(readiness.owned_windows_acceptance_required, true);
  assert.equal(readiness.owned_windows_user_attestation_received, true);
  assert.equal(readiness.machine_readable_owned_windows_evidence_committed, false);
  assert.equal(readiness.promotion_included, false);
  assert.equal(readiness.candidate_can_promote_itself, false);
  assert.equal(readiness.stable_manifest_modified, false);
  assert.equal(readiness.stable_entry_modified, false);
  assert.equal(readiness.stable_promotion, 'BLOCKED');
  assert.equal(candidate.promotion_policy.stable_promotion_included, false);
  assert.equal(candidate.promotion_policy.candidate_can_promote_itself, false);
  assert.match(acceptance, /stablePromotion='BLOCKED'/);
  assert.match(acceptance, /stablePromotionAutomated=\$false/);
  assert.doesNotMatch(acceptance, /RAH-RAVEN-STUDIO-VERSION\.json[^\n]*Set-Content/i);
});

test('Candidate remains the reviewed runtime, not Stable 2.8 files', () => {
  assert.ok(candidateHtml.includes('127.0.0.1:18765'));
  assert.ok(candidateHtml.includes('127.0.0.1:1234'));
  assert.equal(readiness.candidate_entry, candidate.entry);
});

console.log('Raven Studio 2.9 Stable readiness: repo-side review PASS, promotion remains BLOCKED.');

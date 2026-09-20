import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const readiness=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-STABLE-READINESS.json','utf8'));
const legacy=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json','utf8'));
const stable3=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V3.0.json','utf8'));

test('Studio 2.9 Stable-readiness path is retired',()=>{
  assert.equal(readiness.version,'2.9.0');
  assert.equal(readiness.review_type,'retired-stable-readiness');
  assert.equal(readiness.owned_windows_acceptance_required,false);
  assert.equal(readiness.promotion_included,false);
  assert.equal(readiness.candidate_can_promote_itself,false);
  assert.equal(readiness.stable_promotion,'RETIRED');
  assert.equal(readiness.superseded_by.version,'3.0.0');
  assert.equal(readiness.superseded_by.release_gate,'passed');
});

test('Retirement points to a real Stable successor and preserves zero authority delta',()=>{
  assert.equal(legacy.stage,'retired');
  assert.equal(legacy.authority_delta,'none');
  assert.equal(readiness.authority_delta,'none');
  assert.equal(stable3.version,'3.0.0');
  assert.equal(stable3.stage,'stable');
  assert.equal(stable3.release_gate.status,'passed');
  assert.equal(stable3.features.automatic_mutating_actions,false);
});

console.log('Raven Studio 2.9 readiness: RETIRED; Studio 3.0 Stable is current.');

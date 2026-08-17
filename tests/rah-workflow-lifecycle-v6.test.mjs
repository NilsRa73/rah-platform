import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const historical=[
  '.github/workflows/validate-policy-id-candidate.yml',
  '.github/workflows/validate-ephemeral-approval-candidate.yml',
  '.github/workflows/validate-node11-stable-promotion.yml',
];

test('historical v4/v5 workflows are explicitly reference-only',()=>{
  for(const path of historical){
    const source=fs.readFileSync(path,'utf8');
    assert.match(source,/Historical Reference/);
    assert.doesNotMatch(source,/RAH-CAPABILITY-ALLOWLIST-CONTRACT\.json/);
    assert.doesNotMatch(source,/rah-capability-allowlist-contract\.test\.mjs/);
  }
});

test('historical workflows remain read-only and do not mutate runtime',()=>{
  for(const path of historical){
    const source=fs.readFileSync(path,'utf8');
    assert.match(source,/permissions:\s*\n\s*contents: read/);
    assert.doesNotMatch(source,/contents:\s*write/);
    assert.doesNotMatch(source,/pull-requests:\s*write/);
  }
});

test('current canonical and master-sync workflows own v6 validation',()=>{
  const canonical=fs.readFileSync('.github/workflows/validate-capability-allowlist-contract.yml','utf8');
  const sync=fs.readFileSync('.github/workflows/validate-cc161-node121-canonical-master-sync.yml','utf8');
  assert.match(canonical,/Validate Canonical Capability Allowlist Contract/);
  assert.match(canonical,/rah-capability-allowlist-contract\.test\.mjs/);
  assert.match(canonical,/rah-cc161-node121-stable-patch-release\.test\.mjs/);
  assert.match(sync,/Validate CC 1\.6\.1 Node 1\.2\.1 Canonical Master Sync/);
  assert.match(sync,/rah-capability-allowlist-contract\.test\.mjs/);
});

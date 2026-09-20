import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const bat=fs.readFileSync('ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.bat','utf8');
const ps1=fs.readFileSync('ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.ps1','utf8');
const legacy=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json','utf8'));
const stable3=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V3.0.json','utf8'));

test('Legacy Studio 2.9 launcher forwards only to the fixed compatibility wrapper',()=>{
  assert.match(bat,/ACCEPT-RAH-RAVEN-STUDIO-2\.9-CANDIDATE\.ps1/);
  assert.match(bat,/Studio 2\.9 has been superseded by Studio 3\.0 Stable/);
  assert.match(bat,/--self-test/);
  assert.doesNotMatch(bat,/desktop-bridge|18765|Invoke-RestMethod|start\s+"RAH Raven Desktop Bridge"/i);
});

test('Legacy PowerShell verifies retirement and forwards to Studio 3.0 Stable finalizer',()=>{
  assert.match(ps1,/RAH-RAVEN-STUDIO-V3\.0\.json/);
  assert.match(ps1,/RAH-RAVEN-STUDIO-FINAL\.ps1/);
  assert.match(ps1,/START-HER-RAH-RAVEN-STUDIO\.cmd/);
  assert.match(ps1,/stage -ne 'retired'/);
  assert.match(ps1,/release_gate\.status -ne 'passed'/);
  assert.doesNotMatch(ps1,/Invoke-RestMethod|Invoke-WebRequest|127\.0\.0\.1:18765|127\.0\.0\.1:1234/i);
  assert.doesNotMatch(ps1,/Set-Content|Remove-Item|Copy-Item|Move-Item/i);
});

test('Lifecycle cannot return Studio 2.9 to promotion review',()=>{
  assert.equal(legacy.stage,'retired');
  assert.equal(legacy.promotion_policy.retired_no_promotion,true);
  assert.equal(legacy.promotion_policy.candidate_can_promote_itself,false);
  assert.equal(stable3.stage,'stable');
  assert.equal(stable3.release_gate.status,'passed');
});

console.log('Raven Studio 2.9 legacy acceptance compatibility: PASS.');

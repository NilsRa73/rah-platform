import assert from 'node:assert/strict';
import fs from 'node:fs';

const ps1=fs.readFileSync('RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1','utf8');
const bat=fs.readFileSync('RAH-CANDIDATE-ACCEPTANCE-CENTER.bat','utf8');
const suite=fs.readFileSync('START-RAH-CANDIDATE-SUITE.bat','utf8');
const docs=fs.readFileSync('RAH-CANDIDATE-ACCEPTANCE-CENTER.md','utf8');

const studio29=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json','utf8'));
const studio30=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V3.0.json','utf8'));
const daily=JSON.parse(fs.readFileSync('RAH-RAVEN-DAILY-DRIVER-VERSION.json','utf8'));
const investigator=JSON.parse(fs.readFileSync('apps/rah-ai-investigator/RAH-INVESTIGATOR-VERSION.json','utf8'));

assert.equal(studio29.stage,'retired');
assert.equal(studio29.superseded_by.version,'3.0.0');
assert.equal(studio30.version,'3.0.0');
assert.equal(studio30.stage,'stable');
assert.equal(studio30.release_gate.status,'passed');
assert.equal(daily.stage,'stable');
assert.equal(daily.stable_gate.status,'passed');
assert.equal(investigator.stage,'stable');
assert.equal(investigator.validation.stable_release_gate,true);

assert.match(ps1,/No current Candidate in this owned-machine acceptance queue/);
assert.match(ps1,/No Candidate launcher is exposed while the queue is empty/);
assert.doesNotMatch(ps1,/ValidateSet|Invoke-TargetAcceptance|ACCEPT-RAH-RAVEN-STUDIO|ACCEPT-RAH-RAVEN-OWNED|ACCEPT-RC2/i);
assert.doesNotMatch(ps1,/Invoke-WebRequest|Invoke-RestMethod|Start-Process|Set-Content|Remove-Item|Copy-Item|Move-Item|Invoke-Expression|\biex\b/i);

assert.match(bat,/RAH-CANDIDATE-ACCEPTANCE-CENTER\.ps1/);
assert.match(suite,/RAH-CANDIDATE-ACCEPTANCE-CENTER\.ps1/);
assert.match(suite,/--self-test/);
assert.doesNotMatch(suite,/-Target|INSTALL-RAH-RAVEN|ACCEPT-RAH-RAVEN-STUDIO|ACCEPT-RC2/i);

assert.match(docs,/No current Candidate/i);
assert.match(docs,/Studio 2\.9.*Retired/i);
assert.match(docs,/Studio 3\.0.*Stable/i);
assert.match(docs,/Daily Driver 1\.0.*Stable/i);
assert.match(docs,/Investigator 1\.0.*Stable/i);

console.log('RAH Candidate Acceptance Center: empty queue is explicit and lifecycle-consistent.');

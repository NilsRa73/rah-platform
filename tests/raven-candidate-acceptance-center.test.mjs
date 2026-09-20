import assert from 'node:assert/strict';
import fs from 'node:fs';

const ps1=fs.readFileSync('RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1','utf8');
const bat=fs.readFileSync('RAH-CANDIDATE-ACCEPTANCE-CENTER.bat','utf8');
const suite=fs.readFileSync('START-RAH-CANDIDATE-SUITE.bat','utf8');
const docs=fs.readFileSync('RAH-CANDIDATE-ACCEPTANCE-CENTER.md','utf8');
const studio=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json','utf8'));
const daily=JSON.parse(fs.readFileSync('RAH-RAVEN-DAILY-DRIVER-VERSION.json','utf8'));
const investigator=JSON.parse(fs.readFileSync('apps/rah-ai-investigator/RAH-INVESTIGATOR-VERSION.json','utf8'));

assert.equal(studio.version,'2.9.0');
assert.equal(studio.stage,'candidate');
assert.equal(studio.promotion_policy.requires_owned_windows_runtime_test,true);
assert.equal(studio.promotion_policy.stable_promotion_included,false);
assert.equal(studio.promotion_policy.candidate_can_promote_itself,false);

assert.equal(daily.version,'1.0.0');
assert.equal(daily.stage,'stable');
assert.equal(daily.stable_gate.status,'passed');
assert.equal(investigator.version,'1.0.0');
assert.equal(investigator.stage,'stable');
assert.equal(investigator.validation.stable_release_gate,true);

assert.match(ps1,/ValidateSet\('studio'\)/);
assert.match(ps1,/ACCEPT-RAH-RAVEN-STUDIO-2\.9-CANDIDATE\.bat/);
assert.match(ps1,/RAH-RAVEN-STUDIO-V2\.9-CANDIDATE\.json/);
assert.match(ps1,/Promotion = 'BLOCKED'/);
assert.match(ps1,/Stable-promotion boundary is no longer fail-closed/);
assert.match(ps1,/if \(\$SelfTest\)/);
assert.doesNotMatch(ps1,/Id\s*=\s*'daily-driver'|Id\s*=\s*'investigator'/i);
assert.doesNotMatch(ps1,/ACCEPT-RAH-RAVEN-OWNED-MACHINE|ACCEPT-RC2-OWNED-WINDOWS/i);

assert.match(bat,/RAH-CANDIDATE-ACCEPTANCE-CENTER\.ps1/);
assert.match(bat,/Stable promotion is ALWAYS blocked/);

assert.match(suite,/set "CENTER_PS1=%~dp0RAH-CANDIDATE-ACCEPTANCE-CENTER\.ps1"/);
assert.match(suite,/if \/I "%~1"=="--self-test"/);
assert.match(suite,/-File "%CENTER_PS1%" -SelfTest/);
assert.match(suite,/-Target studio/);
assert.match(suite,/Daily Driver 1\.0 and AI Investigator 1\.0 are Stable/);
assert.match(suite,/Stable promotion remains BLOCKED/);
assert.doesNotMatch(suite,/INSTALL-RAH-RAVEN|ensure_daily_driver|-Target daily-driver|-Target investigator/i);

assert.match(docs,/cannot promote Stable/);
assert.match(docs,/START-RAH-CANDIDATE-SUITE\.bat/);
assert.match(docs,/one ZIP/i);
assert.match(docs,/Studio 2\.9 Candidate/);
assert.match(docs,/Daily Driver 1\.0.*Stable/i);
assert.match(docs,/AI Investigator 1\.0.*Stable/i);

const forbidden=[
  /Invoke-WebRequest/i,/Invoke-RestMethod/i,/Start-BitsTransfer/i,/System\.Net\.WebClient/i,
  /Set-Content/i,/Add-Content/i,/Out-File/i,/Remove-Item/i,/Move-Item/i,/Copy-Item/i,/New-Item/i,
  /Invoke-Expression/i,/\biex\b/i,/Start-Process/i,/git\s+push/i,/gh\s+pr/i,/gh\s+api/i
];
for(const pattern of forbidden) assert.doesNotMatch(ps1,pattern,'Acceptance Center must remain read-only/fixed-launcher only: '+pattern);

assert.doesNotMatch(ps1,/Read-Host[^\n]*(path|sti|launcher|script|command|kommando)/i,'Interactive input must not become arbitrary path/command authority.');
assert.doesNotMatch(suite,/\bstart\s+"?[^\r\n]*\.exe/i,'Suite starter must not become a generic executable launcher.');
assert.doesNotMatch(suite,/\bcmd\s+\/c/i,'Suite starter must not delegate arbitrary commands through cmd /c.');
assert.doesNotMatch(suite,/powershell\.exe[^\r\n]*(Invoke-Expression|iex)/i,'Suite starter must not add dynamic PowerShell execution.');

console.log('RAH Candidate Acceptance Center: Studio 2.9 is the only current Candidate; Stable products are excluded.');

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
assert.equal(daily.stage,'candidate');
assert.equal(daily.stable_gate.status,'not_passed');
assert.equal(daily.stable_gate.requires_windows_runtime,true);
assert.equal(daily.security_boundary.runtime_acceptance_can_promote_stable,false);

assert.equal(investigator.version,'1.0-RC2');
assert.equal(investigator.stage,'candidate');
assert.equal(investigator.owned_windows_acceptance.can_only_mark_eligible_for_stable_review,true);
assert.equal(investigator.owned_windows_acceptance.can_promote_stable,false);
assert.equal(investigator.validation.stable_release_gate,false);

for(const required of [
  'ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.bat',
  'ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat',
  'apps/rah-ai-investigator/ACCEPT-RC2-OWNED-WINDOWS.bat',
  'RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json',
  'RAH-RAVEN-DAILY-DRIVER-VERSION.json',
  'apps/rah-ai-investigator/RAH-INVESTIGATOR-VERSION.json'
]) assert.match(ps1,new RegExp(required.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')));

assert.match(ps1,/ValidateSet\('studio','daily-driver','investigator'\)/);
assert.match(ps1,/Promotion = 'BLOCKED'/);
assert.match(ps1,/Stable-promotion boundary is no longer fail-closed/);
assert.match(ps1,/if \(\$SelfTest\)/);
assert.match(bat,/RAH-CANDIDATE-ACCEPTANCE-CENTER\.ps1/);
assert.match(bat,/Stable promotion is ALWAYS blocked/);

assert.match(suite,/set "INSTALLER=%~dp0INSTALL-RAH-RAVEN\.bat"/);
assert.match(suite,/set "CENTER_PS1=%~dp0RAH-CANDIDATE-ACCEPTANCE-CENTER\.ps1"/);
assert.match(suite,/if \/I "%~1"=="--self-test"/);
assert.match(suite,/-File "%CENTER_PS1%" -SelfTest/);
assert.match(suite,/:run_studio/);
assert.match(suite,/:run_daily/);
assert.match(suite,/:run_investigator/);
assert.match(suite,/:ensure_daily_driver/);
assert.match(suite,/-Target studio/);
assert.match(suite,/-Target daily-driver/);
assert.match(suite,/-Target investigator/);
assert.match(suite,/call :ensure_daily_driver/);
assert.match(suite,/set "RAH_RAVEN_INSTALL_NO_START=1"/);
assert.match(suite,/call "%INSTALLER%"/);
assert.match(suite,/Setup runs only because Daily Driver was selected/);
assert.match(suite,/Stable promotion remains BLOCKED/);

const studioStart=suite.indexOf(':run_studio');
const dailyStart=suite.indexOf(':run_daily');
const investigatorStart=suite.indexOf(':run_investigator');
const afterRun=suite.indexOf(':after_run');
const ensureDaily=suite.lastIndexOf(':ensure_daily_driver');
const installerCall=suite.indexOf('call "%INSTALLER%"');
assert.ok(studioStart>=0 && dailyStart>studioStart && investigatorStart>dailyStart && afterRun>investigatorStart && ensureDaily>afterRun,'Fixed target labels must remain ordered and explicit.');
assert.ok(installerCall>ensureDaily,'Daily Driver installer must only be reachable through the Daily Driver setup subroutine.');
assert.doesNotMatch(suite.slice(studioStart,dailyStart),/INSTALLER|ensure_daily_driver/i,'Studio selection must not install Daily Driver.');
assert.doesNotMatch(suite.slice(investigatorStart,afterRun),/INSTALLER|ensure_daily_driver/i,'Investigator selection must not install Daily Driver.');

assert.doesNotMatch(suite,/\bstart\s+"?[^\r\n]*\.exe/i,'Suite starter must not become a generic executable launcher.');
assert.doesNotMatch(suite,/\bcmd\s+\/c/i,'Suite starter must not delegate arbitrary commands through cmd /c.');
assert.doesNotMatch(suite,/powershell\.exe[^\r\n]*(Invoke-Expression|iex)/i,'Suite starter must not add dynamic PowerShell execution.');

assert.match(docs,/cannot promote Stable/);
assert.match(docs,/START-RAH-CANDIDATE-SUITE\.bat/);
assert.match(docs,/one ZIP/i);

const forbidden=[
  /Invoke-WebRequest/i,/Invoke-RestMethod/i,/Start-BitsTransfer/i,/System\.Net\.WebClient/i,
  /Set-Content/i,/Add-Content/i,/Out-File/i,/Remove-Item/i,/Move-Item/i,/Copy-Item/i,/New-Item/i,
  /Invoke-Expression/i,/\biex\b/i,/Start-Process/i,/git\s+push/i,/gh\s+pr/i,/gh\s+api/i
];
for(const pattern of forbidden) assert.doesNotMatch(ps1,pattern,`Acceptance Center must remain read-only/fixed-launcher only: ${pattern}`);

assert.doesNotMatch(ps1,/Read-Host[^\n]*(path|sti|launcher|script|command|kommando)/i,'Interactive input must not become arbitrary path/command authority.');
console.log('RAH Candidate Acceptance Center: three fixed Candidate targets, target-specific Daily Driver setup, manifest drift guards and Stable-promotion block are enforced.');

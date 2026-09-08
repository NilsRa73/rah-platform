import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const wheel = fs.readFileSync('RAH-RAVEN-COMMAND-WHEEL.html', 'utf8');

test('Command Wheel HOVED-PC controls are fixed read-only Agent Runner capabilities', () => {
  assert.match(wheel, /HOVED-PC Kontroll/);
  assert.match(wheel, /id="quickRun" disabled/);
  assert.match(wheel, /id="localRun"[^>]*disabled/);
  assert.match(wheel, /id="quickChatGPT"[^>]*disabled/);
  assert.match(wheel, /\/agent\/capabilities/);
  assert.match(wheel, /\/agent\/run/);
  assert.match(wheel, /\/agent\/chatgpt\/quick-check/);
  assert.match(wheel, /x\.id==='system-inventory'/);
  assert.match(wheel, /x\.id==='hovedpc-local-status'/);
  assert.match(wheel, /d\.mode==='read-only-allowlist'/);
  assert.match(wheel, /d\.arbitrary_commands===false/);
  assert.match(wheel, /d\.file_writes===false/);
  assert.match(wheel, /d\.automatic_execution===false/);
  assert.match(wheel, /quick\.read_only!==true/);
  assert.match(wheel, /quick\.requires_confirmation!==true/);
  assert.match(wheel, /local\.read_only===true/);
  assert.match(wheel, /local\.requires_confirmation===true/);
  assert.match(wheel, /JSON\.stringify\(\{capability:id,confirm:true\}\)/);
  assert.match(wheel, /quickRun\.addEventListener\('click',\(\)=>runCapability\('system-inventory','Quick Check'\)\)/);
  assert.match(wheel, /localRun\.addEventListener\('click',\(\)=>runCapability\('hovedpc-local-status','HOVED-PC Lokalstatus'\)\)/);
  assert.match(wheel, /JSON\.stringify\(\{confirm:true\}\)/);
  assert.match(wheel, /d\.delivery!=='composer-draft-only'/);
  assert.match(wheel, /d\.read_only!==true/);
  assert.match(wheel, /d\.files_modified!==false/);
  assert.match(wheel, /d\.automatic_actions!==false/);
  assert.match(wheel, /d\.auto_send!==false/);
  assert.match(wheel, /Raven fyller inn utkastet; du trykker Send/);
});

test('HOVED-PC controls have no user-supplied command surface or automatic execution', () => {
  assert.doesNotMatch(wheel, /<input/i);
  assert.doesNotMatch(wheel, /<textarea/i);
  assert.doesNotMatch(wheel, /cmd\.exe/i);
  assert.doesNotMatch(wheel, /powershell\s+-command/i);
  assert.doesNotMatch(wheel, /shell\s*[:=]\s*true/i);
  assert.doesNotMatch(wheel, /setInterval\([^)]*(quickRun|localRun|quickChatGPT)\.click/i);
  assert.doesNotMatch(wheel, /DOMContentLoaded[^\n]*(quickRun|localRun|quickChatGPT)\.click/i);
});

console.log('Raven Command Wheel HOVED-PC controls are explicit-click, fixed-capability, draft-only and read-only.');

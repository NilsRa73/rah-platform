import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const wheel = fs.readFileSync('RAH-RAVEN-COMMAND-WHEEL.html', 'utf8');

test('Command Wheel HOVED-PC Quick Check is fixed to read-only system inventory', () => {
  assert.match(wheel, /HOVED-PC Quick Check/);
  assert.match(wheel, /id="quickRun" disabled/);
  assert.match(wheel, /id="quickChatGPT"[^>]*disabled/);
  assert.match(wheel, /\/agent\/capabilities/);
  assert.match(wheel, /\/agent\/run/);
  assert.match(wheel, /\/agent\/chatgpt\/quick-check/);
  assert.match(wheel, /x\.id==='system-inventory'/);
  assert.match(wheel, /d\.mode!==['"]read-only-allowlist['"]/);
  assert.match(wheel, /d\.arbitrary_commands!==false/);
  assert.match(wheel, /d\.file_writes!==false/);
  assert.match(wheel, /d\.automatic_execution!==false/);
  assert.match(wheel, /cap\.read_only!==true/);
  assert.match(wheel, /cap\.requires_confirmation!==true/);
  assert.match(wheel, /JSON\.stringify\(\{capability:'system-inventory',confirm:true\}\)/);
  assert.match(wheel, /JSON\.stringify\(\{confirm:true\}\)/);
  assert.match(wheel, /d\.delivery!=='composer-draft-only'/);
  assert.match(wheel, /d\.read_only!==true/);
  assert.match(wheel, /d\.files_modified!==false/);
  assert.match(wheel, /d\.automatic_actions!==false/);
  assert.match(wheel, /d\.auto_send!==false/);
  assert.match(wheel, /Raven auto-sender aldri meldingen/);
});

test('Quick Check has no user-supplied command surface or automatic execution', () => {
  assert.doesNotMatch(wheel, /<input/i);
  assert.doesNotMatch(wheel, /<textarea/i);
  assert.doesNotMatch(wheel, /cmd\.exe/i);
  assert.doesNotMatch(wheel, /powershell\s+-command/i);
  assert.doesNotMatch(wheel, /shell\s*[:=]\s*true/i);
  assert.doesNotMatch(wheel, /setInterval\([^)]*quickRun\.click/i);
  assert.doesNotMatch(wheel, /setInterval\([^)]*quickChatGPT\.click/i);
  assert.doesNotMatch(wheel, /DOMContentLoaded[^\n]*(quickRun|quickChatGPT)\.click/i);
});

console.log('Raven Command Wheel Quick Check is explicit-click, fixed-capability, draft-only and read-only.');

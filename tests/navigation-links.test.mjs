import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL('../' + path, import.meta.url), 'utf8');

test('Desktop Bridge exposes local Command Wheel and Agent Runner UI routes', () => {
  const bridge = read('desktop-bridge/raven_bridge.py');
  assert.match(bridge, /@app\.get\("\/command-wheel\/ui"\)/);
  assert.match(bridge, /return _send_local_page\(COMMAND_WHEEL_UI\)/);
  assert.match(bridge, /@app\.get\("\/agent\/ui"\)/);
  assert.match(bridge, /return _send_local_page\(AGENT_RUNNER_UI\)/);
  // User-interface routes may be opened without weakening protected local APIs.
  assert.match(bridge, /"\/command-wheel\/ui",/);
  assert.match(bridge, /"\/agent\/ui",/);
  assert.match(bridge, /PROTECTED_LOCAL_PREFIXES/);
});

test('Doctor navigates to actual Command Wheel UI route', () => {
  const doctor = read('RAH-RAVEN-DOCTOR.html');
  assert.match(doctor, /href="\/command-wheel\/ui"/);
  assert.doesNotMatch(doctor, /href="RAH-RAVEN-COMMAND-WHEEL\.html"/);
});

test('Command Wheel navigates to local Agent Runner', () => {
  const wheel = read('RAH-RAVEN-COMMAND-WHEEL.html');
  assert.match(wheel, /href="http:\/\/127\.0\.0\.1:18765\/agent\/ui"/);
  assert.doesNotMatch(wheel, /href="RAH-RAVEN-AGENT-RUNNER\.html"/);
});

test('Agent Runner navigates locally without redirecting to nonexistent bridge files', () => {
  const runner = read('RAH-RAVEN-AGENT-RUNNER.html');
  assert.match(runner, /href="http:\/\/127\.0\.0\.1:18765\/command-wheel\/ui"/);
  assert.doesNotMatch(runner, /href="RAH-RAVEN-START\.html"/);
  assert.doesNotMatch(runner, /href="RAH-RAVEN-MISSION-CONTROL\.html"/);
});

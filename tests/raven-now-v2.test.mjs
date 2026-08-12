import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-NOW-V2.html','utf8');

assert.match(html,/RAH Raven Now v2/);
assert.match(html,/v2 · READ ONLY/);
assert.match(html,/Dagens viktigste mission/);
assert.match(html,/Tre nylige prosjekter/);
assert.match(html,/Systemstatus/);
assert.match(html,/id="continueButton"/);
assert.match(html,/>▶ FORTSETT</);
assert.match(html,/id="todayMission"/);
assert.match(html,/id="todayProgress"/);
assert.match(html,/id="recentProjects"/);
assert.match(html,/id="bridgeState"/);
assert.match(html,/id="chronicleState"/);
assert.match(html,/id="lmState"/);
assert.match(html,/id="agentRunnerState"/);
assert.match(html,/rah\.command\.center/);
assert.match(html,/rah\.raven\.agent\.runner\.history\.v1/);
assert.match(html,/\/chronicle\/brief\?hours=24/);
assert.match(html,/RAH-RAVEN-MISSION-CONTROL\.html/);
assert.match(html,/RAH-RAVEN-START\.html/);
assert.match(html,/function recentProjects\(s,m\)/);
assert.match(html,/function completion\(m\)/);
assert.match(html,/function nextStep\(m\)/);
assert.match(html,/Raven Now v2 er fortsatt skrivebeskyttet/);

// Dashboard is strictly read-only. State-changing operations remain elsewhere.
assert.doesNotMatch(html,/localStorage\.setItem\(STATE_KEY/);
assert.doesNotMatch(html,/function completeStep\s*\(/);
assert.doesNotMatch(html,/step\.done\s*=\s*true/);
assert.doesNotMatch(html,/status\s*=\s*['"]COMPLETED['"]/);
assert.doesNotMatch(html,/\/agent\/run/);
assert.doesNotMatch(html,/createChronicleMission/);

console.log('Raven Now v2 personal dashboard semantics passed.');

import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-PROJECT.html','utf8');

assert.match(html,/RAH Raven Project Focus v2\.1/);
assert.match(html,/Project Focus/);
assert.match(html,/rah\.command\.center/);
assert.match(html,/URLSearchParams/);
assert.match(html,/params\.get\('index'\)/);
assert.match(html,/RAH-RAVEN-NOW-V2\.html/);
assert.match(html,/RAH-RAVEN-MISSION-CONTROL\.html/);
assert.match(html,/id="activateProject"/);
assert.match(html,/Gjør dette til aktivt prosjekt/);
assert.match(html,/confirm\(/);
assert.match(html,/s\.activeProject=index/);
assert.match(html,/project-activation/);
assert.match(html,/Aktiv mission beholdes uendret/);
assert.match(html,/Ingen mission-steg markeres ferdig/);
assert.match(html,/location\.href='RAH-RAVEN-NOW-V2\.html\?projectActivated=1'/);
assert.match(html,/prosjektet vises som AKTIVT/);

// Explicit activation may change activeProject and log activity only.
// It must never replace or complete the active mission.
assert.match(html,/localStorage\.setItem\(STATE_KEY/);
assert.doesNotMatch(html,/\bs\.activeMission\s*=(?!=)/);
assert.doesNotMatch(html,/\bstate\.activeMission\s*=(?!=)/);
assert.doesNotMatch(html,/step\.done\s*=\s*true/);
assert.doesNotMatch(html,/status\s*=\s*['"]COMPLETED['"]/);
assert.doesNotMatch(html,/\/agent\/run/);
assert.doesNotMatch(html,/createChronicleMission/);

console.log('Raven Project Focus v2.1 explicit activation and return flow passed.');

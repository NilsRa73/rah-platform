import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-PROJECT.html','utf8');

assert.match(html,/RAH Raven Project Focus v2/);
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

// Project activation is explicit and narrow: it may change activeProject and log activity,
// but must never replace/complete an active mission or execute Agent actions.
assert.match(html,/localStorage\.setItem\(STATE_KEY/);
assert.doesNotMatch(html,/s\.activeMission\s*=/);
assert.doesNotMatch(html,/state\.activeMission\s*=/);
assert.doesNotMatch(html,/step\.done\s*=\s*true/);
assert.doesNotMatch(html,/status\s*=\s*['"]COMPLETED['"]/);
assert.doesNotMatch(html,/\/agent\/run/);
assert.doesNotMatch(html,/createChronicleMission/);

console.log('Raven Project Focus v2 explicit activation safety passed.');

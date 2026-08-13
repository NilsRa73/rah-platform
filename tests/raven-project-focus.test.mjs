import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-PROJECT.html','utf8');

assert.match(html,/RAH Raven Project Focus v2\.3/);
assert.match(html,/Project Focus/);
assert.match(html,/rah\.command\.center/);
assert.match(html,/URLSearchParams/);
assert.match(html,/params\.get\('index'\)/);
assert.match(html,/storedActive/);
assert.match(html,/rawIndex===null\|\|rawIndex===''/);
assert.match(html,/requestedIndex=rawIndex===null\|\|rawIndex===''\?storedActive:Number\(rawIndex\)/);
assert.match(html,/Åpner aktivt prosjekt automatisk|Åpner aktivt prosjekt/);
assert.match(html,/RAH-RAVEN-NOW-V2\.html/);
assert.match(html,/RAH-RAVEN-MISSION-CONTROL\.html/);
assert.match(html,/id="activateProject"/);
assert.match(html,/Gjør dette til aktivt prosjekt/);
assert.match(html,/id="missionReconcile"/);
assert.match(html,/id="missionProjectLink"/);
assert.match(html,/Vis missionens prosjekt/);
assert.match(html,/missionProjectIndex/);
assert.match(html,/projects\.findIndex/);
assert.match(html,/canShowMissionProject/);
assert.match(html,/RAH-RAVEN-PROJECT\.html\?index=\$\{missionProjectIndex\}/);
assert.match(html,/Dette er missionens prosjekt/);
assert.match(html,/samkjøre Project Brain med missionen/);
assert.match(html,/confirm\(/);
assert.match(html,/s\.activeProject=index/);
assert.match(html,/project-activation/);
assert.match(html,/Mission «\$\{m\.title\|\|'Aktiv mission'\}» blir IKKE endret/);
assert.match(html,/Ingen mission-steg markeres ferdig/);
assert.match(html,/location\.href='RAH-RAVEN-NOW-V2\.html\?projectActivated=1'/);
assert.match(html,/Dette er aktivt prosjekt/);
assert.match(html,/Ingen Project Brain-prosjekter ennå/);

// Reconciliation is navigation only. Explicit activation may change activeProject and log activity only.
assert.match(html,/localStorage\.setItem\(STATE_KEY/);
assert.doesNotMatch(html,/\bs\.activeMission\s*=(?!=)/);
assert.doesNotMatch(html,/\bstate\.activeMission\s*=(?!=)/);
assert.doesNotMatch(html,/step\.done\s*=\s*true/);
assert.doesNotMatch(html,/status\s*=\s*['"]COMPLETED['"]/);
assert.doesNotMatch(html,/\/agent\/run/);
assert.doesNotMatch(html,/createChronicleMission/);

console.log('Raven Project Focus v2.3 mission-project reconciliation and explicit activation passed.');

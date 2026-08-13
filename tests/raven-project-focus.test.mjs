import assert from 'node:assert/strict';
import fs from 'node:fs';

const html=fs.readFileSync('RAH-RAVEN-PROJECT.html','utf8');
const policy=fs.readFileSync('raven-checkpoint-policy.js','utf8');

assert.match(html,/RAH Raven Project Focus v2\.4/);
assert.match(html,/Project Focus/);
assert.match(html,/rah\.command\.center/);
assert.match(html,/URLSearchParams/);
assert.match(html,/params\.get\('index'\)/);
assert.match(html,/storedActive=Checkpoint\.activeProjectIndex\(s\)/);
assert.match(html,/rawIndex===null\|\|rawIndex===''/);
assert.match(html,/requestedIndex=rawIndex===null\|\|rawIndex===''\?storedActive:Number\(rawIndex\)/);
assert.match(html,/Åpner aktivt prosjekt automatisk|Åpner aktivt prosjekt/);
assert.match(html,/RAH-RAVEN-NOW-V2\.html/);
assert.match(html,/RAH-RAVEN-MISSION-CONTROL\.html/);
assert.match(html,/<script src="raven-checkpoint-policy\.js"><\/script>/);
assert.match(html,/const Checkpoint=window\.RAHCheckpointPolicy/);
assert.match(html,/Checkpoint\.projectMissionRelation\(s,m,index\)/);
assert.match(html,/Checkpoint\.missionOpen\(m\)/);
assert.match(html,/relation\.missionIndex/);
assert.match(html,/relation\.missionProject/);
assert.match(html,/relation\.status/);
assert.match(html,/relation\.detail/);
assert.match(html,/relation\.missionProjectHref/);
assert.doesNotMatch(html,/projects\.findIndex\(/);
assert.match(html,/id="activateProject"/);
assert.match(html,/Gjør dette til aktivt prosjekt/);
assert.match(html,/id="missionReconcile"/);
assert.match(html,/id="missionProjectLink"/);
assert.match(html,/Vis missionens prosjekt/);
assert.match(html,/canShowMissionProject/);
assert.match(html,/Dette er missionens prosjekt/);
assert.match(html,/samkjøre Project Brain med missionen/);
assert.match(html,/confirm\(/);
assert.match(html,/s\.activeProject=index/);
assert.match(html,/project-activation/);
assert.match(html,/blir IKKE endret/);
assert.match(html,/Ingen mission-steg markeres ferdig/);
assert.match(html,/location\.href='RAH-RAVEN-NOW-V2\.html\?projectActivated=1'/);
assert.match(html,/Dette er aktivt prosjekt/);
assert.match(html,/Ingen Project Brain-prosjekter ennå/);
assert.match(policy,/function projectMissionRelation\(/);
assert.match(policy,/✓ SAMME PROSJEKT/);
assert.match(policy,/⚠ ULIKT PROSJEKT/);
assert.match(policy,/MISSIONSPROSJEKT IKKE FUNNET/);

// Reconciliation is navigation only. Explicit activation may change activeProject and log activity only.
assert.match(html,/localStorage\.setItem\(STATE_KEY/);
assert.doesNotMatch(html,/\bs\.activeMission\s*=(?!=)/);
assert.doesNotMatch(html,/\bstate\.activeMission\s*=(?!=)/);
assert.doesNotMatch(html,/step\.done\s*=\s*true/);
assert.doesNotMatch(html,/status\s*=\s*['"]COMPLETED['"]/);
assert.doesNotMatch(html,/\/agent\/run/);
assert.doesNotMatch(html,/createChronicleMission/);

console.log('Raven Project Focus v2.4 shared project-mission relation and explicit activation passed.');

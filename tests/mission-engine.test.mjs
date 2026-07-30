import assert from 'node:assert/strict';
import fs from 'node:fs';

const engine = fs.readFileSync('mission-engine.js', 'utf8');
const html = fs.readFileSync('index.html', 'utf8');

assert.match(engine, /RAH Mission Engine v1\.5/);
assert.match(engine, /function ensureMissionShape/);
assert.match(engine, /function startStep/);
assert.match(engine, /function completeStep/);
assert.match(engine, /function finishMission/);
assert.match(engine, /appendBrainNote/);
assert.match(engine, /Mission gjenopprettet etter oppstart/);
assert.match(engine, /window\.rahMission/);
assert.match(html, /mission-engine\.js\?v=1\.5/);
assert.match(html, /cloud-sync\.js\?v=1\.0/);
assert.ok(html.indexOf('cloud-sync.js?v=1.0') < html.indexOf('mission-engine.js?v=1.5'), 'cloud sync must load before mission engine');

console.log('Mission Engine v1.5 validation passed.');

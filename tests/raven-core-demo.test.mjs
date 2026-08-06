import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-CORE-DEMO.html', 'utf8');
const vision = fs.readFileSync('raven-vision-core.js', 'utf8');
const council = fs.readFileSync('raven-council.js', 'utf8');
const bridge = fs.readFileSync('desktop-bridge/raven_bridge.py', 'utf8');

assert.match(html, /Vision → Project Brain → Council → Mission Control/);
assert.match(html, /raven-vision-core\.js\?v=0\.1/);
assert.match(html, /raven-council\.js\?v=0\.1/);
assert.match(html, /rah\.raven\.vision\.core\.history\.v1/);
assert.match(html, /rah\.raven\.council\.history\.v1/);
assert.match(html, /rah\.command\.center/);
assert.match(html, /http:\/\/127\.0\.0\.1:18765/);
assert.match(html, /applyVisionToRahState/);
assert.match(html, /applyRecordToRahState/);
assert.match(html, /attachMission: true/);
assert.match(html, /En aktiv mission finnes allerede/);
assert.match(html, /Automatiske risikohandlinger: NEI/);
assert.match(html, /Bilder lagret i Brain: NEI/);

assert.match(vision, /imageStored: false/);
assert.match(council, /buildPlanningMission/);
assert.match(bridge, /@app\.post\("\/lm\/chat"\)/);

console.log('Raven Core end-to-end demo validation passed.');

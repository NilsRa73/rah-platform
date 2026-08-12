import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-NOW.html', 'utf8');

assert.match(html, /RAH Raven Now v1/);
assert.match(html, /sist jobbet med → siste resultat → neste steg → blokkering/i);
assert.match(html, /v1 · READ ONLY/);
assert.match(html, /rah\.command\.center/);
assert.match(html, /rah\.raven\.agent\.runner\.history\.v1/);
assert.match(html, /\/chronicle\/brief\?hours=24/);
assert.match(html, /id="workedTitle"/);
assert.match(html, /id="resultTitle"/);
assert.match(html, /id="nextTitle"/);
assert.match(html, /id="blockerTitle"/);
assert.match(html, /RAH-RAVEN-MISSION-CONTROL\.html/);
assert.match(html, /RAH-RAVEN-COUNCIL\.html/);
assert.match(html, /RAH-RAVEN-AGENT-RUNNER\.html/);
assert.match(html, /RAH-RAVEN-DAILY-BRIEF\.html/);
assert.match(html, /Raven Now er skrivebeskyttet/);
assert.match(html, /kan ikke fullføre steg/);
assert.match(html, /function nextStep\(m\)/);
assert.match(html, /function bestResult\(m,agent\)/);
assert.match(html, /function latestActivity\(s,m,agent\)/);
assert.match(html, /function chronicleLoop\(\)/);

// Raven Now must remain a read-only overview. Completion belongs to Mission Control.
assert.doesNotMatch(html, /function completeStep\s*\(/);
assert.doesNotMatch(html, /step\.done\s*=\s*true/);
assert.doesNotMatch(html, /status\s*=\s*['"]COMPLETED['"]/);
assert.doesNotMatch(html, /localStorage\.setItem\(STATE_KEY/);
assert.doesNotMatch(html, /\/agent\/run/);
assert.doesNotMatch(html, /createChronicleMission/);

console.log('Raven Now v1 unified read-only workline semantics passed.');

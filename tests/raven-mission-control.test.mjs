import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-MISSION-CONTROL.html', 'utf8');

assert.match(html, /RAH Raven Mission Control v2/);
assert.match(html, /Ett prosjekt\. Ett neste steg\./);
assert.match(html, /rah\.command\.center/);
assert.match(html, /id="projectName"/);
assert.match(html, /id="nextTitle"/);
assert.match(html, /id="lastResult"/);
assert.match(html, /id="blockerText"/);
assert.match(html, /id="openNext"/);
assert.match(html, /id="completeNext"/);
assert.match(html, /id="recordResult"/);
assert.match(html, /id="setBlocker"/);
assert.match(html, /Marker faktisk ferdig/);
assert.match(html, /Å åpne et verktøy teller ikke lenger som fullført arbeid/);
assert.match(html, /function openStep\(index\)/);
assert.match(html, /function completeStep\(index\)/);
assert.match(html, /function recordResult\(\)/);
assert.match(html, /function setBlocker\(\)/);
assert.match(html, /step\.done=true/);
assert.match(html, /step\.lastOpenedAt=now\(\)/);
assert.match(html, /historyRecorded/);
assert.match(html, /RAH-RAVEN-VISION-CORE\.html/);
assert.match(html, /RAH-RAVEN-CORE-DEMO\.html/);

const openStepBody = html.match(/function openStep\(index\)\{([\s\S]*?)\n  \}\n  function recordHistory/)?.[1] || '';
assert.ok(openStepBody, 'openStep body missing');
assert.doesNotMatch(openStepBody, /step\.done\s*=\s*true/);

const completeStepBody = html.match(/function completeStep\(index\)\{([\s\S]*?)\n  \}\n  function recordResult/)?.[1] || '';
assert.ok(completeStepBody, 'completeStep body missing');
assert.match(completeStepBody, /step\.done=true/);
assert.match(completeStepBody, /blockerText\(m\)/);

console.log('Raven Mission Control v2 validation passed.');

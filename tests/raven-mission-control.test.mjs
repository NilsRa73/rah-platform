import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-MISSION-CONTROL.html', 'utf8');
const studio = fs.readFileSync('RAH-RAVEN-START.html', 'utf8');
const core = fs.readFileSync('RAH-RAVEN-CORE-DEMO.html', 'utf8');

assert.match(html, /RAH Raven Mission Control v2\.1/);
assert.match(html, /Ett prosjekt\. Ett neste steg\./);
assert.match(html, /rah\.command\.center/);
assert.match(html, /rah\.raven\.agent\.runner\.history\.v1/);
assert.match(html, /id="resumeTitle"/);
assert.match(html, /id="resumeButton"/);
assert.match(html, /id="resumeReason"/);
assert.match(html, /id="councilState"/);
assert.match(html, /id="agentState"/);
assert.match(html, /id="projectName"/);
assert.match(html, /id="nextTitle"/);
assert.match(html, /id="lastResult"/);
assert.match(html, /id="blockerText"/);
assert.match(html, /id="openNext"/);
assert.match(html, /id="completeNext"/);
assert.match(html, /id="recordResult"/);
assert.match(html, /id="setBlocker"/);
assert.match(html, /Marker faktisk ferdig/);
assert.match(html, /Council og Agent-resultater brukes bare som lokal kontekst/);
assert.match(html, /function latestCouncil\(\)/);
assert.match(html, /function latestAgent\(\)/);
assert.match(html, /function renderResume\(m,next,blocker,council,agent\)/);
assert.match(html, /function createCouncilMission\(record\)/);
assert.match(html, /function openStep\(index\)/);
assert.match(html, /function completeStep\(index\)/);
assert.match(html, /function recordResult\(\)/);
assert.match(html, /function setBlocker\(\)/);
assert.match(html, /step\.done=true/);
assert.match(html, /step\.lastOpenedAt=now\(\)/);
assert.match(html, /historyRecorded/);
assert.match(html, /RAH-RAVEN-VISION-CORE\.html/);
assert.match(html, /RAH-RAVEN-AGENT-RUNNER\.html/);
assert.match(html, /RAH-RAVEN-COUNCIL\.html/);
assert.match(html, /RAH-RAVEN-CORE-DEMO\.html/);

const openStepBody = html.match(/function openStep\(index\)\{([\s\S]*?)\n  \}\n  function recordHistory/)?.[1] || '';
assert.ok(openStepBody, 'openStep body missing');
assert.doesNotMatch(openStepBody, /step\.done\s*=\s*true/);

const completeStepBody = html.match(/function completeStep\(index\)\{([\s\S]*?)\n  \}\n  function recordResult/)?.[1] || '';
assert.ok(completeStepBody, 'completeStep body missing');
assert.match(completeStepBody, /step\.done=true/);
assert.match(completeStepBody, /blockerText\(m\)/);

const resumeBody = html.match(/function renderResume\(m,next,blocker,council,agent\)\{([\s\S]*?)\n  \}\n  function render\(\)/)?.[1] || '';
assert.ok(resumeBody, 'renderResume body missing');
assert.match(resumeBody, /latest Agent-resultat|Agent-resultat|Agent Runner/);
assert.doesNotMatch(resumeBody, /\.done\s*=\s*true/);
assert.doesNotMatch(resumeBody, /status\s*=\s*["']COMPLETED["']/);

const councilMissionBody = html.match(/function createCouncilMission\(record\)\{([\s\S]*?)\n  \}\n  function agentIsRecorded/)?.[1] || '';
assert.ok(councilMissionBody, 'createCouncilMission body missing');
assert.match(councilMissionBody, /replaceGuard\(\)/);
assert.match(councilMissionBody, /councilId/);

// Mission Control remains the primary Mission entry from both Studio and Core.
assert.match(studio, /mission:\{name:'Mission Control',url:'RAH-RAVEN-MISSION-CONTROL\.html'\}/);
assert.match(studio, /href="RAH-RAVEN-MISSION-CONTROL\.html">🎯 Mission Control v2/);
assert.match(core, /href="RAH-RAVEN-MISSION-CONTROL\.html">Åpne Mission/);
assert.doesNotMatch(studio, /index\.html#missions/);
assert.doesNotMatch(core, /index\.html#missions/);

console.log('Raven Mission Control v2.1 resume context and explicit-completion semantics passed.');

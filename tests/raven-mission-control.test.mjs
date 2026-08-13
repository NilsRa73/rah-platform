import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-MISSION-CONTROL.html', 'utf8');
const studio = fs.readFileSync('RAH-RAVEN-START.html', 'utf8');
const core = fs.readFileSync('RAH-RAVEN-CORE-DEMO.html', 'utf8');
const agent = fs.readFileSync('RAH-RAVEN-AGENT-RUNNER.html', 'utf8');

assert.match(html, /RAH Raven Mission Control v2\.3/);
assert.match(html, /Ett prosjekt\. Ett neste steg\./);
assert.match(html, /rah\.command\.center/);
assert.match(html, /rah\.raven\.agent\.runner\.history\.v1/);
assert.match(html, /id="resumeTitle"/);
assert.match(html, /id="resumeButton"/);
assert.match(html, /id="resumeReason"/);
assert.match(html, /id="councilState"/);
assert.match(html, /id="agentState"/);
assert.match(html, /id="chronicleState"/);
assert.match(html, /id="chronicleText"/);
assert.match(html, /id="projectName"/);
assert.match(html, /id="missionName"/);
assert.match(html, /id="projectMissionState"/);
assert.match(html, /id="projectMissionDetail"/);
assert.match(html, /id="projectFocusLink"/);
assert.match(html, /RAH-RAVEN-PROJECT\.html/);
assert.match(html, /SAMME PROSJEKT/);
assert.match(html, /ULIKT PROSJEKT/);
assert.match(html, /Ingen automatisk bytting/);
assert.match(html, /function missionMatchesProject\(project,m\)/);
assert.match(html, /function renderProjectMissionRelation\(project,m\)/);
assert.match(html, /renderProjectMissionRelation\(project,m\)/);
assert.match(html, /id="nextTitle"/);
assert.match(html, /id="lastResult"/);
assert.match(html, /id="blockerText"/);
assert.match(html, /id="openNext"/);
assert.match(html, /id="completeNext"/);
assert.match(html, /id="recordResult"/);
assert.match(html, /id="setBlocker"/);
assert.match(html, /Marker faktisk ferdig/);
assert.match(html, /Council, Agent Runner og Chronicle \/ Daily Brief brukes bare som lokal kontekst/);
assert.match(html, /function latestCouncil\(\)/);
assert.match(html, /function latestAgent\(\)/);
assert.match(html, /function loadChronicleContext\(\)/);
assert.match(html, /\/chronicle\/brief\?hours=24/);
assert.match(html, /function latestChronicleLoop\(\)/);
assert.match(html, /function renderResume\(m,next,blocker,council,agent,chronicle\)/);
assert.match(html, /function createCouncilMission\(record\)/);
assert.match(html, /function createChronicleMission\(loop\)/);
assert.match(html, /presetId:"chronicle-resume"/);
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
assert.match(html, /RAH-RAVEN-DAILY-BRIEF\.html/);
assert.match(html, /RAH-RAVEN-CORE-DEMO\.html/);
assert.match(html, /RAH-RAVEN-NOW-V2\.html/);

const relationBody = html.match(/function renderProjectMissionRelation\(project,m\)\{([\s\S]*?)\}\n\n  async function loadChronicleContext/)?.[1] || '';
assert.ok(relationBody, 'project/mission relationship body missing');
assert.match(relationBody, /SAMME PROSJEKT/);
assert.match(relationBody, /ULIKT PROSJEKT/);
assert.doesNotMatch(relationBody, /activeProject\s*=/);
assert.doesNotMatch(relationBody, /activeMission\s*=/);
assert.doesNotMatch(relationBody, /\.done\s*=\s*true/);

const openStepBody = html.match(/function openStep\(index\)\{([\s\S]*?)\n  \}\n  function recordHistory/)?.[1] || '';
assert.ok(openStepBody, 'openStep body missing');
assert.doesNotMatch(openStepBody, /step\.done\s*=\s*true/);

const completeStepBody = html.match(/function completeStep\(index\)\{([\s\S]*?)\n  \}\n  function recordResult/)?.[1] || '';
assert.ok(completeStepBody, 'completeStep body missing');
assert.match(completeStepBody, /step\.done=true/);
assert.match(completeStepBody, /blockerText\(m\)/);
assert.match(completeStepBody, /confirm\(/);

const resumeBody = html.match(/function renderResume\(m,next,blocker,council,agent,chronicle\)\{([\s\S]*?)\n  \}\n\n  function render\(\)/)?.[1] || '';
assert.ok(resumeBody, 'renderResume body missing');
assert.match(resumeBody, /CHRONICLE \/ DAILY BRIEF/);
assert.match(resumeBody, /Agent Runner/);
assert.doesNotMatch(resumeBody, /\.done\s*=\s*true/);
assert.doesNotMatch(resumeBody, /status\s*=\s*["']COMPLETED["']/);

const chronicleMissionBody = html.match(/function createChronicleMission\(loop\)\{([\s\S]*?)\n  \}\n  function agentIsRecorded/)?.[1] || '';
assert.ok(chronicleMissionBody, 'createChronicleMission body missing');
assert.match(chronicleMissionBody, /replaceGuard\(\)/);
assert.match(chronicleMissionBody, /chronicleSource/);
assert.doesNotMatch(chronicleMissionBody, /done:true/);

assert.match(studio, /mission:\{name:'Mission Control',url:'RAH-RAVEN-MISSION-CONTROL\.html'\}/);
assert.match(studio, /href="RAH-RAVEN-MISSION-CONTROL\.html">🎯 Mission Control v2/);
assert.match(core, /href="RAH-RAVEN-MISSION-CONTROL\.html">Åpne Mission/);
assert.match(agent, /href="RAH-RAVEN-MISSION-CONTROL\.html">Mission Control v2/);
assert.doesNotMatch(studio, /index\.html#missions/);
assert.doesNotMatch(core, /index\.html#missions/);
assert.doesNotMatch(agent, /index\.html#missions/);

assert.match(agent, /read-only-allowlist/);
assert.match(agent, /automatic_execution!==false/);
assert.match(agent, /confirm:true/);
assert.match(agent, /Ingen vilkårlig kommando/);

console.log('Raven Mission Control v2.3 project/mission relationship passed.');

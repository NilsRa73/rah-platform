import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-NOW-V2.html','utf8');

assert.match(html,/RAH Raven Now v2/);
assert.match(html,/v2\.3 · READ ONLY/);
assert.match(html,/Dagens viktigste mission/);
assert.match(html,/Project Switcher/);
assert.match(html,/Systemstatus/);
assert.match(html,/id="continueButton"/);
assert.match(html,/id="continueContext"/);
assert.match(html,/FORTSETT velger neste kontrollpunkt/);
assert.match(html,/FORTSETT MISSION/);
assert.match(html,/FORTSETT PROSJEKT/);
assert.match(html,/LØS BLOKKERING/);
assert.match(html,/VELG MISSION/);
assert.match(html,/function missionOpen\(m\)/);
assert.match(html,/function missionMatchesProject\(m,activeIndex,active\)/);
assert.match(html,/function updateContinue\(m,block,activeIndex,active\)/);
assert.match(html,/button\.href='RAH-RAVEN-MISSION-CONTROL\.html'/);
assert.match(html,/button\.href=`RAH-RAVEN-PROJECT\.html\?index=\$\{activeIndex\}`/);
assert.match(html,/De er ikke samme prosjekt; FORTSETT åpner missionen uten å bytte prosjekt/);
assert.match(html,/Ingen uferdig aktiv mission\. FORTSETT åpner Project Focus/);
assert.match(html,/id="todayMission"/);
assert.match(html,/id="todayProgress"/);
assert.match(html,/id="recentProjects"/);
assert.match(html,/id="activeProjectBadge"/);
assert.match(html,/active-tag/);
assert.match(html,/AKTIVT/);
assert.match(html,/id="activationNotice"/);
assert.match(html,/projectActivated/);
assert.match(html,/id="bridgeState"/);
assert.match(html,/id="chronicleState"/);
assert.match(html,/id="lmState"/);
assert.match(html,/id="agentRunnerState"/);
assert.match(html,/rah\.command\.center/);
assert.match(html,/rah\.raven\.agent\.runner\.history\.v1/);
assert.match(html,/\/chronicle\/brief\?hours=24/);
assert.match(html,/RAH-RAVEN-MISSION-CONTROL\.html/);
assert.match(html,/RAH-RAVEN-START\.html/);
assert.match(html,/RAH-RAVEN-PROJECT\.html\?index=/);
assert.match(html,/data-project-index=/);
assert.match(html,/function activeProjectIndex\(s\)/);
assert.match(html,/function recentProjects\(s,m\)/);
assert.match(html,/add\(active\);add\(missionProject\)/);
assert.match(html,/Raven Now v2 er fortsatt skrivebeskyttet/);

// Raven Now stays strictly read-only. FORTSETT only changes navigation target/text.
assert.doesNotMatch(html,/localStorage\.setItem\(STATE_KEY/);
assert.doesNotMatch(html,/\bs\.activeProject\s*=(?!=)/);
assert.doesNotMatch(html,/\bstate\.activeProject\s*=(?!=)/);
assert.doesNotMatch(html,/function completeStep\s*\(/);
assert.doesNotMatch(html,/step\.done\s*=\s*true/);
assert.doesNotMatch(html,/status\s*=\s*['"]COMPLETED['"]/);
assert.doesNotMatch(html,/\/agent\/run/);
assert.doesNotMatch(html,/createChronicleMission/);

console.log('Raven Now v2.3 project-aware read-only FORTSETT passed.');

import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync('raven-council.js', 'utf8');
const html = fs.readFileSync('RAH-RAVEN-COUNCIL.html', 'utf8');
const bridge = fs.readFileSync('desktop-bridge/raven_bridge.py', 'utf8');
const context = { console, structuredClone, Date, globalThis: {} };
context.globalThis = context;
vm.runInNewContext(source, context, { filename: 'raven-council.js' });
const core = context.RavenCouncilCore;

assert.ok(core, 'Council core must be exported');
assert.equal(core.VERSION, '0.1.0');
assert.deepEqual(Array.from(core.ROLE_ORDER), ['archivist', 'planner', 'builder', 'reviewer', 'safety']);
assert.match(core.ROLES.safety.system, /godkjenning/i);
assert.equal(core.buildRoleMessages('planner', { goal: 'Bygg en test', context: 'index.html' }).length, 2);

const plan = core.parseNumberedPlan('Beslutning\n1. Finn gjeldende fil\n2. Kjør test\n3. Lagre resultat', 5);
assert.deepEqual(Array.from(plan), ['Finn gjeldende fil', 'Kjør test', 'Lagre resultat']);

const record = core.createCouncilRecord(
  { goal: 'Fullfør Council', project: 'RAH', maxSteps: 3 },
  { archivist: 'A', planner: '1. Planlegg', builder: 'B', reviewer: 'R', safety: 'S' },
  '1. Lag kjernen\n2. Test den\n3. Koble Mission Control',
  'local-model'
);
const mission = core.buildPlanningMission(record);
assert.equal(mission.status, 'RUNNING');
assert.equal(mission.presetId, 'raven-council-planning');
assert.ok(mission.steps.some(step => step.action === 'save-mission-result'));
assert.ok(mission.steps.some(step => step.action === 'create-project-task'));
assert.ok(mission.steps.some(step => step.action === 'open-brain'));

const state = core.applyRecordToRahState({ brain: 'Eksisterende', activity: [] }, record, { attachMission: true });
assert.match(state.brain, /Raven Council/);
assert.equal(state.activeMission.councilId, record.id);
assert.equal(state.councilHistory.length, 1);

assert.match(html, /Raven Council v0\.2/);
assert.match(html, /raven-council\.js\?v=0\.1/);
assert.match(html, /Send plan til Mission Control/);
assert.match(html, /http:\/\/127\.0\.0\.1:18765/);
assert.match(html, /\/lm\/models/);
assert.match(html, /\/lm\/chat/);
assert.match(html, /tools_executed !== false/);
assert.match(html, /automatic_actions !== false/);
assert.doesNotMatch(html, /127\.0\.0\.1:1234/);

assert.match(bridge, /@app\.post\("\/lm\/chat"\)/);
assert.match(bridge, /"tools_executed": False/);
assert.match(bridge, /"automatic_actions": False/);
assert.match(bridge, /"null",\s+# Local file:\/\/ Raven pages\./);

console.log('Raven Council v0.2 Bridge validation passed.');

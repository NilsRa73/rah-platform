import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync('raven-council.js', 'utf8');
const html = fs.readFileSync('RAH-RAVEN-COUNCIL.html', 'utf8');
const bridge = fs.readFileSync('desktop-bridge/raven_bridge.py', 'utf8');
const context = { console, structuredClone, Date, URL, globalThis: {} };
context.globalThis = context;
vm.runInNewContext(source, context, { filename: 'raven-council.js' });
const core = context.RavenCouncilCore;

assert.ok(core, 'Council core must be exported');
assert.equal(core.VERSION, '0.3.0');
assert.deepEqual(Array.from(core.ROLE_ORDER), ['archivist', 'planner', 'builder', 'reviewer', 'safety']);

assert.equal(core.DEFAULT_BRIDGE_BASE, 'http://127.0.0.1:18765');
for (const url of ['http://127.0.0.1:18765','http://localhost:18765','http://[::1]:18765']) assert.doesNotThrow(() => core.normalizeBridgeBase(url));
for (const url of ['https://example.com','http://192.168.1.5:18765','file:///tmp/council','javascript:alert(1)']) assert.throws(() => core.normalizeBridgeBase(url), /lokal loopback|HTTP på lokal loopback/);
const endpoints=core.endpoints('http://127.0.0.1:18765/');
assert.equal(endpoints.health,'http://127.0.0.1:18765/health');
assert.equal(endpoints.models,'http://127.0.0.1:18765/lm/models');
assert.equal(endpoints.chat,'http://127.0.0.1:18765/lm/chat');
assert.match(html, /Kun lokal loopback er tillatt/);
assert.match(html, /Eksterne adresser blokkeres før nettverkskall/);
assert.match(html, /CORE\.normalizeBridgeBase/);
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

assert.match(html, /Raven Council v0\.3/);
assert.match(html, /raven-council\.js\?v=0\.3/);
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

const componentManifest=JSON.parse(fs.readFileSync('RAH-RAVEN-COUNCIL-VERSION.json','utf8'));
assert.equal(componentManifest.product,'RAH Raven Council');
assert.equal(componentManifest.version,'0.3.0');
assert.equal(componentManifest.stage,'stable');
assert.equal(componentManifest.helper_version,'0.3.0');
assert.equal(componentManifest.runtime_feature_change,false);
assert.equal(componentManifest.development_paused,true);
assert.equal(componentManifest.change_policy,'bugfix-only-until-explicit-reopen');
assert.equal(componentManifest.features.local_bridge_only,true);
assert.equal(componentManifest.features.external_bridge_addresses_allowed,false);
assert.equal(componentManifest.features.bridge_tools_executed,false);
assert.equal(componentManifest.features.bridge_automatic_actions,false);
assert.equal(componentManifest.features.project_brain_write_requires_explicit_click,true);
assert.equal(componentManifest.features.mission_handoff_requires_explicit_click,true);
assert.equal(componentManifest.stable_release_gate?.status,'passed');
assert.equal(componentManifest.stable_release_gate?.runtime_files_frozen,true);
assert.equal(componentManifest.next_milestone,null);
console.log('Raven Council v0.3 Stable Gate: local boundary, explicit handoff and frozen runtime contract passed.');

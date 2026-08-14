import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync('raven-chronicle-sync.js', 'utf8');
const page = fs.readFileSync('RAH-RAVEN-MEMORY-SYNC.html', 'utf8');
const context = { console, globalThis: {} };
context.globalThis = context;
vm.runInNewContext(source, context, { filename: 'raven-chronicle-sync.js' });
const core = context.RavenChronicleSyncCore;

assert.ok(core);
assert.equal(core.VERSION, '0.1.0');
assert.equal(core.SYNC_KEY, 'rah.raven.chronicle.sync.v1');

const vision = core.visionEvent({ id: 'v1', source: 'Aktivt vindu', model: 'vision-model', createdAt: '2026-08-06', prompt: 'SECRET PROMPT', answer: 'SECRET ANSWER', image: 'SECRET IMAGE' });
const council = core.councilEvent({ id: 'c1', project: 'RAH', model: 'text-model', createdAt: '2026-08-06', goal: 'SECRET GOAL', chair: 'SECRET CHAIR', roles: { planner: 'SECRET ROLE' }, plan: ['one'] });
const agent = core.agentEvent({ id: 'a1', title: 'Test Council', ok: true, time: '2026-08-06', durationMs: 10, readOnly: true, filesModified: false, stdout: 'SECRET STDOUT', stderr: 'SECRET STDERR' });
const mission = core.missionEvent({ id: 'm1', title: 'SECRET MISSION', status: 'RUNNING', steps: [{ title: 'SECRET STEP' }], updatedAt: '2026-08-06', results: [{ body: 'SECRET RESULT' }] });

const serialized = JSON.stringify([vision, council, agent, mission]);
for (const secret of ['SECRET PROMPT', 'SECRET ANSWER', 'SECRET IMAGE', 'SECRET GOAL', 'SECRET CHAIR', 'SECRET ROLE', 'SECRET STDOUT', 'SECRET STDERR', 'SECRET MISSION', 'SECRET STEP', 'SECRET RESULT']) {
  assert.doesNotMatch(serialized, new RegExp(secret));
}
assert.match(vision.note, /Bilde lagret: nei/);
assert.match(council.note, /modellsvaret lagret i Chronicle: nei/i);
assert.match(agent.note, /Kommando-output og feillogg lagret i Chronicle: nei/);
assert.match(mission.note, /Mission-tittel, oppgaveinnhold og resultater lagret i Chronicle: nei/);
assert.equal(core.unsynced([vision, council], [vision.local_id]).length, 1);
assert.deepEqual(Object.keys(core.toChroniclePayload(vision)).sort(), ['category', 'note', 'privacy', 'project', 'title']);
assert.equal(core.toChroniclePayload(vision).privacy, 'private');

assert.match(page, /Raven Memory Sync v0\.2/);
assert.match(page, /\/chronicle\/event/);
assert.match(page, /rah\.raven\.vision\.core\.history\.v1/);
assert.match(page, /rah\.raven\.council\.history\.v1/);
assert.match(page, /rah\.raven\.agent\.runner\.history\.v1/);
assert.match(page, /Jeg bekrefter/);
assert.match(page, /Ingen innholdstekster ble sendt/);
assert.doesNotMatch(page, /automatic.*sync/i);

console.log('Raven Chronicle Memory Sync privacy validation passed.');

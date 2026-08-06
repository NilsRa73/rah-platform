import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync('raven-vision-core.js', 'utf8');
const html = fs.readFileSync('RAH-RAVEN-VISION-CORE.html', 'utf8');
const context = { console, structuredClone, Date, globalThis: {} };
context.globalThis = context;
vm.runInNewContext(source, context, { filename: 'raven-vision-core.js' });
const core = context.RavenVisionCore;

assert.ok(core);
assert.equal(core.VERSION, '0.1.0');
assert.equal(core.DEFAULT_BRIDGE_BASE, 'http://127.0.0.1:18765');
const endpoints = core.endpoints('http://127.0.0.1:18765/');
assert.equal(endpoints.health, 'http://127.0.0.1:18765/health');
assert.equal(endpoints.captureActiveWindow, 'http://127.0.0.1:18765/capture/active-window');
assert.equal(endpoints.captureAfterDelay(99), 'http://127.0.0.1:18765/capture/after-delay?seconds=10');
assert.equal(endpoints.models, 'http://127.0.0.1:18765/lm/models');
assert.equal(endpoints.analyze, 'http://127.0.0.1:18765/lm/analyze');

const record = core.createVisionRecord({ source: 'Aktivt vindu', prompt: 'Les', answer: 'Svar', model: 'vision-model', metadata: { width: 100 } });
assert.equal(record.imageStored, false);
const state = core.applyVisionToRahState({ brain: 'Fra før', activity: [], activeMission: { title: 'Test', results: [], logs: [], currentStep: 0 } }, record);
assert.match(state.brain, /Raven Vision/);
assert.equal(state.visionHistory.length, 1);
assert.equal(state.activeMission.results[0].visionId, record.id);
assert.equal(state.activeMission.logs[0].stepIndex, 0);

assert.match(html, /http:\/\/127\.0\.0\.1:18765/);
assert.match(source, /capture\/active-window/);
assert.match(source, /\/lm\/analyze/);
assert.match(html, /Bildet ble ikke lagret/);
assert.doesNotMatch(html, /127\.0\.0\.1:8765/);

console.log('Raven Vision Core v0.1 validation passed.');

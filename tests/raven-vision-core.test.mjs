import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync('raven-vision-core.js', 'utf8');
const html = fs.readFileSync('RAH-RAVEN-VISION-CORE.html', 'utf8');
const context = { console, structuredClone, Date, URL, globalThis: {} };
context.globalThis = context;
vm.runInNewContext(source, context, { filename: 'raven-vision-core.js' });
const core = context.RavenVisionCore;

assert.ok(core);
assert.equal(core.VERSION, '0.6.0');
assert.equal(core.DEFAULT_BRIDGE_BASE, 'http://127.0.0.1:18765');

assert.equal(core.isLoopbackBase('http://127.0.0.1:18765'), true);
assert.equal(core.isLoopbackBase('http://localhost:18765'), true);
assert.equal(core.isLoopbackBase('http://[::1]:18765'), true);
assert.equal(core.isLoopbackBase('https://example.com'), false);
assert.equal(core.isLoopbackBase('http://192.168.1.10:18765'), false);
assert.throws(() => core.endpoints('https://example.com'), /lokal loopback-adresse/);
assert.throws(() => core.endpoints('http://192.168.1.10:18765'), /lokal loopback-adresse/);
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

assert.match(html, /RAH Raven Vision Core v0\.6/);
assert.match(html, /<span class="badge">v0\.6<\/span>/);
assert.match(html, /DEL SISTE BILDE MED CHATGPT/);
for (const id of ['shareChatGPT','chatgptSharePanel','copyImage','downloadPng','returnHandoffCore','shareStatus']) assert.match(html, new RegExp(`id="${id}"`));
assert.match(html, /Ingenting sendes automatisk\. Lim inn i ChatGPT med Ctrl\+V eller dra PNG-filen inn\./);
assert.match(html, /KOPIER BILDE/);
assert.match(html, /LAST NED PNG/);
assert.match(html, /navigator\.clipboard\.write/);
assert.match(html, /new ClipboardItem\(\{"image\/png": blob\}\)/);
assert.match(html, /document\.createElement\("canvas"\)/);
assert.match(html, /canvas\.toBlob/);
assert.match(html, /Raven-Vision-Latest\.png/);
assert.match(html, /\$\("shareChatGPT"\)\.onclick = openChatGPTSharePanel/);
assert.match(html, /\$\("copyImage"\)\.onclick = copyImageToClipboard/);
assert.match(html, /\$\("downloadPng"\)\.onclick = downloadLatestPng/);

const shareRegion = html.split('function openChatGPTSharePanel()',2)[1].split('async function discoverModels()',1)[0];
assert.doesNotMatch(shareRegion, /fetch\(/);
assert.doesNotMatch(shareRegion, /localStorage/);
assert.doesNotMatch(shareRegion, /writeState\(/);
assert.doesNotMatch(shareRegion, /api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);
const setImageRegion = html.split('function setImage(',2)[1].split('function readFile(',1)[0];
assert.doesNotMatch(setImageRegion, /copyImageToClipboard\(/);
assert.doesNotMatch(setImageRegion, /downloadLatestPng\(/);
assert.match(setImageRegion, /shareChatGPT/);

assert.match(html, /http:\/\/127\.0\.0\.1:18765/);
assert.match(html, /Kun lokal loopback er tillatt/);
assert.match(html, /Eksterne adresser blokkeres før nettverkskall/);
assert.match(source, /capture\/active-window/);
assert.match(source, /\/lm\/analyze/);
assert.match(html, /Bildet ble ikke lagret/);
assert.match(html, /Raven tar aldri skjermbilder skjult/);
assert.doesNotMatch(html, /127\.0\.0\.1:8765/);
assert.doesNotMatch(html, /api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);

assert.match(html, /RAH-RAVEN-CORE-DEMO\.html/);
assert.match(html, /const query = new URLSearchParams\(location\.search\)/);
assert.match(html, /query\.get\("mode"\) === "chatgpt"/);
assert.match(html, /query\.get\("return"\) === "core"/);
assert.match(html, /ChatGPT-handoff-modus/);
assert.match(html, /chatGPTMode \? "Bildet er klart for eksplisitt ChatGPT-handoff/);
assert.equal((html.match(/copyImageToClipboard\(\)/g)||[]).length, 1);
assert.equal((html.match(/downloadLatestPng\(\)/g)||[]).length, 1);
console.log('Raven Vision Core v0.6 local-boundary and source-preserving handoff validation passed.');

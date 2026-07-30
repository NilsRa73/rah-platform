import fs from 'node:fs';
import assert from 'node:assert/strict';

const moduleText = fs.readFileSync('voice-control-v1.6.js', 'utf8');
const html = fs.readFileSync('index.html', 'utf8');

assert.match(moduleText, /const VERSION = "1\.6\.0"/);
assert.match(moduleText, /speechSynthesis/);
assert.match(moduleText, /pendingConfirmation/);
assert.match(moduleText, /captureActiveWindow/);
assert.match(moduleText, /analyzeVision/);
assert.match(moduleText, /runNextMissionStep/);
assert.match(moduleText, /synkroniser skyen/);
assert.match(moduleText, /http:\/\/127\.0\.0\.1:8765\/health/);
assert.match(html, /voice-control-v1\.6\.js\?v=1\.6/);
assert.match(html, /mission-engine\.js\?v=1\.5/);
assert.match(html, /cloud-sync\.js\?v=1\.0/);
assert.match(html, /vision-module\.js\?v=1\.3/);

console.log('Voice Control v1.6 validation passed.');

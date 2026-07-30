import assert from 'node:assert/strict';
import fs from 'node:fs';

const moduleText = fs.readFileSync('system-health-v1.7.js', 'utf8');
const indexText = fs.readFileSync('index.html', 'utf8');

assert.match(indexText, /system-health-v1\.7\.js\?v=1\.7/);
assert.match(moduleText, /runRavenSystemHealth/);
assert.match(moduleText, /127\.0\.0\.1:8765/);
assert.match(moduleText, /127\.0\.0\.1:1234/);
assert.match(moduleText, /Cloud Sync/);
assert.match(moduleText, /Voice Control/);
assert.match(moduleText, /Mission Engine/);
assert.match(moduleText, /AbortController/);
assert.match(moduleText, /localStorage/);
assert.doesNotMatch(moduleText, /service_role/i);

console.log('System Health v1.7 integration validation passed.');

import assert from 'node:assert/strict';
import fs from 'node:fs';

const launcher = fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat', 'utf8');
const cc = JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json', 'utf8'));

assert.equal(cc.version, '0.3.1');
assert.equal(cc.features.offline_first_one_click_launcher, true);
assert.equal(cc.features.launcher_network_requests, false);
assert.equal(cc.features.automatic_update, false);
assert.equal(cc.features.launcher_powershell_execution, false);
assert.deepEqual(cc.package_files, [
  'RAH-COMMAND-CENTER-V0.3.html',
  'rah-command-center-core.js',
  'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
]);

assert.match(launcher, /RAH-COMMAND-CENTER-V0\.3\.html/);
assert.match(launcher, /start "" "%CC_PAGE%"/);
assert.match(launcher, /Ingen filer lastes ned eller oppdateres automatisk/);
assert.doesNotMatch(launcher, /Invoke-WebRequest|curl\b|wget\b|bitsadmin|Start-BitsTransfer/i);
assert.doesNotMatch(launcher, /powershell|pwsh/i);
assert.doesNotMatch(launcher, /raw\.githubusercontent\.com|https?:\/\//i);
assert.doesNotMatch(launcher, /git\s+(pull|fetch|clone)/i);

console.log('RAH Command Center v0.3.1 packaging test passed: offline-first launcher has no updater or network path.');

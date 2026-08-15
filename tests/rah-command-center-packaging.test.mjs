import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const manifest = JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json', 'utf8'));
const ccUpdater = fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1', 'utf8');
const ravenUpdater = fs.readFileSync('UPDATE-RAH-RAVEN.ps1', 'utf8');
const launcher = fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat', 'utf8');

const packageFiles = [
  'RAH-COMMAND-CENTER-V0.3.html',
  'rah-command-center-core.js',
  'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
];

test('v0.3.1 package is explicit and runtime-only', () => {
  assert.equal(manifest.product, 'RAH Raven Command Center');
  assert.equal(manifest.version, '0.3.1');
  assert.deepEqual(manifest.package_files, packageFiles);
  assert.equal(manifest.features.one_click_package_update, true);
  assert.equal(manifest.features.desktop_shortcut_install, true);
  assert.equal(manifest.features.stable_runtime_files_changed, false);
});

test('Command Center updater is path-contained and does not auto-run hidden work', () => {
  assert.match(ccUpdater, /Get-SafeTargetPath/);
  assert.match(ccUpdater, /Contains\("\.\."\)/);
  assert.match(ccUpdater, /RAH Command Center\.lnk/);
  assert.match(ccUpdater, /if \(-not \$NoStart\)/);
  assert.doesNotMatch(ccUpdater, /agent\/run/i);
  assert.doesNotMatch(ccUpdater, /capture\/active-window/i);
  assert.doesNotMatch(ccUpdater, /lm\/analyze/i);
});

test('Raven updater treats Command Center sync as optional', () => {
  assert.match(ravenUpdater, /function Sync-CommandCenterPackage/);
  assert.match(ravenUpdater, /-File \$ccUpdater -NoStart/);
  assert.match(ravenUpdater, /Raven-oppdateringen fortsetter/);
  assert.match(ravenUpdater, /Valgfri Command Center-synk ble hoppet over/);
});

test('one-click launcher only refreshes the fixed Command Center updater', () => {
  assert.match(launcher, /raw\.githubusercontent\.com\/NilsRa73\/rah-platform\/main\/UPDATE-RAH-COMMAND-CENTER\.ps1/);
  assert.match(launcher, /-File "%CC_UPDATER%"/);
  assert.doesNotMatch(launcher, /powershell\s+-Command\s+%/i);
});

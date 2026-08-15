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

test('v0.3.2 is an integrity-hardening candidate with no Raven runtime feature change', () => {
  assert.equal(manifest.product, 'RAH Raven Command Center');
  assert.equal(manifest.version, '0.3.2');
  assert.equal(manifest.stage, 'candidate-integrity-boundary');
  assert.equal(manifest.runtime_feature_change, false);
  assert.deepEqual(manifest.package_files, packageFiles);
  assert.equal(manifest.features.one_click_package_update, true);
  assert.equal(manifest.features.desktop_shortcut_install, true);
  assert.equal(manifest.features.verified_commit_resolution, true);
  assert.equal(manifest.features.immutable_commit_downloads, true);
  assert.equal(manifest.features.stable_manifest_required_before_install, true);
  assert.equal(manifest.features.fixed_package_allowlist, true);
  assert.equal(manifest.features.launcher_remote_code_bootstrap, false);
  assert.equal(manifest.features.raven_updater_remote_cc_bootstrap, false);
  assert.equal(manifest.features.stable_runtime_files_changed, false);
  assert.equal(manifest.next_milestone, 'stable-gate');
  assert.equal(manifest.release_gate.status, 'candidate');
});

test('Command Center updater resolves a verified commit and downloads only from that immutable SHA', () => {
  assert.match(ccUpdater, /Resolve-VerifiedRepositoryCommit/);
  assert.match(ccUpdater, /Invoke-RestMethod[\s\S]*commits\/\$RepoBranch/);
  assert.match(ccUpdater, /commit\.verification\.verified/);
  assert.match(ccUpdater, /\^\[0-9a-fA-F\]\{40\}\$/);
  assert.match(ccUpdater, /raw\.githubusercontent\.com\/\$RepoOwner\/\$RepoName\/\$ResolvedCommit/);
  assert.doesNotMatch(ccUpdater, /raw\.githubusercontent\.com\/NilsRa73\/rah-platform\/main/);
  assert.match(ccUpdater, /\$manifest\.stage -ne "stable"/);
  assert.match(ccUpdater, /\$manifest\.release_gate\.status -ne "passed"/);
});

test('Command Center updater keeps the package path-contained and fixed to an allowlist', () => {
  assert.match(ccUpdater, /Get-SafeTargetPath/);
  assert.match(ccUpdater, /Contains\("\.\."\)/);
  assert.match(ccUpdater, /Assert-FixedPackageContract/);
  assert.match(ccUpdater, /\$AllowedPackageFiles/);
  for (const file of packageFiles) assert.match(ccUpdater, new RegExp(file.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  assert.doesNotMatch(ccUpdater, /agent\/run/i);
  assert.doesNotMatch(ccUpdater, /capture\/active-window/i);
  assert.doesNotMatch(ccUpdater, /lm\/analyze/i);
});

test('one-click launcher executes only the local updater and never bootstraps remote PowerShell', () => {
  assert.match(launcher, /UPDATE-RAH-COMMAND-CENTER\.ps1/);
  assert.match(launcher, /-File "%CC_UPDATER%"/);
  assert.match(launcher, /if not exist "%CC_UPDATER%"/);
  assert.doesNotMatch(launcher, /raw\.githubusercontent\.com/i);
  assert.doesNotMatch(launcher, /Invoke-WebRequest/i);
  assert.doesNotMatch(launcher, /-Command\s+".*Invoke-WebRequest/i);
});

test('Raven updater treats Command Center sync as optional and never downloads executable CC updater code', () => {
  assert.match(ravenUpdater, /function Sync-CommandCenterPackage/);
  assert.match(ravenUpdater, /Test-Path -LiteralPath \$ccUpdater -PathType Leaf/);
  assert.match(ravenUpdater, /-File \$ccUpdater -NoStart/);
  assert.match(ravenUpdater, /Raven-oppdateringen fortsetter/);
  assert.match(ravenUpdater, /Valgfri Command Center-synk ble hoppet over/);
  const syncBlock = ravenUpdater.match(/function Sync-CommandCenterPackage \{[\s\S]*?\n\}/)?.[0] || '';
  assert.doesNotMatch(syncBlock, /Invoke-WebRequest/i);
  assert.doesNotMatch(syncBlock, /raw\.githubusercontent\.com/i);
  assert.doesNotMatch(syncBlock, /\.rah-download/i);
});

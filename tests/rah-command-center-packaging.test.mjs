import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const manifest = JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json', 'utf8'));
const updater = fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1', 'utf8');
const ravenUpdater = fs.readFileSync('UPDATE-RAH-RAVEN.ps1', 'utf8');
const launcher = fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat', 'utf8');

const packageFiles = [
  'RAH-COMMAND-CENTER-V0.3.html',
  'rah-command-center-core.js',
  'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
];

test('normal one-click start is offline-first and does not update', () => {
  assert.equal(manifest.version, '0.3.2');
  assert.equal(manifest.stage, 'stable-bugfix-candidate');
  assert.equal(manifest.runtime_feature_change, false);
  assert.equal(manifest.features.one_click_package_update, false);
  assert.equal(manifest.features.offline_first_one_click_launcher, true);
  assert.equal(manifest.features.launcher_network_requests, false);
  assert.equal(manifest.features.automatic_update_on_launch, false);
  assert.match(launcher, /start "" "%CC_PAGE%"/);
  assert.match(launcher, /For manuell oppdatering/);
  assert.doesNotMatch(launcher, /Invoke-WebRequest|powershell|pwsh|curl\b|wget\b|raw\.githubusercontent\.com|https?:\/\//i);
});

test('network updater remains a separate explicit tool with a fixed package contract', () => {
  assert.deepEqual(manifest.package_files, packageFiles);
  assert.equal(manifest.features.manual_command_center_updater_available, true);
  assert.equal(manifest.features.manual_updater_requires_explicit_launch, true);
  assert.equal(manifest.features.manual_updater_network_requests, true);
  assert.equal(manifest.features.manual_updater_fixed_package_allowlist, true);
  assert.match(updater, /Invoke-WebRequest/);
  assert.match(updater, /Get-SafeTargetPath/);
  assert.match(updater, /Contains\("\.\."\)/);
  assert.match(updater, /Assert-FixedPackageContract/);
  assert.match(updater, /\$AllowedPackageFiles/);
  assert.doesNotMatch(launcher, /UPDATE-RAH-COMMAND-CENTER\.ps1"?\s*$/m);
});

test('manual updater resolves verified main then downloads only from that immutable commit', () => {
  assert.equal(manifest.features.manual_updater_verified_commit_resolution, true);
  assert.equal(manifest.features.manual_updater_immutable_commit_downloads, true);
  assert.equal(manifest.features.manual_updater_stable_manifest_required, true);
  assert.match(updater, /Resolve-VerifiedRepositoryCommit/);
  assert.match(updater, /Invoke-RestMethod[\s\S]*commits\/\$RepoBranch/);
  assert.match(updater, /commit\.verification\.verified/);
  assert.match(updater, /\^\[0-9a-fA-F\]\{40\}\$/);
  assert.match(updater, /raw\.githubusercontent\.com\/\$RepoOwner\/\$RepoName\/\$ResolvedCommit/);
  assert.doesNotMatch(updater, /raw\.githubusercontent\.com\/NilsRa73\/rah-platform\/main/);
  assert.match(updater, /\$manifest\.stage -ne "stable"/);
  assert.match(updater, /\$manifest\.release_gate\.status -ne "passed"/);
  assert.match(updater, /\$manifest\.raven_contract -ne "2\.0\.32"/);
});

test('Raven updater optional CC sync never downloads executable updater code', () => {
  assert.equal(manifest.features.raven_updater_optional_cc_sync, true);
  assert.equal(manifest.features.raven_updater_remote_cc_bootstrap, false);
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

test('candidate remains outside Stable until a separate gate', () => {
  assert.equal(manifest.release_gate.status, 'candidate');
  assert.equal(manifest.next_milestone, 'stable-gate');
  assert.equal(manifest.features.stable_runtime_files_changed, false);
});

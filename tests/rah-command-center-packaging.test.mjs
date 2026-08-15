import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const manifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const updater=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');
const launcher=fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','utf8');

const packageFiles=[
  'RAH-COMMAND-CENTER-V0.4.html',
  'rah-command-center-core.js',
  'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
];

test('normal one-click start is offline-first and does not update',()=>{
  assert.equal(manifest.version,'0.4.0');
  assert.equal(manifest.entry,'RAH-COMMAND-CENTER-V0.4.html');
  assert.deepEqual(manifest.package_files,packageFiles);
  assert.equal(manifest.features.one_click_package_update,false);
  assert.equal(manifest.features.offline_first_one_click_launcher,true);
  assert.equal(manifest.features.launcher_network_requests,false);
  assert.equal(manifest.features.automatic_update_on_launch,false);
  assert.match(launcher,/RAH-COMMAND-CENTER-V0\.4\.html/);
  assert.match(launcher,/start "" "%CC_PAGE%"/);
  assert.match(launcher,/For manuell oppdatering/);
  assert.doesNotMatch(launcher,/Invoke-WebRequest|powershell|pwsh|curl\b|wget\b|raw\.githubusercontent\.com|https?:\/\//i);
});

test('network updater remains a separate explicit tool',()=>{
  assert.equal(manifest.features.manual_command_center_updater_available,true);
  assert.equal(manifest.features.manual_updater_requires_explicit_launch,true);
  assert.equal(manifest.features.manual_updater_network_requests,true);
  assert.match(updater,/Invoke-WebRequest/);
  assert.match(updater,/Get-SafeTargetPath/);
  assert.match(updater,/Contains\("\.\."\)/);
  assert.doesNotMatch(launcher,/UPDATE-RAH-COMMAND-CENTER\.ps1"?\s*$/m);
});

test('device registry remains metadata-only',()=>{
  assert.equal(manifest.features.local_device_registry,true);
  assert.equal(manifest.features.device_metadata_local_storage_only,true);
  assert.equal(manifest.features.network_discovery,false);
  assert.equal(manifest.features.remote_control,false);
  assert.equal(manifest.features.device_commands,false);
  assert.equal(manifest.features.credential_collection,false);
  assert.equal(manifest.features.stable_runtime_files_changed,false);
});

import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';

const read = path => fs.readFileSync(path, 'utf8');
const gitBlobSha = path => {
  const content = fs.readFileSync(path);
  const header = Buffer.from(`blob ${content.length}\0`);
  return crypto.createHash('sha1').update(Buffer.concat([header, content])).digest('hex');
};

const html = read('RAH-RAVEN-PROJECT-REGISTRY.html');
const manifest = JSON.parse(read('RAH-RAVEN-PROJECT-REGISTRY-VERSION.json'));

assert.equal(manifest.product, 'RAH Raven Project Registry');
assert.equal(manifest.version, '0.1.0');
assert.equal(manifest.stage, 'candidate');
assert.equal(manifest.release_gate.status, 'pending');
assert.equal(manifest.features.wip_limit, 3);
assert.deepEqual(manifest.features.wip_statuses, ['AKTIV', 'TESTING', 'PILOT']);
assert.equal(manifest.features.project_brain_snapshot_read_only, true);
assert.equal(manifest.features.project_brain_write, false);
assert.equal(manifest.features.project_brain_activation, false);
assert.equal(manifest.features.mission_mutation, false);
assert.equal(manifest.features.mission_step_completion, false);
assert.equal(manifest.features.chronicle_sync, false);
assert.equal(manifest.features.daily_brief_mutation, false);
assert.equal(manifest.features.network_requests, false);
assert.equal(manifest.features.background_polling, false);
assert.equal(manifest.features.automatic_project_activation, false);
assert.equal(manifest.features.automatic_status_change, false);
assert.equal(manifest.features.local_storage, true);
assert.equal(manifest.features.registry_storage_key, 'rah.project.registry.v0.1');
assert.equal(manifest.features.project_brain_storage_key_read_only, 'rah.command.center');
assert.equal(manifest.features.user_action_writes_only, true);
assert.equal(manifest.features.json_export_explicit_only, true);
assert.equal(manifest.features.json_import_explicit_only, true);
assert.equal(manifest.features.json_import_replace_requires_confirmation, true);
assert.equal(manifest.features.registry_max_entries, 500);
assert.equal(manifest.features.automatic_sending, false);

for (const status of ['IDÉ','AVKLARES','KØ','AKTIV','TESTING','MVP FERDIG','PILOT','PARKERT','SLÅTT SAMMEN','AVSLUTTET']) {
  assert.ok(html.includes(`'${status}'`) || html.includes(`>${status}<`), `missing standard status ${status}`);
}

assert.match(html, /const WIP_LIMIT=3;/);
assert.match(html, /const WIP=new Set\(\['AKTIV','TESTING','PILOT'\]\);/);
assert.match(html, /wipCount\(\)>=WIP_LIMIT/);
assert.match(html, /WIP-grensen er 3/);
assert.match(html, /WIP-grensen på tre er nådd/);
assert.match(html, /confirm\(`Endre status/);
assert.match(html, /ERSTATT dagens lokale register/);
assert.match(html, /raw\?\.schema!=='rah-project-registry-v1'/);
assert.match(html, /file\.size>1024\*1024/);
assert.match(html, /slice\(0,500\)/);

assert.ok(html.includes("const STORAGE_KEY='rah.project.registry.v0.1'"));
assert.ok(html.includes("const PROJECT_BRAIN_KEY='rah.command.center'"));
assert.match(html, /localStorage\.getItem\(PROJECT_BRAIN_KEY\)/);
assert.doesNotMatch(html, /localStorage\.setItem\(PROJECT_BRAIN_KEY/);
assert.doesNotMatch(html, /localStorage\.removeItem\(PROJECT_BRAIN_KEY/);
assert.doesNotMatch(html, /fetch\s*\(/);
assert.doesNotMatch(html, /XMLHttpRequest/);
assert.doesNotMatch(html, /WebSocket/);
assert.doesNotMatch(html, /EventSource/);
assert.doesNotMatch(html, /setInterval\s*\(/);
assert.match(html, /connect-src 'none'/);
assert.match(html, /Project Brain · read-only/);
assert.match(html, /NO MUTATION/);
assert.match(html, /NO SYNC/);
assert.match(html, /automatic.*aktiveres/i);

const stableBaselines = {
  'RAH-RAVEN-PROJECT.html': '3bc0af6c53b59a904167c1f0d8167cb8520027ee',
  'RAH-RAVEN-MISSION-CONTROL.html': 'cb3c951b034cf94183a4678652cde52ff3fb2bd7',
  'RAH-RAVEN-DAILY-BRIEF.html': '8515b7dc848143ecad7e85227dd559514c1229f0',
  'RAH-RAVEN-CARE-HUB.html': '7626087d3a8d873885b0e33ca477a76307255a88',
  'RAH-COMMAND-CENTER-V0.8.html': 'a71e73aa7da43e04d7e3433cfc4d7406969a872e',
  'RAH-RAVEN-VERSION.json': '27bc472fe5b2d07f729bf72ca288fcc5868b8dc1'
};
for (const [path, expected] of Object.entries(stableBaselines)) {
  assert.equal(gitBlobSha(path), expected, `${path} stable baseline moved`);
}

console.log('RAH Raven Project Registry v0.1 candidate boundary: PASS');

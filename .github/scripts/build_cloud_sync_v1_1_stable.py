from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path('.')
BASE_SHA = '6c335dcd31cc342177127cd4ab90fd2f351dcb9a'

FROZEN = [
    'index.html',
    'cloud-sync.js',
    'supabase/001_project_brain_sync.sql',
    '.github/workflows/validate-cloud-sync.yml',
    'RAH-RAVEN-START.html',
    'RAH-RAVEN-CORE-DEMO.html',
    'RAH-RAVEN-VISION-CORE.html',
    'RAH-RAVEN-COUNCIL.html',
    'RAH-RAVEN-AGENT-RUNNER.html',
    'RAH-RAVEN-MEMORY-SYNC.html',
    'RAH-RAVEN-MISSION-CONTROL.html',
    'RAH-RAVEN-NOW.html',
    'RAH-RAVEN-NOW-V2.html',
    'RAH-RAVEN-PROJECT.html',
    'raven-vision-core.js',
    'raven-council.js',
    'raven-checkpoint-policy.js',
    'RAH-RAVEN-CHRONICLE.html',
    'RAH-RAVEN-CHRONICLE-LIVE.html',
    'RAH-RAVEN-CHRONICLE-VERSION.json',
    'desktop-bridge/server_v17.py',
    'system-health-v1.7.js',
    'SYSTEM_HEALTH_V1_7.md',
    'RAH-RAVEN-SYSTEM-HEALTH-VERSION.json',
    'RAH-RAVEN-CASE-CENTER.html',
    'RAH-RAVEN-CASE-CENTER-VERSION.json',
    'desktop-bridge/server_v16.py',
    'RAH-HOME-CONTROL.html',
    'RAH-HOME-CONTROL-VERSION.json',
]


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()

before = {p: digest(p) for p in FROZEN if (ROOT / p).exists()}

component_path = ROOT / 'RAH-RAVEN-CLOUD-SYNC-VERSION.json'
component = json.loads(component_path.read_text(encoding='utf-8'))
assert component['product'] == 'RAH Project Brain Cloud Sync'
assert component['version'] == '1.1.0'
assert component['stage'] == 'candidate'
assert component['features']['explicit_sync_only'] is True
assert component['features']['automatic_sync'] is False
assert component['features']['legacy_index_mutator_retired'] is True
component['stage'] = 'stable'
component['next_milestone'] = None
component['stable_since'] = '2026-08-15'
component['development_paused'] = True
component['change_policy'] = 'bugfix-only-until-explicit-reopen'
component['stable_release_gate'] = {
    'status': 'passed',
    'gate_version': '1.0.0',
    'runtime_files_frozen': True,
}
component_path.write_text(json.dumps(component, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

master_path = ROOT / 'RAH-RAVEN-VERSION.json'
master = json.loads(master_path.read_text(encoding='utf-8'))
expected_core = {
    'raven_vision': '0.6', 'raven_council': '0.3', 'agent_runner': '0.3',
    'memory_sync': '0.2', 'mission_control': '2.9', 'project_focus': '2.4',
    'raven_core': '1.12', 'raven_now': '2.17', 'raven_studio': '2.8'
}
assert master['release_gate']['stable_components'] == expected_core
privacy = master['privacy']
assert privacy['raven_chronicle_stable'] is True
assert privacy['system_health_stable'] is True
assert privacy['case_center_stable'] is True
assert privacy['project_brain_cloud_sync_explicit_only'] is True
assert privacy['project_brain_cloud_sync_automatic_sync'] is False
assert privacy['project_brain_cloud_sync_stable'] is False
privacy['project_brain_cloud_sync_stable'] = True
master_path.write_text(json.dumps(master, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

test = r'''import assert from "node:assert/strict";
import fs from "node:fs";

const index = fs.readFileSync("index.html", "utf8");
const sync = fs.readFileSync("cloud-sync.js", "utf8");
const sql = fs.readFileSync("supabase/001_project_brain_sync.sql", "utf8");
const component = JSON.parse(fs.readFileSync("RAH-RAVEN-CLOUD-SYNC-VERSION.json", "utf8"));
const master = JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json", "utf8"));

assert.match(index, /cloud-sync\.js\?v=1\.0/, "Frozen Command Center hook must remain present");
assert.equal(fs.existsSync(".github/workflows/integrate-cloud-sync.yml"), false, "Retired index-mutating workflow must stay absent");
assert.match(sync, /VERSION = "1\.1\.0"/);
assert.match(sync, /rah_user_state/);
assert.match(sync, /Sjekk sky-status/);
assert.match(sync, /Last opp denne enheten/);
assert.match(sync, /Hent fra skyen/);
assert.match(sync, /window\.confirm/);
assert.match(sync, /automaticSync: false/);
assert.match(sync, /autoRefreshToken: false/);
assert.doesNotMatch(sync, /setInterval\s*\(/, "Cloud Sync must not run a background interval");
assert.doesNotMatch(sync, /markLocalChanged/, "Cloud Sync must not watch local changes for upload");
assert.doesNotMatch(sync, /DEBOUNCE_MS|SYNC_INTERVAL_MS/);
assert.doesNotMatch(sync, /window\.saveState\s*=/, "Cloud Sync must not wrap saveState");
assert.doesNotMatch(sync, /addEventListener\(["'](?:click|change)["'][\s\S]{0,200}markLocalChanged/);
assert.doesNotMatch(sync, /onAuthStateChange[\s\S]{0,300}sync\s*\(/, "Auth changes must not trigger state sync");
assert.doesNotMatch(sync, /if \(session[^\n]{0,100}sync\s*\(/, "Startup must not trigger state sync");

assert.equal(component.product, "RAH Project Brain Cloud Sync");
assert.equal(component.version, "1.1.0");
assert.equal(component.stage, "stable");
assert.equal(component.features.explicit_sync_only, true);
assert.equal(component.features.automatic_sync, false);
assert.equal(component.features.background_timer, false);
assert.equal(component.features.click_change_watch, false);
assert.equal(component.features.login_triggered_sync, false);
assert.equal(component.features.upload_requires_confirmation, true);
assert.equal(component.features.download_requires_confirmation, true);
assert.equal(component.features.inspect_sends_local_state, false);
assert.equal(component.features.legacy_index_mutator_retired, true);
assert.equal(component.features.automatic_sending, false);
assert.equal(component.next_milestone, null);
assert.equal(component.stable_since, "2026-08-15");
assert.equal(component.development_paused, true);
assert.equal(component.change_policy, "bugfix-only-until-explicit-reopen");
assert.equal(component.stable_release_gate?.status, "passed");
assert.equal(component.stable_release_gate?.gate_version, "1.0.0");
assert.equal(component.stable_release_gate?.runtime_files_frozen, true);

assert.match(sql, /enable row level security/i);
assert.match(sql, /auth\.uid\(\) = user_id/g);
assert.match(sql, /revoke all .* from anon/i);

const stable = {raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};
assert.deepEqual(master.release_gate.stable_components, stable);
assert.equal(master.privacy.raven_chronicle_stable, true);
assert.equal(master.privacy.system_health_stable, true);
assert.equal(master.privacy.case_center_stable, true);
assert.equal(master.privacy.project_brain_cloud_sync_explicit_only, true);
assert.equal(master.privacy.project_brain_cloud_sync_automatic_sync, false);
assert.equal(master.privacy.project_brain_cloud_sync_background_timer, false);
assert.equal(master.privacy.project_brain_cloud_sync_click_change_watch, false);
assert.equal(master.privacy.project_brain_cloud_sync_login_triggered_sync, false);
assert.equal(master.privacy.project_brain_cloud_sync_upload_requires_confirmation, true);
assert.equal(master.privacy.project_brain_cloud_sync_download_requires_confirmation, true);
assert.equal(master.privacy.project_brain_cloud_sync_legacy_index_mutator_retired, true);
assert.equal(master.privacy.project_brain_cloud_sync_stable, true);

console.log("RAH Project Brain Cloud Sync v1.1 stable contract passed with runtime freeze preserved.");
'''
(ROOT / 'tests/cloud-sync.test.mjs').write_text(test, encoding='utf-8')

for p, expected in before.items():
    actual = digest(p)
    if actual != expected:
        raise SystemExit(f'Frozen runtime surface changed: {p}')

print('Cloud Sync v1.1 Stable Gate metadata applied; runtime freeze preserved.')

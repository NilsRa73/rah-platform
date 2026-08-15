import assert from "node:assert/strict";
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
assert.equal(component.stage, "candidate");
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
assert.equal(component.next_milestone, "stable-gate");

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
assert.equal(master.privacy.project_brain_cloud_sync_stable, false);

console.log("RAH Project Brain Cloud Sync v1.1 candidate contract passed.");

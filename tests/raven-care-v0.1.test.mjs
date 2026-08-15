import assert from "node:assert/strict";
import fs from "node:fs";

const read = path => fs.readFileSync(path, "utf8");
const html = read("RAH-RAVEN-CARE.html");
const manifest = JSON.parse(read("RAH-RAVEN-CARE-VERSION.json"));
const master = JSON.parse(read("RAH-RAVEN-VERSION.json"));
const projectMap = read("RAH-RAVEN-CARE-PROJECT-MAP.md");

assert.equal(manifest.product, "RAH Raven Care");
assert.equal(manifest.version, "0.1.0");
assert.equal(manifest.stage, "stable");
assert.equal(manifest.entry, "RAH-RAVEN-CARE.html");
assert.equal(manifest.runtime_feature_change, true);
assert.equal(manifest.features.care_dashboard_shell, true);
assert.equal(manifest.features.case_center_navigation_only, true);
assert.equal(manifest.features.fristvakt_navigation_only, true);
assert.equal(manifest.features.health_fatigue_module, false);
assert.equal(manifest.features.fastlege_view, false);
assert.equal(manifest.features.dashboard_data_storage, false);
assert.equal(manifest.features.dashboard_network_requests, false);
assert.equal(manifest.features.automatic_sending, false);
assert.equal(manifest.features.hidden_data_collection, false);
assert.equal(manifest.features.medical_decision_automation, false);
assert.equal(manifest.features.legal_decision_automation, false);
assert.equal(manifest.features.source_classification_visible, true);
assert.equal(manifest.features.synthetic_or_deidentified_demo_only, true);
assert.equal(manifest.features.existing_care_modules_modified, false);
assert.equal(manifest.features.stable_raven_runtime_modified, false);
assert.equal(manifest.next_milestone, null);
assert.equal(manifest.stable_since, "2026-08-15");
assert.equal(manifest.development_paused, true);
assert.equal(manifest.change_policy, "bugfix-only-until-explicit-reopen");
assert.equal(manifest.stable_release_gate.status, "passed");
assert.equal(manifest.stable_release_gate.gate_version, "1.0.0");
assert.equal(manifest.stable_release_gate.runtime_files_frozen, true);

assert.match(html, /RAH Raven Care · v0\.1 lokal navigasjon/);
assert.match(html, /LOKAL NAVIGASJON · SYNTETISKE ELLER AVIDENTIFISERTE DEMODATA/);
assert.doesNotMatch(html, /\bKANDIDAT\b/i, "Care runtime must remain stage-neutral after the Stable Gate.");
assert.equal((html.match(/href="RAH-RAVEN-CASE-CENTER\.html"/g) || []).length, 1);
assert.equal((html.match(/href="RAH-RAVEN-FRISTVAKT\.html"/g) || []).length, 1);
assert.match(html, /Dette dashboardet er bare navigasjon/);
assert.match(html, /ingen nettverkskall og ingen skjult datainnsamling/i);
assert.match(html, /avgjør ikke diagnose, behandling, rettighet eller fristbrudd/);
assert.match(html, /dokumentert faktum, pasientopplysning, tolkning eller uavklart/);
assert.match(html, /syntetiske eller avidentifiserte data/i);
assert.doesNotMatch(html, /<script\b/i);
assert.doesNotMatch(html, /<iframe\b|<form\b/i);
assert.doesNotMatch(html, /fetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon|localStorage\s*\.|sessionStorage\s*\./);
assert.match(projectMap, /RAH-RAVEN-CARE\.html` — v0\.1 dashboard med lokal navigasjon/);
assert.doesNotMatch(projectMap, /v0\.1 kandidatdashboard/i);

assert.ok(master.files.includes("RAH-RAVEN-CARE.html"));
assert.ok(master.files.includes("RAH-RAVEN-CARE-VERSION.json"));
assert.equal(master.privacy.raven_care_version_synced, true);
assert.equal(master.privacy.raven_care_navigation_only, true);
assert.equal(master.privacy.raven_care_dashboard_data_storage, false);
assert.equal(master.privacy.raven_care_dashboard_network_requests, false);
assert.equal(master.privacy.raven_care_automatic_sending, false);
assert.equal(master.privacy.raven_care_hidden_data_collection, false);
assert.equal(master.privacy.raven_care_medical_decision_automation, false);
assert.equal(master.privacy.raven_care_legal_decision_automation, false);
assert.equal(master.privacy.raven_care_source_classification_visible, true);
assert.equal(master.privacy.raven_care_synthetic_or_deidentified_demo_only, true);
assert.equal(master.privacy.raven_care_stable, true);
assert.match(master.summary, /Raven Care v0\.1 are stable/);
assert.deepEqual(master.release_gate.stable_components, {
  raven_vision: "0.6",
  raven_council: "0.3",
  agent_runner: "0.3",
  memory_sync: "0.2",
  mission_control: "2.9",
  project_focus: "2.4",
  raven_core: "1.12",
  raven_now: "2.17",
  raven_studio: "2.8"
});

console.log("RAH Raven Care v0.1 Stable contract passed: runtime frozen, navigation-only, network-free and registered outside the nine-core release set.");

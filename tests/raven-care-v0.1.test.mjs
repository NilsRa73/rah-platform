import assert from "node:assert/strict";
import fs from "node:fs";

const read = path => fs.readFileSync(path, "utf8");
const html = read("RAH-RAVEN-CARE.html");
const manifest = JSON.parse(read("RAH-RAVEN-CARE-VERSION.json"));
const projectMap = read("RAH-RAVEN-CARE-PROJECT-MAP.md");

assert.equal(manifest.product, "RAH Raven Care");
assert.equal(manifest.version, "0.1.0");
assert.equal(manifest.stage, "candidate");
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
assert.equal(manifest.next_milestone, "manual-health-fatigue-v0.2");

assert.match(html, /RAH Raven Care · v0\.1 lokal navigasjon/);
assert.match(html, /LOKAL NAVIGASJON · SYNTETISKE ELLER AVIDENTIFISERTE DEMODATA/);
assert.doesNotMatch(html, /\bKANDIDAT\b/i, "Care runtime must remain stage-neutral before the Stable Gate.");
assert.equal((html.match(/href="RAH-RAVEN-CASE-CENTER\.html"/g) || []).length, 1);
assert.equal((html.match(/href="RAH-RAVEN-FRISTVAKT\.html"/g) || []).length, 1);
assert.match(html, /Dette dashboardet er bare navigasjon/);
assert.match(html, /ingen nettverkskall og ingen skjult datainnsamling/i);
assert.match(html, /avgjør ikke diagnose, behandling, rettighet eller fristbrudd/);
assert.match(html, /dokumentert faktum, pasientopplysning, tolkning eller uavklart/);
assert.match(html, /syntetiske eller avidentifiserte data/i);
assert.doesNotMatch(html, /<script\b/i);
assert.doesNotMatch(html, /<iframe\b|<form\b/i);
assert.doesNotMatch(html, /fetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon|localStorage|sessionStorage/);
assert.match(projectMap, /RAH-RAVEN-CARE\.html` — v0\.1 dashboard med lokal navigasjon/);
assert.doesNotMatch(projectMap, /v0\.1 kandidatdashboard/i);

console.log("RAH Raven Care v0.1 candidate contract is stage-neutral in the UI, navigation-only, source-aware and network-free.");

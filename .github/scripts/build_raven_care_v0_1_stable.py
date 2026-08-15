from __future__ import annotations

import json
import subprocess
from pathlib import Path

BASE_SHA = "a8cfb17c3213d511f811bcf2665e59a6e2237137"
ROOT = Path(__file__).resolve().parents[2]
CARE_MANIFEST = ROOT / "RAH-RAVEN-CARE-VERSION.json"
MASTER_MANIFEST = ROOT / "RAH-RAVEN-VERSION.json"
CARE_TEST = ROOT / "tests/raven-care-v0.1.test.mjs"

EXPECTED_CORE = {
    "raven_vision": "0.6",
    "raven_council": "0.3",
    "agent_runner": "0.3",
    "memory_sync": "0.2",
    "mission_control": "2.9",
    "project_focus": "2.4",
    "raven_core": "1.12",
    "raven_now": "2.17",
    "raven_studio": "2.8",
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


care = load_json(CARE_MANIFEST)
assert care["product"] == "RAH Raven Care"
assert care["version"] == "0.1.0"
assert care["stage"] == "candidate"
assert care["entry"] == "RAH-RAVEN-CARE.html"
assert care["features"]["dashboard_data_storage"] is False
assert care["features"]["dashboard_network_requests"] is False
assert care["features"]["automatic_sending"] is False
assert care["features"]["hidden_data_collection"] is False
assert care["features"]["medical_decision_automation"] is False
assert care["features"]["legal_decision_automation"] is False
assert care["features"]["stable_raven_runtime_modified"] is False

care["stage"] = "stable"
care["next_milestone"] = None
care["stable_since"] = "2026-08-15"
care["development_paused"] = True
care["change_policy"] = "bugfix-only-until-explicit-reopen"
care["stable_release_gate"] = {
    "status": "passed",
    "gate_version": "1.0.0",
    "runtime_files_frozen": True,
}
write_json(CARE_MANIFEST, care)

master = load_json(MASTER_MANIFEST)
assert master["product"] == "RAH Raven"
assert master["version"] == "2.0.32"
assert master["release_gate"]["stable_components"] == EXPECTED_CORE

master["summary"] = (
    "RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, "
    "Project Brain Cloud Sync v1.1, Voice Control v1.7, Mission Engine v1.6 and "
    "Raven Care v0.1 are stable. Care remains a local navigation-only shell with "
    "no dashboard storage, network requests, automatic sending or decision automation."
)

files = master["files"]
care_files = ["RAH-RAVEN-CARE.html", "RAH-RAVEN-CARE-VERSION.json"]
for item in care_files:
    assert item not in files, f"Care file unexpectedly already registered: {item}"
insert_at = files.index("RAH-RAVEN-FRISTVAKT.html") + 1
files[insert_at:insert_at] = care_files

privacy = master["privacy"]
care_contract = {
    "raven_care_version_synced": True,
    "raven_care_navigation_only": True,
    "raven_care_dashboard_data_storage": False,
    "raven_care_dashboard_network_requests": False,
    "raven_care_automatic_sending": False,
    "raven_care_hidden_data_collection": False,
    "raven_care_medical_decision_automation": False,
    "raven_care_legal_decision_automation": False,
    "raven_care_source_classification_visible": True,
    "raven_care_synthetic_or_deidentified_demo_only": True,
    "raven_care_stable": True,
}
for key in care_contract:
    assert key not in privacy, f"Care master flag unexpectedly already exists: {key}"
privacy.update(care_contract)
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
write_json(MASTER_MANIFEST, master)

CARE_TEST.write_text(r'''import assert from "node:assert/strict";
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
''', encoding="utf-8")

subprocess.run(["node", "tests/raven-care-v0.1.test.mjs"], cwd=ROOT, check=True)
subprocess.run(["node", "tests/raven-release-gate.test.mjs"], cwd=ROOT, check=True)

allowed = {
    ".github/scripts/build_raven_care_v0_1_stable.py",
    ".github/workflows/build-raven-care-v0.1-stable-gate.yml",
    "RAH-RAVEN-CARE-VERSION.json",
    "RAH-RAVEN-VERSION.json",
    "tests/raven-care-v0.1.test.mjs",
}
changed = set(subprocess.check_output(
    ["git", "diff", "--name-only", BASE_SHA], cwd=ROOT, text=True
).splitlines())
extra = changed - allowed
assert not extra, f"Stable Gate touched non-allowlisted files: {sorted(extra)}"
assert "RAH-RAVEN-CARE.html" not in changed, "Care runtime must stay byte-for-byte frozen in Stable Gate"
assert master["release_gate"]["stable_components"] == EXPECTED_CORE

print("Raven Care v0.1 Stable Gate builder passed with a runtime-frozen, three-product-file target diff.")

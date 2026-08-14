from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")

def read_json(path: str) -> dict:
    return json.loads(read(path))

def write_json(path: str, data: dict) -> None:
    write(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor, got {text.count(old)}")
    return text.replace(old, new, 1)

# Runtime change is identity-only: sync the footer from Raven 2.0.30 to 2.0.32.
studio_path = "RAH-RAVEN-START.html"
studio = read(studio_path)
assert "RAH Raven Studio v2.8" in studio
old_footer = "RAH Raven Studio v2.8 · Raven 2.0.30 · Launcher 3.0 · Local-first · Ingen skjult skjermfangst, mikrofon eller kamera."
new_footer = "RAH Raven Studio v2.8 · Raven 2.0.32 · Launcher 3.0 · Local-first · Ingen skjult skjermfangst, mikrofon eller kamera."
studio = replace_once(studio, old_footer, new_footer, "Studio footer version sync")
write(studio_path, studio)

studio_manifest = {
    "product": "RAH Raven Studio",
    "version": "2.8.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "RAH-RAVEN-START.html",
    "local_only": True,
    "runtime_feature_change": False,
    "features": {
        "local_first_launcher": True,
        "status_polling_enabled": True,
        "status_poll_interval_ms": 30000,
        "status_polling_loopback_only": True,
        "bridge_status_url": "http://127.0.0.1:18765/health",
        "bridge_lm_models_url": "http://127.0.0.1:18765/lm/models",
        "lm_studio_fallback_url": "http://127.0.0.1:1234/v1/models",
        "external_status_addresses_allowed": False,
        "raven_state_writes": False,
        "mission_mutation": False,
        "mission_step_completion": False,
        "agent_execution": False,
        "automatic_sending": False,
        "favorites_storage_local_only": True,
        "recent_storage_local_only": True,
        "handoff_entry_navigation_only": True,
        "handoff_history_explicit_save_delete_only": True,
        "handoff_history_metadata_only": True,
        "footer_raven_version_synced": True,
        "capability_set_changed": False
    },
    "next_milestone": "stable-gate"
}
write_json("RAH-RAVEN-STUDIO-VERSION.json", studio_manifest)

master = read_json("RAH-RAVEN-VERSION.json")
assert master["version"] == "2.0.32"
assert master["launcher"] == "3.0"
assert master["release_gate"]["component_versions"]["raven_studio"] == "2.8"
expected_stable = {
    "raven_vision": "0.6",
    "raven_council": "0.3",
    "agent_runner": "0.3",
    "memory_sync": "0.2",
    "mission_control": "2.9",
    "project_focus": "2.4",
    "raven_core": "1.12",
    "raven_now": "2.17"
}
assert master["release_gate"]["stable_components"] == expected_stable
if "RAH-RAVEN-STUDIO-VERSION.json" not in master["files"]:
    idx = master["files"].index("RAH-RAVEN-START.html") + 1
    master["files"].insert(idx, "RAH-RAVEN-STUDIO-VERSION.json")
p = master["privacy"]
p["raven_studio_status_polling_loopback_only"] = True
p["raven_studio_external_status_addresses_allowed"] = False
p["raven_studio_raven_state_writes"] = False
p["raven_studio_mission_mutation"] = False
p["raven_studio_mission_step_completion"] = False
p["raven_studio_agent_execution"] = False
p["raven_studio_footer_version_synced"] = True
p["raven_studio_stable"] = False
master["summary"] = "RAH Raven 2.0.32 remains the temporary stable freeze. Eight core components are stable; Raven Studio v2.8 is a local-first version-sync and stable-contract candidate with loopback-only status polling."
write_json("RAH-RAVEN-VERSION.json", master)

studio_test = r'''import assert from "node:assert/strict";
import fs from "node:fs";

const html=fs.readFileSync("RAH-RAVEN-START.html","utf8");
const studio=JSON.parse(fs.readFileSync("RAH-RAVEN-STUDIO-VERSION.json","utf8"));
const master=JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json","utf8"));

assert.match(html,/RAH Raven Studio v2\.8/);
assert.match(html,/RAH Raven Studio v2\.8 · Raven 2\.0\.32 · Launcher 3\.0 · Local-first/);
assert.doesNotMatch(html,/RAH Raven Studio v2\.8 · Raven 2\.0\.30/);
assert.match(html,/get\('http:\/\/127\.0\.0\.1:18765\/health'\)/);
assert.match(html,/get\('http:\/\/127\.0\.0\.1:18765\/lm\/models'\)/);
assert.match(html,/get\('http:\/\/127\.0\.0\.1:1234\/v1\/models'\)/);
assert.match(html,/setInterval\(testAll,30000\)/);
assert.doesNotMatch(html,/rah\.bridge\.base/);
assert.doesNotMatch(html,/api\.openai\.com|chatgpt\.com\/backend|openai\.com\/v1/i);
assert.doesNotMatch(html,/supabase\.co|\/rest\/v1\//i);
assert.doesNotMatch(html,/localStorage\.setItem\(['"]rah\.command\.center/);
assert.doesNotMatch(html,/\bactiveProject\s*=|\bactiveMission\s*=|\.done\s*=\s*true|\/agent\/run/);

for(const key of ["rah-raven-studio-favorites-v1","rah-raven-studio-recent-v1","rah-raven-studio-used-v1"])
  assert.ok(html.includes(key),`${key} missing`);
assert.match(html,/HANDOFF_HISTORY_KEY=HANDOFF_HISTORY\.STORAGE_KEY/);
assert.match(html,/\$\('handoffReceiptSave'\)\.onclick=saveHandoffReceipt/);
assert.match(html,/\$\('handoffHistoryDelete'\)\.onclick=deleteHandoffHistory/);
assert.doesNotMatch(html,/saveHandoffReceipt\(\);/);
const launchStart=html.indexOf("function launchApp(id){");
const launchEnd=html.indexOf("function setAppState",launchStart);
assert.ok(launchStart>=0&&launchEnd>launchStart);
const launch=html.slice(launchStart,launchEnd);
assert.match(launch,/writeLocal\(USED_KEY,used\)/);
assert.match(launch,/writeLocal\(RECENT_KEY,\{id,ts:now\}\)/);
assert.match(launch,/location\.href=app\.url/);
assert.doesNotMatch(launch,/fetch\(|activeProject|activeMission|\/agent\/run|\.done\s*=/);

assert.equal(studio.product,"RAH Raven Studio");
assert.equal(studio.version,"2.8.0");
assert.equal(studio.stage,"candidate");
assert.equal(studio.local_only,true);
assert.equal(studio.runtime_feature_change,false);
assert.equal(studio.features.local_first_launcher,true);
assert.equal(studio.features.status_polling_enabled,true);
assert.equal(studio.features.status_poll_interval_ms,30000);
assert.equal(studio.features.status_polling_loopback_only,true);
assert.equal(studio.features.external_status_addresses_allowed,false);
assert.equal(studio.features.raven_state_writes,false);
assert.equal(studio.features.mission_mutation,false);
assert.equal(studio.features.mission_step_completion,false);
assert.equal(studio.features.agent_execution,false);
assert.equal(studio.features.automatic_sending,false);
assert.equal(studio.features.handoff_entry_navigation_only,true);
assert.equal(studio.features.handoff_history_explicit_save_delete_only,true);
assert.equal(studio.features.handoff_history_metadata_only,true);
assert.equal(studio.features.footer_raven_version_synced,true);
assert.equal(studio.features.capability_set_changed,false);
assert.equal(studio.next_milestone,"stable-gate");

const expectedStable={raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17"};
assert.deepEqual(master.release_gate.stable_components,expectedStable);
assert.equal(master.release_gate.stable_components.raven_studio,undefined);
assert.equal(master.privacy.raven_studio_status_polling_loopback_only,true);
assert.equal(master.privacy.raven_studio_external_status_addresses_allowed,false);
assert.equal(master.privacy.raven_studio_raven_state_writes,false);
assert.equal(master.privacy.raven_studio_mission_mutation,false);
assert.equal(master.privacy.raven_studio_mission_step_completion,false);
assert.equal(master.privacy.raven_studio_agent_execution,false);
assert.equal(master.privacy.raven_studio_footer_version_synced,true);
assert.equal(master.privacy.raven_studio_stable,false);
assert.ok(master.files.includes("RAH-RAVEN-STUDIO-VERSION.json"));
console.log("Raven Studio v2.8 version-sync and candidate stable contract passed.");
'''
write("tests/raven-studio.test.mjs", studio_test)

release_path = "tests/raven-release-gate.test.mjs"
release = read(release_path)
anchor = 'assert.equal(privacy.raven_now_stable,true,"Raven Now v2.17 stable marker must stay true");'
insert = '''assert.equal(privacy.raven_studio_status_polling_loopback_only,true,"Raven Studio status polling must stay loopback-only");
assert.equal(privacy.raven_studio_external_status_addresses_allowed,false,"Raven Studio external status addresses must stay blocked");
assert.equal(privacy.raven_studio_raven_state_writes,false,"Raven Studio must not write Raven state");
assert.equal(privacy.raven_studio_mission_mutation,false,"Raven Studio must not mutate missions");
assert.equal(privacy.raven_studio_mission_step_completion,false,"Raven Studio must not complete mission steps");
assert.equal(privacy.raven_studio_agent_execution,false,"Raven Studio must not execute Agent Runner");
assert.equal(privacy.raven_studio_footer_version_synced,true,"Raven Studio footer must report Raven 2.0.32");
assert.equal(privacy.raven_studio_stable,false,"Raven Studio remains candidate until stable gate passes");'''
release = replace_once(release, anchor, anchor + "\n" + insert, "release Studio privacy")
manifest_anchor = 'assert.ok(manifest.files.includes("RAH-RAVEN-NOW-VERSION.json"),"Raven Now component manifest must ship in Raven package");'
studio_checks = '''assert.ok(manifest.files.includes("RAH-RAVEN-STUDIO-VERSION.json"),"Raven Studio component manifest must ship in Raven package");
const studioManifest=JSON.parse(read("RAH-RAVEN-STUDIO-VERSION.json"));
assert.equal(studioManifest.version,"2.8.0");
assert.equal(studioManifest.stage,"candidate");
assert.equal(studioManifest.runtime_feature_change,false);
assert.equal(studioManifest.features.local_first_launcher,true);
assert.equal(studioManifest.features.status_polling_enabled,true);
assert.equal(studioManifest.features.status_poll_interval_ms,30000);
assert.equal(studioManifest.features.status_polling_loopback_only,true);
assert.equal(studioManifest.features.external_status_addresses_allowed,false);
assert.equal(studioManifest.features.raven_state_writes,false);
assert.equal(studioManifest.features.mission_mutation,false);
assert.equal(studioManifest.features.mission_step_completion,false);
assert.equal(studioManifest.features.agent_execution,false);
assert.equal(studioManifest.features.automatic_sending,false);
assert.equal(studioManifest.features.footer_raven_version_synced,true);
assert.equal(studioManifest.features.capability_set_changed,false);
assert.equal(studioManifest.next_milestone,"stable-gate");
assert.equal(manifest.release_gate.stable_components.raven_studio,undefined,"Raven Studio must remain outside stable_components during candidate gate");

'''
release = replace_once(release, manifest_anchor, studio_checks + manifest_anchor, "release Studio manifest")
write(release_path, release)

print("Raven Studio v2.8 candidate built: footer sync + explicit stable contract; eight stable runtimes untouched.")

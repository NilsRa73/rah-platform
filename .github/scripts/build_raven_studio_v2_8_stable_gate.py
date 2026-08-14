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
        raise RuntimeError(f"{label}: expected one anchor, got {text.count(old)}")
    return text.replace(old, new, 1)

# Promote metadata only. Studio runtime is frozen in this gate.
studio = read_json("RAH-RAVEN-STUDIO-VERSION.json")
assert studio["version"] == "2.8.0"
assert studio["stage"] == "candidate"
assert studio["runtime_feature_change"] is False
assert studio["next_milestone"] == "stable-gate"
studio["stage"] = "stable"
studio["next_milestone"] = None
studio["stable_since"] = "2026-08-14"
studio["development_paused"] = True
studio["change_policy"] = "bugfix-only-until-explicit-reopen"
studio["stable_release_gate"] = {
    "status": "passed",
    "gate_version": "1.0.0",
    "runtime_files_frozen": True
}
write_json("RAH-RAVEN-STUDIO-VERSION.json", studio)

master = read_json("RAH-RAVEN-VERSION.json")
assert master["version"] == "2.0.32"
assert master["privacy"]["raven_studio_stable"] is False
expected_eight = {
    "raven_vision": "0.6",
    "raven_council": "0.3",
    "agent_runner": "0.3",
    "memory_sync": "0.2",
    "mission_control": "2.9",
    "project_focus": "2.4",
    "raven_core": "1.12",
    "raven_now": "2.17"
}
assert master["release_gate"]["stable_components"] == expected_eight
master["privacy"]["raven_studio_stable"] = True
master["release_gate"]["bugfix_component_updates"]["raven_studio"] = "2.8"
master["release_gate"]["stable_components"]["raven_studio"] = "2.8"
master["summary"] = "RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components are stable, including Raven Studio v2.8 with synced Raven 2.0.32 identity and loopback-only status polling."
write_json("RAH-RAVEN-VERSION.json", master)

studio_test_path = "tests/raven-studio.test.mjs"
t = read(studio_test_path)
t = replace_once(t, 'assert.equal(studio.stage,"candidate");', 'assert.equal(studio.stage,"stable");', "Studio stage test")
t = replace_once(t, 'assert.equal(studio.next_milestone,"stable-gate");', '''assert.equal(studio.next_milestone,null);
assert.equal(studio.stable_since,"2026-08-14");
assert.equal(studio.development_paused,true);
assert.equal(studio.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(studio.stable_release_gate?.status,"passed");
assert.equal(studio.stable_release_gate?.runtime_files_frozen,true);''', "Studio stable metadata test")
t = replace_once(t, 'const expectedStable={raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17"};', 'const expectedStable={raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};', "Studio stable components")
t = replace_once(t, 'assert.equal(master.release_gate.stable_components.raven_studio,undefined);', '''assert.equal(master.release_gate.stable_components.raven_studio,"2.8");
assert.equal(master.release_gate.bugfix_component_updates.raven_studio,"2.8");''', "Studio stable pin")
t = replace_once(t, 'assert.equal(master.privacy.raven_studio_stable,false);', 'assert.equal(master.privacy.raven_studio_stable,true);', "Studio stable privacy")
t = t.replace('Raven Studio v2.8 version-sync and candidate stable contract passed.', 'Raven Studio v2.8 stable contract passed.')
write(studio_test_path, t)

release_path = "tests/raven-release-gate.test.mjs"
r = read(release_path)
r = replace_once(r, 'assert.equal(privacy.raven_studio_stable,false,"Raven Studio remains candidate until stable gate passes");', 'assert.equal(privacy.raven_studio_stable,true,"Raven Studio v2.8 stable marker must stay true");', "release Studio stable privacy")
r = replace_once(r, 'assert.equal(studioManifest.stage,"candidate");', 'assert.equal(studioManifest.stage,"stable");', "release Studio stage")
r = replace_once(r, 'assert.equal(studioManifest.next_milestone,"stable-gate");', '''assert.equal(studioManifest.next_milestone,null);
assert.equal(studioManifest.stable_since,"2026-08-14");
assert.equal(studioManifest.development_paused,true);
assert.equal(studioManifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(studioManifest.stable_release_gate?.status,"passed");
assert.equal(studioManifest.stable_release_gate?.runtime_files_frozen,true);''', "release Studio stable metadata")
r = replace_once(r, 'assert.equal(manifest.release_gate.stable_components.raven_studio,undefined,"Raven Studio must remain outside stable_components during candidate gate");', '''assert.equal(manifest.release_gate.stable_components.raven_studio,"2.8","Raven Studio v2.8 must be stable");
assert.equal(manifest.release_gate.bugfix_component_updates.raven_studio,"2.8","Raven Studio v2.8 bugfix pin must be recorded");''', "release Studio stable pin")
# Existing stable-component assertions end with Raven Now. Add Studio immediately after.
anchor = 'assert.equal(manifest.release_gate?.stable_components?.raven_now,"2.17");'
r = replace_once(r, anchor, anchor + '\nassert.equal(manifest.release_gate?.stable_components?.raven_studio,"2.8");\nassert.equal(manifest.release_gate?.bugfix_component_updates?.raven_studio,"2.8");', "release Studio stable aggregate")
write(release_path, r)

print("Raven Studio v2.8 stable metadata built; Studio and all stable runtimes remain frozen.")

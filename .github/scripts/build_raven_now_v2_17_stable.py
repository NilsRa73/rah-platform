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
    if old not in text:
        raise RuntimeError(f"{label} anchor missing")
    return text.replace(old, new, 1)

# Promote only the already-validated Raven Now candidate contract. Runtime remains frozen.
now = read_json("RAH-RAVEN-NOW-VERSION.json")
assert now["version"] == "2.17.0"
assert now["stage"] == "candidate"
assert now["runtime_feature_change"] is False
assert now["next_milestone"] == "stable-gate"
now["stage"] = "stable"
now["next_milestone"] = None
now["stable_since"] = "2026-08-14"
now["development_paused"] = True
now["change_policy"] = "bugfix-only-until-explicit-reopen"
now["stable_release_gate"] = {
    "status": "passed",
    "gate_version": "1.0.0",
    "runtime_files_frozen": True
}
write_json("RAH-RAVEN-NOW-VERSION.json", now)

manifest = read_json("RAH-RAVEN-VERSION.json")
assert manifest["version"] == "2.0.32"
assert manifest["release_gate"]["component_versions"]["raven_now"] == "2.17"
expected_stable = {
    "raven_vision":"0.6","raven_council":"0.3","agent_runner":"0.3","memory_sync":"0.2",
    "mission_control":"2.9","project_focus":"2.4","raven_core":"1.12"
}
assert manifest["release_gate"]["stable_components"] == expected_stable
manifest["privacy"]["raven_now_stable"] = True
manifest["release_gate"]["bugfix_component_updates"]["raven_now"] = "2.17"
manifest["release_gate"]["stable_components"]["raven_now"] = "2.17"
manifest["summary"] = "RAH Raven 2.0.32 remains the temporary stable freeze. Eight core components are stable, including Raven Now v2.17 with a read-only dashboard and loopback-only Bridge status requests."
write_json("RAH-RAVEN-VERSION.json", manifest)

boundary_path = "tests/raven-now-local-boundary.test.mjs"
boundary = read(boundary_path)
boundary = replace_once(boundary, 'assert.equal(manifest.stage,"candidate");', 'assert.equal(manifest.stage,"stable");', "boundary stable stage")
boundary = replace_once(boundary, 'assert.equal(manifest.next_milestone,"stable-gate");', '''assert.equal(manifest.next_milestone,null);
assert.equal(manifest.stable_since,"2026-08-14");
assert.equal(manifest.development_paused,true);
assert.equal(manifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(manifest.stable_release_gate?.status,"passed");
assert.equal(manifest.stable_release_gate?.runtime_files_frozen,true);''', "boundary stable contract")
boundary = boundary.replace("Raven Now v2.17 local Bridge boundary candidate passed.", "Raven Now v2.17 stable local Bridge boundary passed.")
write(boundary_path, boundary)

release_path = "tests/raven-release-gate.test.mjs"
release = read(release_path)
release = replace_once(release,
    'assert.equal(privacy.raven_now_stable,false,"Raven Now v2.17 remains candidate until stable gate passes");',
    'assert.equal(privacy.raven_now_stable,true,"Raven Now v2.17 stable marker must stay true");',
    "release stable privacy")
release = replace_once(release, 'assert.equal(nowManifest.stage,"candidate");', 'assert.equal(nowManifest.stage,"stable");', "release stable stage")
release = replace_once(release, 'assert.equal(nowManifest.next_milestone,"stable-gate");', '''assert.equal(nowManifest.next_milestone,null);
assert.equal(nowManifest.stable_since,"2026-08-14");
assert.equal(nowManifest.development_paused,true);
assert.equal(nowManifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(nowManifest.stable_release_gate?.status,"passed");
assert.equal(nowManifest.stable_release_gate?.runtime_files_frozen,true);''', "release stable contract")
core_stable_anchor = 'assert.equal(manifest.release_gate?.stable_components?.raven_core,"1.12");'
release = replace_once(release, core_stable_anchor, core_stable_anchor + '\nassert.equal(manifest.release_gate?.stable_components?.raven_now,"2.17");\nassert.equal(manifest.release_gate?.bugfix_component_updates?.raven_now,"2.17");', "release stable component pin")
release = release.replace(
    "RAH Raven 2.0.32 Temporary Stable Gate: seven stable core components; Raven Now v2.17 candidate local Bridge boundary OK.",
    "RAH Raven 2.0.32 Temporary Stable Gate: eight stable core components including Raven Now v2.17; local Bridge boundaries OK."
)
write(release_path, release)

print("Raven Now v2.17 stable metadata built; Raven Now runtime remains frozen.")

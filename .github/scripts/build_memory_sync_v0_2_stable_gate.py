from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read_json(name: str) -> dict:
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def write_json(name: str, data: dict) -> None:
    (ROOT / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


memory = read_json("RAH-RAVEN-MEMORY-SYNC-VERSION.json")
assert memory["version"] == "0.2.0"
assert memory["stage"] == "candidate"
assert memory["runtime_feature_change"] is False
assert memory["features"]["local_bridge_only"] is True
assert memory["features"]["external_bridge_addresses_allowed"] is False
assert memory["features"]["chronicle_write_requires_explicit_confirmation"] is True
assert memory["features"]["general_background_permission"] is False
assert memory["features"]["automatic_sync"] is False
assert memory["features"]["metadata_only"] is True
assert memory["features"]["sync_core_runtime_changed"] is False
memory["stage"] = "stable"
memory["stable_since"] = "2026-08-14"
memory["development_paused"] = True
memory["change_policy"] = "bugfix-only-until-explicit-reopen"
memory["stable_release_gate"] = {
    "status": "passed",
    "gate_version": "1.0.0",
    "runtime_files_frozen": True,
}
memory["next_milestone"] = None
write_json("RAH-RAVEN-MEMORY-SYNC-VERSION.json", memory)

manifest = read_json("RAH-RAVEN-VERSION.json")
assert manifest["version"] == "2.0.32"
assert manifest["release_gate"]["runtime_feature_change"] is False
assert manifest["privacy"]["memory_sync_stable"] is False
assert "memory_sync" not in manifest["release_gate"]["stable_components"]
manifest["summary"] = (
    "RAH Raven 2.0.32 remains the temporary stable freeze. Vision Core v0.6, Council v0.3, "
    "Agent Runner v0.3 and Memory Sync v0.2 are stable local-only components. Memory Sync keeps "
    "its loopback-only Bridge boundary, explicit metadata-only Chronicle writes and no automatic sync."
)
manifest["privacy"]["memory_sync_stable"] = True
manifest["release_gate"]["stable_components"]["memory_sync"] = "0.2"
write_json("RAH-RAVEN-VERSION.json", manifest)

memory_test_path = ROOT / "tests/raven-memory-sync.test.mjs"
memory_test = memory_test_path.read_text(encoding="utf-8")
repls = {
    'assert.equal(component.stage, "candidate");': 'assert.equal(component.stage, "stable");\nassert.equal(component.development_paused, true);\nassert.equal(component.change_policy, "bugfix-only-until-explicit-reopen");',
    'assert.equal(component.features.sync_core_runtime_changed, false);': 'assert.equal(component.features.sync_core_runtime_changed, false);\nassert.equal(component.stable_release_gate?.status, "passed");\nassert.equal(component.stable_release_gate?.runtime_files_frozen, true);\nassert.equal(component.next_milestone, null);',
    'console.log("Raven Memory Sync v0.2 local-boundary and metadata-only contract passed.");': 'console.log("Raven Memory Sync v0.2 stable local-boundary and metadata-only contract passed.");',
}
for old, new in repls.items():
    if old not in memory_test:
        raise RuntimeError(f"Memory test anchor missing: {old}")
    memory_test = memory_test.replace(old, new, 1)
memory_test_path.write_text(memory_test, encoding="utf-8")

release_path = ROOT / "tests/raven-release-gate.test.mjs"
release = release_path.read_text(encoding="utf-8")
repls = {
    'assert.equal(privacy.memory_sync_stable,false,"Memory Sync v0.2 remains candidate until its stable gate passes");': 'assert.equal(privacy.memory_sync_stable,true,"Memory Sync v0.2 stable marker must stay true");',
    'assert.equal(manifest.release_gate?.stable_components?.agent_runner,"0.3");': 'assert.equal(manifest.release_gate?.stable_components?.agent_runner,"0.3");\nassert.equal(manifest.release_gate?.stable_components?.memory_sync,"0.2");',
    'assert.equal(memoryManifest.stage,"candidate");': 'assert.equal(memoryManifest.stage,"stable");\nassert.equal(memoryManifest.development_paused,true);\nassert.equal(memoryManifest.change_policy,"bugfix-only-until-explicit-reopen");',
    'assert.equal(memoryManifest.features.sync_core_runtime_changed,false);': 'assert.equal(memoryManifest.features.sync_core_runtime_changed,false);\nassert.equal(memoryManifest.stable_release_gate?.status,"passed");\nassert.equal(memoryManifest.stable_release_gate?.runtime_files_frozen,true);\nassert.equal(memoryManifest.next_milestone,null);',
    'console.log("RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 stable; Memory Sync v0.2 candidate boundary OK.");': 'console.log("RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 stable boundaries OK.");',
}
for old, new in repls.items():
    if old not in release:
        raise RuntimeError(f"Release gate anchor missing: {old}")
    release = release.replace(old, new, 1)
release_path.write_text(release, encoding="utf-8")

print("Memory Sync v0.2 stable metadata/tests built; runtime HTML and Chronicle Sync core unchanged.")

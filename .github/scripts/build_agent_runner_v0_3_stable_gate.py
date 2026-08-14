from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read_json(name: str) -> dict:
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def write_json(name: str, data: dict) -> None:
    (ROOT / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


agent = read_json("RAH-RAVEN-AGENT-RUNNER-VERSION.json")
assert agent["version"] == "0.3.0"
assert agent["stage"] == "candidate"
assert agent["runtime_feature_change"] is False
assert agent["features"]["capability_set_changed"] is False
agent["stage"] = "stable"
agent["stable_since"] = "2026-08-14"
agent["development_paused"] = True
agent["change_policy"] = "bugfix-only-until-explicit-reopen"
agent["stable_release_gate"] = {
    "status": "passed",
    "gate_version": "1.0.0",
    "runtime_files_frozen": True,
}
agent["next_milestone"] = None
write_json("RAH-RAVEN-AGENT-RUNNER-VERSION.json", agent)

manifest = read_json("RAH-RAVEN-VERSION.json")
assert manifest["version"] == "2.0.32"
assert manifest["release_gate"]["runtime_feature_change"] is False
manifest["summary"] = (
    "RAH Raven 2.0.32 remains the temporary stable freeze. Vision Core v0.6, Council v0.3 "
    "and Agent Runner v0.3 are stable local-only components. Agent Runner keeps its loopback-only "
    "Bridge boundary, read-only allowlist and explicit per-run confirmation with no new runtime features."
)
manifest["privacy"]["agent_runner_stable"] = True
manifest["release_gate"]["stable_components"]["agent_runner"] = "0.3"
write_json("RAH-RAVEN-VERSION.json", manifest)

test_path = ROOT / "tests/raven-release-gate.test.mjs"
test = test_path.read_text(encoding="utf-8")
replacements = {
    'assert.equal(privacy.agent_runner_stable,false,"Agent Runner v0.3 remains candidate until its stable gate passes");':
        'assert.equal(privacy.agent_runner_stable,true,"Agent Runner v0.3 stable marker must stay true");',
    'assert.equal(manifest.release_gate?.stable_components?.raven_council,"0.3");':
        'assert.equal(manifest.release_gate?.stable_components?.raven_council,"0.3");\nassert.equal(manifest.release_gate?.stable_components?.agent_runner,"0.3");',
    'assert.equal(agentManifest.stage,"candidate");':
        'assert.equal(agentManifest.stage,"stable");\nassert.equal(agentManifest.development_paused,true);\nassert.equal(agentManifest.change_policy,"bugfix-only-until-explicit-reopen");',
    'assert.equal(agentManifest.features.capability_set_changed,false);':
        'assert.equal(agentManifest.features.capability_set_changed,false);\nassert.equal(agentManifest.stable_release_gate?.status,"passed");\nassert.equal(agentManifest.stable_release_gate?.runtime_files_frozen,true);\nassert.equal(agentManifest.next_milestone,null);',
    'console.log("RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 stable; Agent Runner v0.3 candidate boundary OK.");':
        'console.log("RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 stable boundaries OK.");',
}
for old, new in replacements.items():
    if old not in test:
        raise RuntimeError(f"Stable gate anchor missing: {old}")
    test = test.replace(old, new, 1)
test_path.write_text(test, encoding="utf-8")

print("Agent Runner v0.3 stable gate metadata and tests built; runtime files unchanged.")

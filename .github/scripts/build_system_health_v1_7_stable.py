from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

FROZEN = [
    "index.html",
    "system-health-v1.7.js",
    "SYSTEM_HEALTH_V1_7.md",
    "RAH-RAVEN-VISION-CORE.html",
    "raven-vision-core.js",
    "RAH-RAVEN-COUNCIL.html",
    "raven-council.js",
    "RAH-RAVEN-AGENT-RUNNER.html",
    "desktop-bridge/agent_runner.py",
    "RAH-RAVEN-MEMORY-SYNC.html",
    "raven-chronicle-sync.js",
    "RAH-RAVEN-MISSION-CONTROL.html",
    "RAH-RAVEN-PROJECT.html",
    "RAH-RAVEN-CORE-DEMO.html",
    "RAH-RAVEN-NOW-V2.html",
    "RAH-RAVEN-START.html",
    "RAH-RAVEN-CHRONICLE-LIVE.html",
    "desktop-bridge/server_v17.py",
    "RAH-HOME-CONTROL.html",
    "raven-checkpoint-policy.js",
]

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


def p(path: str) -> Path:
    return ROOT / path


def digest(path: str) -> str:
    return hashlib.sha256(p(path).read_bytes()).hexdigest()


before = {path: digest(path) for path in FROZEN}

component_path = p("RAH-RAVEN-SYSTEM-HEALTH-VERSION.json")
component = json.loads(component_path.read_text(encoding="utf-8"))
assert component["product"] == "RAH Raven System Health"
assert component["version"] == "1.7.0"
assert component["stage"] == "candidate"
assert component["runtime_feature_change"] is False
assert component["next_milestone"] == "stable-gate"
component.update({
    "stage": "stable",
    "next_milestone": None,
    "stable_since": "2026-08-14",
    "development_paused": True,
    "change_policy": "bugfix-only-until-explicit-reopen",
    "stable_release_gate": {
        "status": "passed",
        "gate_version": "1.0.0",
        "runtime_files_frozen": True,
    },
})
component_path.write_text(json.dumps(component, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

master_path = p("RAH-RAVEN-VERSION.json")
master = json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
assert master["privacy"]["raven_chronicle_stable"] is True
assert master["privacy"]["system_health_stable"] is False
master["privacy"]["system_health_stable"] = True
master_path.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

test_path = p("tests/system-health.test.mjs")
test = test_path.read_text(encoding="utf-8")
replacements = {
    'assert.equal(component.stage, "candidate");': 'assert.equal(component.stage, "stable");',
    'assert.equal(component.next_milestone, "stable-gate");': 'assert.equal(component.next_milestone, null);\nassert.equal(component.stable_since, "2026-08-14");\nassert.equal(component.development_paused, true);\nassert.equal(component.change_policy, "bugfix-only-until-explicit-reopen");\nassert.equal(component.stable_release_gate?.status, "passed");\nassert.equal(component.stable_release_gate?.gate_version, "1.0.0");\nassert.equal(component.stable_release_gate?.runtime_files_frozen, true);',
    'assert.equal(master.privacy.system_health_stable, false);': 'assert.equal(master.privacy.system_health_stable, true);',
    'console.log("Raven System Health v1.7 explicit-check candidate contract passed.");': 'console.log("Raven System Health v1.7 stable contract passed with runtime freeze preserved.");',
}
for old, new in replacements.items():
    if test.count(old) != 1:
        raise RuntimeError(f"Stable test anchor missing or ambiguous: {old}")
    test = test.replace(old, new, 1)
test_path.write_text(test, encoding="utf-8")

after = {path: digest(path) for path in FROZEN}
changed = [path for path in FROZEN if before[path] != after[path]]
if changed:
    raise RuntimeError(f"Stable Gate changed frozen runtime/doc(s): {changed}")

master = json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
assert master["privacy"]["raven_chronicle_stable"] is True
print("Built Raven System Health v1.7 stable metadata contract; runtime and nine-core + Chronicle set frozen.")

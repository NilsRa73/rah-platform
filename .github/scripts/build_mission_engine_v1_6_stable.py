from __future__ import annotations

import json
import subprocess
from pathlib import Path

BASE = "8dc076b62e93b37446ab0d1ba2e4a65c759343d8"
TARGETS = {
    "RAH-RAVEN-MISSION-ENGINE-VERSION.json",
    "RAH-RAVEN-VERSION.json",
    "tests/mission-engine.test.mjs",
}
TEMP = {
    ".github/scripts/build_mission_engine_v1_6_stable.py",
    ".github/workflows/build-mission-engine-v1.6-stable-gate.yml",
}

FROZEN = [
    "mission-engine.js",
    "index.html",
    "voice-control-v1.7.js",
    "RAH-RAVEN-VOICE-CONTROL-VERSION.json",
    ".github/workflows/validate-voice-control-v1.7.yml",
    "tests/voice-control-v1.7.test.mjs",
    "cloud-sync.js",
    "RAH-RAVEN-CLOUD-SYNC-VERSION.json",
    ".github/workflows/validate-cloud-sync.yml",
    "supabase/001_project_brain_sync.sql",
    "tests/cloud-sync.test.mjs",
    "RAH-RAVEN-CASE-CENTER.html",
    "RAH-RAVEN-CASE-CENTER-VERSION.json",
    "desktop-bridge/server_v16.py",
    "desktop-bridge/test_case_v16.py",
    ".github/workflows/validate-case-center-v16.yml",
    "tests/raven-case-center-v16.test.mjs",
    "RAH-RAVEN-CHRONICLE.html",
    "RAH-RAVEN-CHRONICLE-LIVE.html",
    "RAH-RAVEN-CHRONICLE-VERSION.json",
    "desktop-bridge/server_v17.py",
    ".github/workflows/validate-chronicle-v17.yml",
    "tests/raven-chronicle-v17.test.mjs",
    "system-health-v1.7.js",
    "RAH-RAVEN-SYSTEM-HEALTH-VERSION.json",
    ".github/workflows/validate-system-health.yml",
    "tests/system-health.test.mjs",
    "RAH-RAVEN-VISION-CORE.html",
    "RAH-RAVEN-VISION-VERSION.json",
    "raven-vision-core.js",
    "RAH-RAVEN-COUNCIL.html",
    "RAH-RAVEN-COUNCIL-VERSION.json",
    "raven-council.js",
    "RAH-RAVEN-AGENT-RUNNER.html",
    "RAH-RAVEN-AGENT-RUNNER-VERSION.json",
    "desktop-bridge/agent_runner.py",
    "RAH-RAVEN-MEMORY-SYNC.html",
    "RAH-RAVEN-MEMORY-SYNC-VERSION.json",
    "RAH-RAVEN-MISSION-CONTROL.html",
    "RAH-RAVEN-MISSION-CONTROL-VERSION.json",
    "RAH-RAVEN-PROJECT.html",
    "RAH-RAVEN-PROJECT-FOCUS-VERSION.json",
    "RAH-RAVEN-CORE-DEMO.html",
    "RAH-RAVEN-CORE-VERSION.json",
    "RAH-RAVEN-NOW.html",
    "RAH-RAVEN-NOW-V2.html",
    "RAH-RAVEN-NOW-VERSION.json",
    "RAH-RAVEN-START.html",
    "RAH-RAVEN-STUDIO-VERSION.json",
    "RAH-HOME-CONTROL.html",
    "RAH-HOME-CONTROL-VERSION.json",
    "raven-checkpoint-policy.js",
]

EXPECTED_STABLE_CORE = {
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


def git_bytes(ref: str, path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{ref}:{path}"])


def assert_frozen() -> None:
    changed = []
    for path in FROZEN:
        current = Path(path).read_bytes()
        baseline = git_bytes(BASE, path)
        if current != baseline:
            changed.append(path)
    if changed:
        raise SystemExit("Frozen files changed: " + ", ".join(changed))


def load_json(path: str):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path: str, data) -> None:
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


assert_frozen()

component = load_json("RAH-RAVEN-MISSION-ENGINE-VERSION.json")
if component.get("product") != "RAH Mission Engine" or component.get("version") != "1.6.0":
    raise SystemExit("Unexpected Mission Engine component manifest")
if component.get("stage") != "candidate" or component.get("next_milestone") != "stable-gate":
    raise SystemExit("Mission Engine must enter Stable Gate from candidate")
component["stage"] = "stable"
component["next_milestone"] = None
component["stable_since"] = "2026-08-15"
component["development_paused"] = True
component["change_policy"] = "bugfix-only-until-explicit-reopen"
component["stable_release_gate"] = {
    "status": "passed",
    "gate_version": "1.0.0",
    "runtime_files_frozen": True,
}
write_json("RAH-RAVEN-MISSION-ENGINE-VERSION.json", component)

master = load_json("RAH-RAVEN-VERSION.json")
if master.get("release_gate", {}).get("stable_components") != EXPECTED_STABLE_CORE:
    raise SystemExit("Core stable set changed before Mission Engine Stable Gate")
for path in ["mission-engine.js", "RAH-RAVEN-MISSION-ENGINE-VERSION.json"]:
    if path not in master["files"]:
        master["files"].append(path)
master["summary"] = (
    "RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, "
    "Project Brain Cloud Sync v1.1, Voice Control v1.7 and Mission Engine v1.6 are stable. "
    "Mission Engine keeps explicit execution and completion boundaries with no automatic step completion."
)
master["privacy"].update({
    "mission_engine_version_synced": True,
    "mission_engine_explicit_step_execution": True,
    "mission_engine_execution_requires_confirmation": True,
    "mission_engine_completion_requires_confirmation": True,
    "mission_engine_automatic_step_completion": False,
    "mission_engine_run_next_completes_waiting_step": False,
    "mission_engine_unknown_actions_rejected": True,
    "mission_engine_startup_state_write": False,
    "mission_engine_project_sync_requires_confirmation": True,
    "mission_engine_clipboard_write_requires_confirmation": True,
    "mission_engine_brain_write_requires_confirmation": True,
    "mission_engine_legacy_index_mutator_retired": True,
    "mission_engine_automatic_sending": False,
    "mission_engine_stable": True,
})
if master["release_gate"]["stable_components"] != EXPECTED_STABLE_CORE:
    raise SystemExit("Mission Engine must remain outside the nine-core stable_components set")
write_json("RAH-RAVEN-VERSION.json", master)

test_path = Path("tests/mission-engine.test.mjs")
test = test_path.read_text(encoding="utf-8")
test = test.replace("assert.equal(component.stage, 'candidate');", "assert.equal(component.stage, 'stable');")
test = test.replace(
    "assert.equal(component.next_milestone, 'stable-gate');",
    """assert.equal(component.next_milestone, null);\nassert.equal(component.stable_since, '2026-08-15');\nassert.equal(component.development_paused, true);\nassert.equal(component.change_policy, 'bugfix-only-until-explicit-reopen');\nassert.deepEqual(component.stable_release_gate, {status:'passed',gate_version:'1.0.0',runtime_files_frozen:true});\n\nassert.ok(master.files.includes('mission-engine.js'));\nassert.ok(master.files.includes('RAH-RAVEN-MISSION-ENGINE-VERSION.json'));\nassert.equal(master.privacy.mission_engine_version_synced, true);\nassert.equal(master.privacy.mission_engine_explicit_step_execution, true);\nassert.equal(master.privacy.mission_engine_execution_requires_confirmation, true);\nassert.equal(master.privacy.mission_engine_completion_requires_confirmation, true);\nassert.equal(master.privacy.mission_engine_automatic_step_completion, false);\nassert.equal(master.privacy.mission_engine_run_next_completes_waiting_step, false);\nassert.equal(master.privacy.mission_engine_unknown_actions_rejected, true);\nassert.equal(master.privacy.mission_engine_startup_state_write, false);\nassert.equal(master.privacy.mission_engine_project_sync_requires_confirmation, true);\nassert.equal(master.privacy.mission_engine_clipboard_write_requires_confirmation, true);\nassert.equal(master.privacy.mission_engine_brain_write_requires_confirmation, true);\nassert.equal(master.privacy.mission_engine_legacy_index_mutator_retired, true);\nassert.equal(master.privacy.mission_engine_automatic_sending, false);\nassert.equal(master.privacy.mission_engine_stable, true);""",
)
test = test.replace(
    "console.log('RAH Mission Engine v1.6 explicit-boundary candidate contract passed.');",
    "console.log('RAH Mission Engine v1.6 stable contract passed with runtime freeze preserved.');",
)
if "component.stage, 'candidate'" in test or "next_milestone, 'stable-gate'" in test:
    raise SystemExit("Candidate assertions remain in Mission Engine test")
test_path.write_text(test, encoding="utf-8")

subprocess.run(["node", "--check", "mission-engine.js"], check=True)
subprocess.run(["node", "tests/mission-engine.test.mjs"], check=True)
subprocess.run(["node", "tests/raven-release-gate.test.mjs"], check=True)

assert_frozen()
changed = set(subprocess.check_output(["git", "diff", "--name-only", BASE], text=True).splitlines())
expected = TARGETS | TEMP
if changed != expected:
    raise SystemExit(f"Unexpected Stable Gate diff: {sorted(changed)}; expected {sorted(expected)}")

subprocess.run(["git", "diff", "--check"], check=True)
print("Mission Engine v1.6 Stable Gate builder passed.")

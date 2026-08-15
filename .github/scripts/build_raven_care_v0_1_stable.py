from __future__ import annotations

import json
import subprocess
from pathlib import Path

BASE = "a8cfb17c3213d511f811bcf2665e59a6e2237137"
TARGETS = {
    "RAH-RAVEN-CARE-VERSION.json",
    "RAH-RAVEN-VERSION.json",
    "tests/raven-care-v0.1.test.mjs",
}
TEMP = {
    ".github/scripts/build_raven_care_v0_1_stable.py",
    ".github/workflows/build-raven-care-v0.1-stable-gate.yml",
}

# Explicitly hash the new Care surface and the parallel Command Center candidate.
# The strict diff check below protects every other file in the repository too.
FROZEN = [
    "RAH-RAVEN-CARE.html",
    "RAH-RAVEN-CARE-PROJECT-MAP.md",
    ".github/workflows/validate-raven-care-v0.1.yml",
    "RAH-COMMAND-CENTER-V0.3.html",
    "RAH-COMMAND-CENTER-VERSION.json",
    "rah-command-center-core.js",
    "tests/rah-command-center-v03.test.mjs",
    "tests/rah-command-center-core.test.mjs",
    ".github/workflows/validate-rah-command-center.yml",
    "index.html",
    "mission-engine.js",
    "voice-control-v1.7.js",
    "cloud-sync.js",
    "raven-checkpoint-policy.js",
    "RAH-HOME-CONTROL.html",
    "RAH-HOME-CONTROL-VERSION.json",
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
        if Path(path).read_bytes() != git_bytes(BASE, path):
            changed.append(path)
    if changed:
        raise SystemExit("Frozen files changed: " + ", ".join(changed))


def load_json(path: str):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path: str, data) -> None:
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


assert_frozen()

component = load_json("RAH-RAVEN-CARE-VERSION.json")
if component.get("product") != "RAH Raven Care" or component.get("version") != "0.1.0":
    raise SystemExit("Unexpected Raven Care component manifest")
if component.get("stage") != "candidate" or component.get("next_milestone") != "manual-health-fatigue-v0.2":
    raise SystemExit("Raven Care v0.1 must enter Stable Gate from the validated candidate")

component["stage"] = "stable"
component["next_milestone"] = None
component["stable_since"] = "2026-08-15"
component["development_paused"] = True
component["change_policy"] = "bugfix-only-until-explicit-reopen"
component["stable_release_gate"] = {
    "status": "passed",
    "gate_version": "1.0.0",
    "runtime_files_frozen": True,
    "runtime_feature_change": False,
}
write_json("RAH-RAVEN-CARE-VERSION.json", component)

master = load_json("RAH-RAVEN-VERSION.json")
if master.get("release_gate", {}).get("stable_components") != EXPECTED_STABLE_CORE:
    raise SystemExit("Core stable set changed before Raven Care Stable Gate")
for path in [
    "RAH-RAVEN-CARE.html",
    "RAH-RAVEN-CARE-VERSION.json",
    "RAH-RAVEN-CARE-PROJECT-MAP.md",
]:
    if path not in master["files"]:
        master["files"].append(path)
master["summary"] = (
    "RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, "
    "Project Brain Cloud Sync v1.1, Voice Control v1.7, Mission Engine v1.6 and "
    "Raven Care v0.1 are stable. Raven Care v0.1 is navigation-only, network-free "
    "and stores no dashboard health data; Command Center v0.3 remains a separate candidate."
)
master["privacy"].update({
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
    "raven_care_health_fatigue_module": False,
    "raven_care_fastlege_view": False,
    "raven_care_runtime_frozen": True,
    "raven_care_stable": True,
})
if master["release_gate"]["stable_components"] != EXPECTED_STABLE_CORE:
    raise SystemExit("Raven Care must remain outside the exact nine-core stable_components set")
write_json("RAH-RAVEN-VERSION.json", master)

test_path = Path("tests/raven-care-v0.1.test.mjs")
test = test_path.read_text(encoding="utf-8")
test = test.replace(
    'const projectMap = read("RAH-RAVEN-CARE-PROJECT-MAP.md");',
    'const projectMap = read("RAH-RAVEN-CARE-PROJECT-MAP.md");\nconst master = JSON.parse(read("RAH-RAVEN-VERSION.json"));',
)
test = test.replace('assert.equal(manifest.stage, "candidate");', 'assert.equal(manifest.stage, "stable");')
test = test.replace(
    'assert.equal(manifest.next_milestone, "manual-health-fatigue-v0.2");',
    '''assert.equal(manifest.next_milestone, null);\nassert.equal(manifest.stable_since, "2026-08-15");\nassert.equal(manifest.development_paused, true);\nassert.equal(manifest.change_policy, "bugfix-only-until-explicit-reopen");\nassert.deepEqual(manifest.stable_release_gate, {status:"passed",gate_version:"1.0.0",runtime_files_frozen:true,runtime_feature_change:false});\n\nassert.ok(master.files.includes("RAH-RAVEN-CARE.html"));\nassert.ok(master.files.includes("RAH-RAVEN-CARE-VERSION.json"));\nassert.ok(master.files.includes("RAH-RAVEN-CARE-PROJECT-MAP.md"));\nassert.equal(master.privacy.raven_care_version_synced, true);\nassert.equal(master.privacy.raven_care_navigation_only, true);\nassert.equal(master.privacy.raven_care_dashboard_data_storage, false);\nassert.equal(master.privacy.raven_care_dashboard_network_requests, false);\nassert.equal(master.privacy.raven_care_automatic_sending, false);\nassert.equal(master.privacy.raven_care_hidden_data_collection, false);\nassert.equal(master.privacy.raven_care_medical_decision_automation, false);\nassert.equal(master.privacy.raven_care_legal_decision_automation, false);\nassert.equal(master.privacy.raven_care_source_classification_visible, true);\nassert.equal(master.privacy.raven_care_synthetic_or_deidentified_demo_only, true);\nassert.equal(master.privacy.raven_care_health_fatigue_module, false);\nassert.equal(master.privacy.raven_care_fastlege_view, false);\nassert.equal(master.privacy.raven_care_runtime_frozen, true);\nassert.equal(master.privacy.raven_care_stable, true);\nassert.deepEqual(master.release_gate.stable_components, {raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"});''',
)
test = test.replace(
    'console.log("RAH Raven Care v0.1 candidate contract is stage-neutral in the UI, navigation-only, source-aware and network-free.");',
    'console.log("RAH Raven Care v0.1 Stable contract passed with navigation-only runtime frozen.");',
)
if 'manifest.stage, "candidate"' in test or 'manual-health-fatigue-v0.2' in test:
    raise SystemExit("Candidate assertions remain in Raven Care stable test")
test_path.write_text(test, encoding="utf-8")

subprocess.run(["node", "tests/raven-care-v0.1.test.mjs"], check=True)
subprocess.run(["node", "tests/raven-release-gate.test.mjs"], check=True)
subprocess.run(["node", "--test", "tests/rah-command-center-core.test.mjs"], check=True)
subprocess.run(["node", "--test", "tests/rah-command-center-v03.test.mjs"], check=True)

assert_frozen()
changed = set(subprocess.check_output(["git", "diff", "--name-only", BASE], text=True).splitlines())
expected = TARGETS | TEMP
if changed != expected:
    raise SystemExit(f"Unexpected Stable Gate diff: {sorted(changed)}; expected {sorted(expected)}")
subprocess.run(["git", "diff", "--check"], check=True)
print("RAH Raven Care v0.1 Stable Gate builder passed.")

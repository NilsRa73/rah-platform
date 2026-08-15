from __future__ import annotations

import json
import subprocess
from pathlib import Path

BASE = "e9af22b12f8997440e9d33566c75c5b9859e8a98"
TARGETS = {
    "RAH-COMMAND-CENTER-VERSION.json",
    "RAH-RAVEN-VERSION.json",
    "tests/rah-command-center-v04.test.mjs",
    "tests/rah-command-center-packaging.test.mjs",
}
TEMP = {
    ".github/scripts/build_command_center_v0_4_1_stable.py",
    ".github/workflows/build-command-center-v0.4.1-stable-gate.yml",
}
FROZEN = [
    "RAH-COMMAND-CENTER-V0.4.html",
    "rah-command-center-core.js",
    "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat",
    "UPDATE-RAH-COMMAND-CENTER.ps1",
    "UPDATE-RAH-RAVEN.ps1",
    ".github/workflows/validate-rah-command-center.yml",
    "RAH-RAVEN-FRISTVAKT.html",
    "RAH-RAVEN-FRISTVAKT-VERSION.json",
    "tests/raven-fristvakt-v0.2.test.mjs",
    ".github/workflows/validate-raven-fristvakt-v0.2.yml",
    "RAH-RAVEN-CARE.html",
    "RAH-RAVEN-CARE-VERSION.json",
    "RAH-RAVEN-CARE-PROJECT-MAP.md",
    "cloud-sync.js",
    "mission-engine.js",
    "voice-control-v1.7.js",
    "index.html",
    "raven-checkpoint-policy.js",
    "RAH-HOME-CONTROL.html",
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


def git_bytes(ref: str, path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{ref}:{path}"])


def assert_frozen() -> None:
    changed = [p for p in FROZEN if Path(p).read_bytes() != git_bytes(BASE, p)]
    if changed:
        raise SystemExit("Frozen files changed: " + ", ".join(changed))


def load_json(path: str):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path: str, data) -> None:
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


assert_frozen()

component = load_json("RAH-COMMAND-CENTER-VERSION.json")
if component.get("product") != "RAH Raven Command Center" or component.get("version") != "0.4.1":
    raise SystemExit("Unexpected Command Center candidate manifest")
if component.get("stage") != "stable-bugfix-candidate" or component.get("next_milestone") != "stable-gate":
    raise SystemExit("v0.4.1 must enter Stable Gate from the updater-integrity candidate")
if component.get("features", {}).get("stable_runtime_files_changed") is not False:
    raise SystemExit("v0.4.1 candidate unexpectedly reports runtime changes")
for flag in [
    "manual_updater_verified_commit_resolution",
    "manual_updater_immutable_commit_downloads",
    "manual_updater_stable_manifest_required",
    "manual_updater_fixed_package_allowlist",
]:
    if component["features"].get(flag) is not True:
        raise SystemExit(f"Missing updater integrity flag: {flag}")
if component["features"].get("raven_updater_remote_cc_bootstrap") is not False:
    raise SystemExit("Remote executable CC updater bootstrap must remain disabled")

component["stage"] = "stable"
component["next_milestone"] = None
component["stable_since"] = "2026-08-15"
component["development_paused"] = True
component["development_reopened"] = False
component["change_policy"] = "bugfix-only-until-explicit-reopen"
component["release_gate"] = {
    "status": "passed",
    "gate_version": "1.0.0",
    "requires_tests": [
        "tests/rah-command-center-core.test.mjs",
        "tests/rah-command-center-v04.test.mjs",
        "tests/rah-command-center-packaging.test.mjs",
    ],
    "stable_raven_runtime_frozen": True,
    "runtime_files_frozen": True,
    "change_policy": "bugfix-only-until-explicit-reopen",
}
component["runtime_feature_change"] = False
write_json("RAH-COMMAND-CENTER-VERSION.json", component)

master = load_json("RAH-RAVEN-VERSION.json")
if master.get("release_gate", {}).get("stable_components") != EXPECTED_CORE:
    raise SystemExit("Exact nine-core Stable set changed before Command Center v0.4.1 gate")
for path in [
    "RAH-COMMAND-CENTER-V0.4.html",
    "RAH-COMMAND-CENTER-VERSION.json",
    "rah-command-center-core.js",
    "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat",
    "UPDATE-RAH-COMMAND-CENTER.ps1",
    "UPDATE-RAH-RAVEN.ps1",
]:
    if path not in master["files"]:
        master["files"].append(path)
master["summary"] = (
    "RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, "
    "Project Brain Cloud Sync v1.1, Voice Control v1.7, Mission Engine v1.6, Raven Care v0.1 "
    "and RAH Raven Command Center v0.4.1 are stable. Command Center v0.4 Devices & Nodes "
    "remains metadata-only; normal startup is offline-first; manual updates are explicit, "
    "GitHub-verified and pinned to an immutable commit. Raven Fristvakt v0.2 remains a separate candidate."
)
master["privacy"].update({
    "command_center_version_synced": True,
    "command_center_stable": True,
    "command_center_runtime_frozen": True,
    "command_center_offline_first_one_click_launcher": True,
    "command_center_launcher_network_requests": False,
    "command_center_automatic_update_on_launch": False,
    "command_center_manual_updater_requires_explicit_launch": True,
    "command_center_manual_updater_verified_commit_resolution": True,
    "command_center_manual_updater_immutable_commit_downloads": True,
    "command_center_manual_updater_stable_manifest_required": True,
    "command_center_manual_updater_fixed_package_allowlist": True,
    "command_center_raven_updater_remote_cc_bootstrap": False,
    "command_center_bridge_health_explicit_only": True,
    "command_center_automatic_agent_execution": False,
    "command_center_automatic_mission_mutation": False,
    "command_center_automatic_sending": False,
    "command_center_local_device_registry": True,
    "command_center_device_metadata_local_storage_only": True,
    "command_center_network_discovery": False,
    "command_center_remote_control": False,
    "command_center_device_commands": False,
    "command_center_credential_collection": False,
})
if master["release_gate"]["stable_components"] != EXPECTED_CORE:
    raise SystemExit("Command Center must remain outside the exact nine-core Stable set")
write_json("RAH-RAVEN-VERSION.json", master)

v04_path = Path("tests/rah-command-center-v04.test.mjs")
v04 = v04_path.read_text(encoding="utf-8")
v04 = v04.replace("assert.equal(cc.stage,'stable-bugfix-candidate');", "assert.equal(cc.stage,'stable');")
v04 = v04.replace("assert.equal(cc.next_milestone,'stable-gate');", "assert.equal(cc.next_milestone,null);")
v04 = v04.replace("assert.equal(cc.release_gate.status,'candidate');", "assert.equal(cc.release_gate.status,'passed');\nassert.equal(cc.release_gate.gate_version,'1.0.0');")
v04 = v04.replace("assert.equal(cc.release_gate.runtime_files_frozen,false);", "assert.equal(cc.release_gate.runtime_files_frozen,true);")
v04 = v04.replace(
    "assert.equal(cc.runtime_feature_change,false);",
    "assert.equal(cc.runtime_feature_change,false);\nassert.equal(cc.stable_since,'2026-08-15');\nassert.equal(cc.development_paused,true);\nassert.equal(cc.development_reopened,false);\nassert.equal(cc.change_policy,'bugfix-only-until-explicit-reopen');",
)
v04 = v04.replace(
    "assert.equal(raven.privacy.raven_care_stable,true);",
    "assert.equal(raven.privacy.raven_care_stable,true);\nassert.equal(raven.privacy.command_center_stable,true);\nassert.equal(raven.privacy.command_center_runtime_frozen,true);\nassert.equal(raven.privacy.command_center_manual_updater_verified_commit_resolution,true);\nassert.equal(raven.privacy.command_center_manual_updater_immutable_commit_downloads,true);\nassert.equal(raven.privacy.command_center_manual_updater_stable_manifest_required,true);\nassert.equal(raven.privacy.command_center_manual_updater_fixed_package_allowlist,true);\nassert.equal(raven.privacy.command_center_raven_updater_remote_cc_bootstrap,false);\nassert.equal(raven.privacy.command_center_local_device_registry,true);\nassert.equal(raven.privacy.command_center_network_discovery,false);\nassert.equal(raven.privacy.command_center_remote_control,false);\nassert.equal(raven.privacy.command_center_device_commands,false);",
)
v04 = v04.replace(
    "console.log('RAH Command Center v0.4.1 updater-integrity candidate passed over frozen v0.4 Devices & Nodes runtime');",
    "console.log('RAH Command Center v0.4.1 Stable: updater integrity frozen over v0.4 Devices & Nodes runtime');",
)
if "stable-bugfix-candidate" in v04 or "next_milestone,'stable-gate'" in v04:
    raise SystemExit("Candidate assertions remain in v0.4 Stable test")
v04_path.write_text(v04, encoding="utf-8")

pkg_path = Path("tests/rah-command-center-packaging.test.mjs")
pkg = pkg_path.read_text(encoding="utf-8")
pkg = pkg.replace("assert.equal(manifest.stage,'stable-bugfix-candidate');", "assert.equal(manifest.stage,'stable');")
pkg = pkg.replace(
    "assert.equal(manifest.runtime_feature_change,false);",
    "assert.equal(manifest.runtime_feature_change,false);\n  assert.equal(manifest.stable_since,'2026-08-15');\n  assert.equal(manifest.development_paused,true);\n  assert.equal(manifest.development_reopened,false);\n  assert.equal(manifest.change_policy,'bugfix-only-until-explicit-reopen');\n  assert.equal(manifest.release_gate.status,'passed');\n  assert.equal(manifest.release_gate.runtime_files_frozen,true);",
)
if "stable-bugfix-candidate" in pkg:
    raise SystemExit("Candidate stage remains in Stable packaging test")
pkg_path.write_text(pkg, encoding="utf-8")

for cmd in [
    ["node", "--test", "tests/rah-command-center-core.test.mjs"],
    ["node", "--test", "tests/rah-command-center-v04.test.mjs"],
    ["node", "--test", "tests/rah-command-center-packaging.test.mjs"],
    ["node", "tests/raven-release-gate.test.mjs"],
    ["node", "tests/raven-care-v0.1.test.mjs"],
    ["node", "tests/raven-fristvakt-v0.2.test.mjs"],
]:
    subprocess.run(cmd, check=True)

assert_frozen()
changed = set(subprocess.check_output(["git", "diff", "--name-only", BASE], text=True).splitlines())
expected = TARGETS | TEMP
if changed != expected:
    raise SystemExit(f"Unexpected Stable Gate diff: {sorted(changed)}; expected {sorted(expected)}")
subprocess.run(["git", "diff", "--check"], check=True)
print("RAH Command Center v0.4.1 Stable Gate builder passed.")

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

BASE_SHA = "ede0a7076a1b762eb8cdc5b251892291e16ef6b9"
ROOT = Path(__file__).resolve().parents[2]
CC_MANIFEST = ROOT / "RAH-COMMAND-CENTER-VERSION.json"
RAVEN_MANIFEST = ROOT / "RAH-RAVEN-VERSION.json"
CC_TEST = ROOT / "tests/rah-command-center-v03.test.mjs"

EXPECTED_CORE = {
    "raven_vision": "0.6", "raven_council": "0.3", "agent_runner": "0.3",
    "memory_sync": "0.2", "mission_control": "2.9", "project_focus": "2.4",
    "raven_core": "1.12", "raven_now": "2.17", "raven_studio": "2.8",
}

FROZEN_CC_FILES = [
    "RAH-COMMAND-CENTER-V0.3.html",
    "rah-command-center-core.js",
    "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat",
    "UPDATE-RAH-COMMAND-CENTER.ps1",
    "UPDATE-RAH-RAVEN.ps1",
    ".github/workflows/validate-rah-command-center.yml",
    "tests/rah-command-center-core.test.mjs",
    "tests/rah-command-center-packaging.test.mjs",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def base_bytes(path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{BASE_SHA}:{path}"], cwd=ROOT)


# Freeze the complete Command Center runtime/package surface before metadata promotion.
frozen_hashes = {p: sha256_bytes(base_bytes(p)) for p in FROZEN_CC_FILES}

cc = load(CC_MANIFEST)
assert cc["product"] == "RAH Raven Command Center"
assert cc["version"] == "0.3.2"
assert cc["stage"] == "stable-bugfix-candidate"
assert cc["release_gate"]["status"] == "candidate"
assert cc["features"]["offline_first_one_click_launcher"] is True
assert cc["features"]["launcher_network_requests"] is False
assert cc["features"]["automatic_update_on_launch"] is False
assert cc["features"]["manual_updater_requires_explicit_launch"] is True
assert cc["features"]["manual_updater_network_requests"] is True
assert cc["features"]["automatic_agent_execution"] is False
assert cc["features"]["automatic_mission_mutation"] is False
assert cc["features"]["automatic_sending"] is False
assert cc["features"]["stable_runtime_files_changed"] is False

requires = cc["release_gate"]["requires_tests"]
cc["stage"] = "stable"
cc["stable_since"] = "2026-08-15"
cc["development_paused"] = True
cc["change_policy"] = "bugfix-only-until-explicit-reopen"
cc["release_gate"] = {
    "status": "passed",
    "gate_version": "1.0.0",
    "requires_tests": requires,
    "stable_raven_runtime_frozen": True,
    "runtime_files_frozen": True,
    "change_policy": "bugfix-only-until-explicit-reopen",
}
write(CC_MANIFEST, cc)

raven = load(RAVEN_MANIFEST)
assert raven["product"] == "RAH Raven"
assert raven["version"] == "2.0.32"
assert raven["release_gate"]["stable_components"] == EXPECTED_CORE
assert raven["privacy"]["raven_care_stable"] is True
assert "Command Center v0.3 remains a separate candidate" in raven["summary"]
raven["summary"] = (
    "RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, "
    "Project Brain Cloud Sync v1.1, Voice Control v1.7, Mission Engine v1.6, "
    "Raven Care v0.1 and RAH Raven Command Center v0.3.2 are stable. Command Center "
    "normal startup is offline-first; its network updater remains a separate explicit manual action."
)

cc_files = [
    "RAH-COMMAND-CENTER-V0.3.html",
    "RAH-COMMAND-CENTER-VERSION.json",
    "rah-command-center-core.js",
    "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat",
    "UPDATE-RAH-COMMAND-CENTER.ps1",
]
for p in cc_files:
    if p not in raven["files"]:
        raven["files"].append(p)

privacy = raven["privacy"]
flags = {
    "command_center_version_synced": True,
    "command_center_offline_first_one_click_launcher": True,
    "command_center_launcher_network_requests": False,
    "command_center_automatic_update_on_launch": False,
    "command_center_manual_updater_available": True,
    "command_center_manual_updater_requires_explicit_launch": True,
    "command_center_manual_updater_network_requests": True,
    "command_center_bridge_health_explicit_only": True,
    "command_center_bridge_health_loopback_only": True,
    "command_center_supporting_module_links_navigation_only": True,
    "command_center_supporting_module_stability_claims": False,
    "command_center_supporting_module_versions_hardcoded": False,
    "command_center_automatic_agent_execution": False,
    "command_center_automatic_mission_mutation": False,
    "command_center_automatic_project_activation": False,
    "command_center_automatic_sending": False,
    "command_center_hidden_capture": False,
    "command_center_runtime_frozen": True,
    "command_center_stable": True,
}
for key in flags:
    assert key not in privacy, f"Command Center master flag already exists unexpectedly: {key}"
privacy.update(flags)
assert raven["release_gate"]["stable_components"] == EXPECTED_CORE
write(RAVEN_MANIFEST, raven)

CC_TEST.write_text(r'''import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const core = require('../rah-command-center-core.js');
const raven = JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const cc = JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const html = fs.readFileSync('RAH-COMMAND-CENTER-V0.3.html','utf8');
const launcher = fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','utf8');
const expected={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};

assert.equal(cc.version,'0.3.2');
assert.equal(cc.stage,'stable');
assert.equal(cc.stable_since,'2026-08-15');
assert.equal(cc.development_paused,true);
assert.equal(cc.change_policy,'bugfix-only-until-explicit-reopen');
assert.equal(cc.release_gate.status,'passed');
assert.equal(cc.release_gate.gate_version,'1.0.0');
assert.equal(cc.release_gate.runtime_files_frozen,true);
assert.equal(cc.release_gate.stable_raven_runtime_frozen,true);
assert.equal(cc.features.offline_first_one_click_launcher,true);
assert.equal(cc.features.launcher_network_requests,false);
assert.equal(cc.features.automatic_update_on_launch,false);
assert.equal(cc.features.manual_updater_requires_explicit_launch,true);
assert.equal(cc.features.manual_updater_network_requests,true);
assert.equal(cc.features.bridge_health_check_explicit_only,true);
assert.equal(cc.features.automatic_agent_execution,false);
assert.equal(cc.features.automatic_mission_mutation,false);
assert.equal(cc.features.automatic_project_activation,false);
assert.equal(cc.features.automatic_sending,false);
assert.equal(cc.features.hidden_capture,false);
assert.equal(cc.features.stage_neutral_runtime_label,true);
assert.equal(cc.features.supporting_module_stability_claims,false);
assert.equal(cc.features.supporting_module_versions_hardcoded,false);

assert.deepEqual(raven.release_gate.stable_components,expected);
assert.equal(raven.privacy.raven_care_stable,true);
assert.equal(raven.privacy.command_center_version_synced,true);
assert.equal(raven.privacy.command_center_offline_first_one_click_launcher,true);
assert.equal(raven.privacy.command_center_launcher_network_requests,false);
assert.equal(raven.privacy.command_center_automatic_update_on_launch,false);
assert.equal(raven.privacy.command_center_manual_updater_requires_explicit_launch,true);
assert.equal(raven.privacy.command_center_bridge_health_explicit_only,true);
assert.equal(raven.privacy.command_center_automatic_agent_execution,false);
assert.equal(raven.privacy.command_center_automatic_mission_mutation,false);
assert.equal(raven.privacy.command_center_automatic_sending,false);
assert.equal(raven.privacy.command_center_runtime_frozen,true);
assert.equal(raven.privacy.command_center_stable,true);
for (const p of ['RAH-COMMAND-CENTER-V0.3.html','RAH-COMMAND-CENTER-VERSION.json','rah-command-center-core.js','DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','UPDATE-RAH-COMMAND-CENTER.ps1']) assert.ok(raven.files.includes(p));
assert.match(raven.summary,/Command Center v0\.3\.2 are stable/);
assert.match(raven.summary,/normal startup is offline-first/);

const snapshot=core.buildCoreSnapshot(raven,'manifest');
assert.equal(snapshot.stableCount,9);
assert.match(html,/PACKAGE MODULES/);
assert.match(html,/PACKAGED/);
assert.match(html,/Not checked\. CC v0\.3\.2 never probes the Bridge until you click the button\./);
assert.doesNotMatch(html,/v0\.3(?:\.2)? candidate/i);
assert.doesNotMatch(html,/Stable local supporting module/);
assert.doesNotMatch(html,/core\.EXTRA_COMPONENTS/);
assert.doesNotMatch(html,/\/agent\/run|setInterval\s*\(|navigator\.mediaDevices|getUserMedia|clipboard\.readText/i);
assert.match(launcher,/start "" "%CC_PAGE%"/);
assert.doesNotMatch(launcher,/Invoke-WebRequest|powershell|pwsh|raw\.githubusercontent\.com|https?:\/\//i);
console.log('RAH Command Center v0.3.2 Stable contract passed: runtime frozen, offline-first normal launch, manual updater explicit, exact nine Raven core components preserved.');
''', encoding="utf-8")

# Stable Gate regressions.
for test in (
    "tests/rah-command-center-core.test.mjs",
    "tests/rah-command-center-v03.test.mjs",
    "tests/rah-command-center-packaging.test.mjs",
    "tests/raven-release-gate.test.mjs",
    "tests/raven-care-v0.1.test.mjs",
):
    subprocess.run(["node", "--test", test], cwd=ROOT, check=True)

# Runtime/package freeze guard.
for p, expected_hash in frozen_hashes.items():
    actual = sha256_bytes((ROOT / p).read_bytes())
    assert actual == expected_hash, f"Frozen Command Center file changed in Stable Gate: {p}"

allowed = {
    ".github/scripts/build_rah_cc_v0_3_2_stable.py",
    ".github/workflows/build-rah-cc-v0.3.2-stable-gate.yml",
    "RAH-COMMAND-CENTER-VERSION.json",
    "RAH-RAVEN-VERSION.json",
    "tests/rah-command-center-v03.test.mjs",
}
changed = set(subprocess.check_output(["git", "diff", "--name-only", BASE_SHA], cwd=ROOT, text=True).splitlines())
extra = changed - allowed
assert not extra, f"Stable Gate touched non-allowlisted files: {sorted(extra)}"
assert raven["release_gate"]["stable_components"] == EXPECTED_CORE
print('RAH Command Center v0.3.2 Stable Gate passed with a runtime-frozen three-product-file diff.')

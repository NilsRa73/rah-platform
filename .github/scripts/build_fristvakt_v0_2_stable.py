from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "RAH-RAVEN-FRISTVAKT-VERSION.json"
MASTER = ROOT / "RAH-RAVEN-VERSION.json"
TEST = ROOT / "tests/raven-fristvakt-v0.2.test.mjs"

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

FROZEN = [
    "RAH-RAVEN-FRISTVAKT.html",
    ".github/workflows/validate-raven-fristvakt-v0.2.yml",
    "RAH-RAVEN-CARE.html",
    "RAH-RAVEN-CARE-VERSION.json",
    "RAH-RAVEN-CASE-CENTER.html",
    "desktop-bridge/server_v16.py",
    "RAH-COMMAND-CENTER-V0.4.html",
    "rah-command-center-core.js",
    "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat",
    "UPDATE-RAH-COMMAND-CENTER.ps1",
    "raven-checkpoint-policy.js",
    "RAH-RAVEN-VISION-CORE.html",
    "raven-vision-core.js",
    "RAH-RAVEN-COUNCIL.html",
    "raven-council.js",
    "RAH-RAVEN-MISSION-CONTROL.html",
    "RAH-RAVEN-NOW.html",
    "RAH-RAVEN-CORE-DEMO.html",
]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


before = {name: digest(ROOT / name) for name in FROZEN}

manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
assert manifest["product"] == "RAH Raven Fristvakt"
assert manifest["version"] == "0.2.0"
assert manifest["stage"] == "candidate"
assert manifest["release_gate"]["status"] == "candidate"
manifest["stage"] = "stable"
manifest["next_milestone"] = None
manifest["stable_since"] = "2026-08-15"
manifest["development_paused"] = True
manifest["change_policy"] = "bugfix-only-until-explicit-reopen"
manifest["release_gate"]["status"] = "passed"
manifest["release_gate"]["gate_version"] = "1.0.0"
manifest["release_gate"]["runtime_files_frozen"] = True
manifest["release_gate"]["change_policy"] = "bugfix-only-until-explicit-reopen"
MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

master = json.loads(MASTER.read_text(encoding="utf-8"))
assert master["version"] == "2.0.32"
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
assert master["privacy"]["raven_care_stable"] is True
assert master["privacy"]["case_center_stable"] is True
assert master["privacy"]["command_center_stable"] is True
files = master["files"]
if "RAH-RAVEN-FRISTVAKT-VERSION.json" not in files:
    pos = files.index("RAH-RAVEN-FRISTVAKT.html") + 1
    files.insert(pos, "RAH-RAVEN-FRISTVAKT-VERSION.json")
master["privacy"].update({
    "raven_fristvakt_version_synced": True,
    "raven_fristvakt_support_tool_only": True,
    "raven_fristvakt_authoritative_decision": False,
    "raven_fristvakt_session_memory_only": True,
    "raven_fristvakt_automatic_persistence": False,
    "raven_fristvakt_browser_storage": False,
    "raven_fristvakt_explicit_json_export": True,
    "raven_fristvakt_explicit_json_import": True,
    "raven_fristvakt_automatic_network_requests": False,
    "raven_fristvakt_official_links_explicit_click_only": True,
    "raven_fristvakt_hardcoded_contact_number": False,
    "raven_fristvakt_result_requires_user_confirmation": True,
    "raven_fristvakt_runtime_frozen": True,
    "raven_fristvakt_stable": True,
})
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
MASTER.write_text(json.dumps(master, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

text = TEST.read_text(encoding="utf-8")
text = text.replace("assert.equal(manifest.stage,'candidate');", "assert.equal(manifest.stage,'stable');")
text = text.replace("assert.equal(manifest.release_gate.status,'candidate');", "assert.equal(manifest.release_gate.status,'passed');\nassert.equal(manifest.release_gate.runtime_files_frozen,true);\nassert.equal(manifest.development_paused,true);\nassert.equal(manifest.change_policy,'bugfix-only-until-explicit-reopen');")
needle = "assert.equal(raven.privacy.command_center_stable,true);"
replacement = needle + "\nassert.equal(raven.privacy.raven_fristvakt_version_synced,true);\nassert.equal(raven.privacy.raven_fristvakt_session_memory_only,true);\nassert.equal(raven.privacy.raven_fristvakt_automatic_persistence,false);\nassert.equal(raven.privacy.raven_fristvakt_browser_storage,false);\nassert.equal(raven.privacy.raven_fristvakt_automatic_network_requests,false);\nassert.equal(raven.privacy.raven_fristvakt_hardcoded_contact_number,false);\nassert.equal(raven.privacy.raven_fristvakt_runtime_frozen,true);\nassert.equal(raven.privacy.raven_fristvakt_stable,true);"
assert needle in text
text = text.replace(needle, replacement)
TEST.write_text(text, encoding="utf-8")

for name, expected in before.items():
    actual = digest(ROOT / name)
    if actual != expected:
        raise SystemExit(f"Frozen runtime changed: {name}")

run("node", "tests/raven-fristvakt-v0.2.test.mjs")
run("node", "tests/raven-release-gate.test.mjs")
run("node", "tests/raven-care-v0.1.test.mjs")
run("node", "tests/raven-case-center-v16.test.mjs")
run("node", "tests/rah-command-center-v04.test.mjs")

changed = subprocess.check_output(["git", "diff", "--name-only"], cwd=ROOT, text=True).splitlines()
expected = sorted([
    "RAH-RAVEN-FRISTVAKT-VERSION.json",
    "RAH-RAVEN-VERSION.json",
    "tests/raven-fristvakt-v0.2.test.mjs",
])
if sorted(changed) != expected:
    raise SystemExit(f"Unexpected Stable Gate diff: {changed}")

print("RAH Raven Fristvakt v0.2 Stable Gate passed with runtime frozen")

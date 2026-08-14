from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

FROZEN = [
    "RAH-RAVEN-CHRONICLE-LIVE.html",
    "desktop-bridge/server_v17.py",
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


def p(path: str) -> Path:
    return ROOT / path


def digest(path: str) -> str:
    return hashlib.sha256(p(path).read_bytes()).hexdigest()


before = {path: digest(path) for path in FROZEN}

component_path = p("RAH-RAVEN-CHRONICLE-VERSION.json")
component = json.loads(component_path.read_text(encoding="utf-8"))
assert component["product"] == "RAH Raven Chronicle"
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
assert master["privacy"]["raven_chronicle_stable"] is False
master["privacy"]["raven_chronicle_stable"] = True
master_path.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

stable_test = '''import assert from "node:assert/strict";\nimport fs from "node:fs";\n\nconst html=fs.readFileSync("RAH-RAVEN-CHRONICLE-LIVE.html","utf8");\nconst component=JSON.parse(fs.readFileSync("RAH-RAVEN-CHRONICLE-VERSION.json","utf8"));\nconst master=JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json","utf8"));\n\nassert.match(html,/CHRONICLE LIVE · DESKTOP BRIDGE v1\\.7/);\nassert.match(html,/RAH Raven Chronicle v1\\.7 · lokal-first · menneskestyrt samtykke/);\nassert.match(html,/const BASE='http:\\/\\/127\\.0\\.0\\.1:18765'/);\nassert.match(html,/refresh\\(\\);setInterval\\(refresh,5000\\)/);\nassert.match(html,/post\\('\\/chronicle\\/session\\/start'/);\nassert.doesNotMatch(html,/setInterval\\([^\\n]*session\\/start|refresh\\([^)]*session\\/start/);\n\nassert.equal(component.product,"RAH Raven Chronicle");\nassert.equal(component.version,"1.7.0");\nassert.equal(component.stage,"stable");\nassert.equal(component.runtime_feature_change,false);\nassert.equal(component.features.visible_session_required_for_foreground_read,true);\nassert.equal(component.features.paused_blocks_foreground_read,true);\nassert.equal(component.features.status_polling_reads_foreground_when_stopped,false);\nassert.equal(component.features.status_polling_reads_foreground_when_paused,false);\nassert.equal(component.features.active_window_endpoint_requires_active_unpaused_session,true);\nassert.equal(component.features.browser_bridge_loopback_only,true);\nassert.equal(component.features.keylogging,false);\nassert.equal(component.features.clipboard_capture,false);\nassert.equal(component.features.audio_capture,false);\nassert.equal(component.features.camera_capture,false);\nassert.equal(component.features.automatic_sending,false);\nassert.equal(component.features.capability_set_changed,false);\nassert.equal(component.next_milestone,null);\nassert.equal(component.stable_since,"2026-08-14");\nassert.equal(component.development_paused,true);\nassert.equal(component.change_policy,"bugfix-only-until-explicit-reopen");\nassert.equal(component.stable_release_gate?.status,"passed");\nassert.equal(component.stable_release_gate?.gate_version,"1.0.0");\nassert.equal(component.stable_release_gate?.runtime_files_frozen,true);\n\nconst stable={raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};\nassert.deepEqual(master.release_gate.stable_components,stable);\nassert.ok(master.files.includes("RAH-RAVEN-CHRONICLE-VERSION.json"));\nassert.equal(master.privacy.raven_chronicle_version_synced,true);\nassert.equal(master.privacy.raven_chronicle_observation_requires_active_session,true);\nassert.equal(master.privacy.raven_chronicle_paused_blocks_foreground_read,true);\nassert.equal(master.privacy.raven_chronicle_foreground_read_when_stopped,false);\nassert.equal(master.privacy.raven_chronicle_foreground_read_when_paused,false);\nassert.equal(master.privacy.raven_chronicle_keylogging,false);\nassert.equal(master.privacy.raven_chronicle_clipboard_capture,false);\nassert.equal(master.privacy.raven_chronicle_audio_capture,false);\nassert.equal(master.privacy.raven_chronicle_camera_capture,false);\nassert.equal(master.privacy.raven_chronicle_automatic_sending,false);\nassert.equal(master.privacy.raven_chronicle_stable,true);\nconsole.log("Raven Chronicle v1.7 stable contract passed with nine-core freeze preserved.");\n'''
p("tests/raven-chronicle-v17.test.mjs").write_text(stable_test, encoding="utf-8")

# Ensure Stable Gate itself made no runtime changes.
after = {path: digest(path) for path in FROZEN}
changed = [path for path in FROZEN if before[path] != after[path]]
if changed:
    raise RuntimeError(f"Stable Gate changed frozen runtime(s): {changed}")

# Re-assert core list after all metadata work.
master = json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
print("Built Raven Chronicle v1.7 stable metadata contract; Chronicle runtime and nine-core runtime set frozen.")

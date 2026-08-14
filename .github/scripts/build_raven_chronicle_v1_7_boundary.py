from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

FROZEN = [
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


def p(path: str) -> Path:
    return ROOT / path


def digest(path: str) -> str:
    return hashlib.sha256(p(path).read_bytes()).hexdigest()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor, got {count}")
    return text.replace(old, new, 1)


before = {path: digest(path) for path in FROZEN}

# 1) Backend: sync Chronicle identity and make stopped/paused state block the
# actual foreground-window read, not only event persistence.
server_path = p("desktop-bridge/server_v17.py")
server = server_path.read_text(encoding="utf-8")
server = replace_once(
    server,
    'CHRONICLE_VERSION = "1.0"',
    'CHRONICLE_VERSION = "1.7.0"',
    "Chronicle version",
)
server = replace_once(
    server,
    "def _foreground_window_safe() -> dict[str, Any]:\n    return _privacy_filter(_foreground_window_raw(), _load_config())\n\n\ndef _observer_loop() -> None:\n",
    "def _foreground_window_safe() -> dict[str, Any]:\n    return _privacy_filter(_foreground_window_raw(), _load_config())\n\n\ndef _observation_window_for_state(state: dict[str, Any]) -> dict[str, Any]:\n    \"\"\"Read the foreground window only inside an active, unpaused session.\"\"\"\n    if not state.get(\"recording\") or not state.get(\"session\"):\n        return {\n            \"available\": False,\n            \"reason\": \"Chronicle-observasjon er stoppet. Start en synlig økt for å lese aktivt vindu.\",\n            \"observation_allowed\": False,\n        }\n    if state.get(\"paused\"):\n        return {\n            \"available\": False,\n            \"reason\": \"Chronicle-observasjon er pauset.\",\n            \"observation_allowed\": False,\n        }\n    window = _foreground_window_safe()\n    window[\"observation_allowed\"] = True\n    return window\n\n\ndef _observer_loop() -> None:\n",
    "observation boundary helper",
)
server = replace_once(
    server,
    '        "active_window": _foreground_window_safe(),',
    '        "active_window": _observation_window_for_state(state),',
    "status observation boundary",
)
server = replace_once(
    server,
    '            "privacy_redaction": True,\n',
    '            "privacy_redaction": True,\n            "foreground_read_requires_active_session": True,\n            "paused_blocks_foreground_read": True,\n',
    "status safeguards",
)
server = replace_once(
    server,
    '@app.get("/chronicle/active-window")\ndef chronicle_active_window():\n    return jsonify({"ok": True, "window": _foreground_window_safe()})\n',
    '@app.get("/chronicle/active-window")\ndef chronicle_active_window():\n    state = _load_state()\n    return jsonify({"ok": True, "window": _observation_window_for_state(state)})\n',
    "active-window observation boundary",
)
server_path.write_text(server, encoding="utf-8")

# 2) UI identity only. The UI may keep polling status while stopped because the
# backend status path no longer reads foreground-window metadata outside consent.
html_path = p("RAH-RAVEN-CHRONICLE-LIVE.html")
html = html_path.read_text(encoding="utf-8")
html = replace_once(
    html,
    "RAH Raven Chronicle v1.0 · lokal-first · menneskestyrt samtykke",
    "RAH Raven Chronicle v1.7 · lokal-first · menneskestyrt samtykke",
    "Chronicle footer identity",
)
html_path.write_text(html, encoding="utf-8")

# 3) Explicit component candidate contract.
manifest = {
    "product": "RAH Raven Chronicle",
    "version": "1.7.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "RAH-RAVEN-CHRONICLE-LIVE.html",
    "backend": "desktop-bridge/server_v17.py",
    "local_only": True,
    "runtime_feature_change": False,
    "features": {
        "visible_session_required_for_foreground_read": True,
        "paused_blocks_foreground_read": True,
        "status_polling_reads_foreground_when_stopped": False,
        "status_polling_reads_foreground_when_paused": False,
        "active_window_endpoint_requires_active_unpaused_session": True,
        "browser_bridge_loopback_only": True,
        "bridge_base": "http://127.0.0.1:18765",
        "window_title_redaction": True,
        "keylogging": False,
        "clipboard_capture": False,
        "audio_capture": False,
        "camera_capture": False,
        "automatic_sending": False,
        "manual_events_explicit": True,
        "local_event_storage": True,
        "capability_set_changed": False,
    },
    "next_milestone": "stable-gate",
}
p("RAH-RAVEN-CHRONICLE-VERSION.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)

# 4) Master package/privacy contract; stable core set remains exactly nine.
master_path = p("RAH-RAVEN-VERSION.json")
master = json.loads(master_path.read_text(encoding="utf-8"))
files = master["files"]
if "RAH-RAVEN-CHRONICLE-VERSION.json" not in files:
    anchor = files.index("RAH-RAVEN-CHRONICLE-LIVE.html") + 1
    files.insert(anchor, "RAH-RAVEN-CHRONICLE-VERSION.json")
privacy = master["privacy"]
privacy.update({
    "raven_chronicle_version_synced": True,
    "raven_chronicle_observation_requires_active_session": True,
    "raven_chronicle_paused_blocks_foreground_read": True,
    "raven_chronicle_foreground_read_when_stopped": False,
    "raven_chronicle_foreground_read_when_paused": False,
    "raven_chronicle_keylogging": False,
    "raven_chronicle_clipboard_capture": False,
    "raven_chronicle_audio_capture": False,
    "raven_chronicle_camera_capture": False,
    "raven_chronicle_automatic_sending": False,
    "raven_chronicle_stable": False,
})
expected_stable = {
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
if master["release_gate"]["stable_components"] != expected_stable:
    raise RuntimeError("Stable core contract moved while building Chronicle candidate")
master_path.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# 5) Backend regression test now proves the foreground-reader is never invoked
# while stopped or paused.
test_path = p("desktop-bridge/test_chronicle_v17.py")
test = test_path.read_text(encoding="utf-8")
test = replace_once(
    test,
    '        module._foreground_window_safe = lambda: {\n            "available": True,\n            "platform": "Windows",\n            "app": "test.exe",\n            "title": "Testvindu",\n            "pid": 123,\n            "redacted": False,\n        }\n',
    '        reads = {"count": 0}\n\n        def fake_foreground_window_safe():\n            reads["count"] += 1\n            return {\n                "available": True,\n                "platform": "Windows",\n                "app": "test.exe",\n                "title": "Testvindu",\n                "pid": 123,\n                "redacted": False,\n            }\n\n        module._foreground_window_safe = fake_foreground_window_safe\n        assert module.CHRONICLE_VERSION == "1.7.0"\n',
    "test foreground counter",
)
test = replace_once(
    test,
    '        assert status.get_json()["recording"] is False\n\n        started = client.post(\n',
    '        status_data = status.get_json()\n        assert status_data["recording"] is False\n        assert status_data["active_window"]["available"] is False\n        assert status_data["active_window"]["observation_allowed"] is False\n        assert status_data["safeguards"]["foreground_read_requires_active_session"] is True\n        assert status_data["safeguards"]["paused_blocks_foreground_read"] is True\n        assert reads["count"] == 0\n        stopped_window = client.get("/chronicle/active-window").get_json()["window"]\n        assert stopped_window["available"] is False\n        assert reads["count"] == 0\n\n        started = client.post(\n',
    "test stopped observation boundary",
)
test = replace_once(
    test,
    '        assert started.get_json()["session"]["project"] == "RAH Test"\n\n        manual = client.post(\n',
    '        assert started.get_json()["session"]["project"] == "RAH Test"\n        running_status = client.get("/chronicle/status").get_json()\n        assert running_status["active_window"]["available"] is True\n        assert running_status["active_window"]["observation_allowed"] is True\n        assert reads["count"] == 1\n\n        manual = client.post(\n',
    "test active observation allowed",
)
test = replace_once(
    test,
    '        paused = client.post("/chronicle/pause")\n        assert paused.status_code == 200\n        resumed = client.post("/chronicle/resume")\n        assert resumed.status_code == 200\n\n        stopped = client.post("/chronicle/session/stop")\n',
    '        paused = client.post("/chronicle/pause")\n        assert paused.status_code == 200\n        paused_status = client.get("/chronicle/status").get_json()\n        assert paused_status["active_window"]["available"] is False\n        assert paused_status["active_window"]["observation_allowed"] is False\n        assert reads["count"] == 1\n        paused_window = client.get("/chronicle/active-window").get_json()["window"]\n        assert paused_window["available"] is False\n        assert reads["count"] == 1\n        resumed = client.post("/chronicle/resume")\n        assert resumed.status_code == 200\n        resumed_status = client.get("/chronicle/status").get_json()\n        assert resumed_status["active_window"]["available"] is True\n        assert reads["count"] == 2\n\n        stopped = client.post("/chronicle/session/stop")\n',
    "test paused observation boundary",
)
test = replace_once(
    test,
    '        assert stopped.status_code == 200\n\n        events = client.get("/chronicle/events?limit=50").get_json()["events"]\n',
    '        assert stopped.status_code == 200\n        final_status = client.get("/chronicle/status").get_json()\n        assert final_status["active_window"]["available"] is False\n        assert reads["count"] == 2\n\n        events = client.get("/chronicle/events?limit=50").get_json()["events"]\n',
    "test final stopped boundary",
)
test_path.write_text(test, encoding="utf-8")

# 6) Browser/component semantic contract.
semantic = '''import assert from "node:assert/strict";\nimport fs from "node:fs";\n\nconst html=fs.readFileSync("RAH-RAVEN-CHRONICLE-LIVE.html","utf8");\nconst component=JSON.parse(fs.readFileSync("RAH-RAVEN-CHRONICLE-VERSION.json","utf8"));\nconst master=JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json","utf8"));\n\nassert.match(html,/CHRONICLE LIVE · DESKTOP BRIDGE v1\\.7/);\nassert.match(html,/RAH Raven Chronicle v1\\.7 · lokal-first · menneskestyrt samtykke/);\nassert.match(html,/const BASE='http:\\/\\/127\\.0\\.0\\.1:18765'/);\nassert.match(html,/refresh\\(\\);setInterval\\(refresh,5000\\)/);\nassert.match(html,/post\\('\/chronicle\/session\/start'/);\nassert.doesNotMatch(html,/setInterval\\([^\\n]*session\\/start|refresh\\([^)]*session\\/start/);\n\nassert.equal(component.product,"RAH Raven Chronicle");\nassert.equal(component.version,"1.7.0");\nassert.equal(component.stage,"candidate");\nassert.equal(component.runtime_feature_change,false);\nassert.equal(component.features.visible_session_required_for_foreground_read,true);\nassert.equal(component.features.paused_blocks_foreground_read,true);\nassert.equal(component.features.status_polling_reads_foreground_when_stopped,false);\nassert.equal(component.features.status_polling_reads_foreground_when_paused,false);\nassert.equal(component.features.active_window_endpoint_requires_active_unpaused_session,true);\nassert.equal(component.features.browser_bridge_loopback_only,true);\nassert.equal(component.features.keylogging,false);\nassert.equal(component.features.clipboard_capture,false);\nassert.equal(component.features.audio_capture,false);\nassert.equal(component.features.camera_capture,false);\nassert.equal(component.features.automatic_sending,false);\nassert.equal(component.features.capability_set_changed,false);\nassert.equal(component.next_milestone,"stable-gate");\n\nconst stable={raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};\nassert.deepEqual(master.release_gate.stable_components,stable);\nassert.ok(master.files.includes("RAH-RAVEN-CHRONICLE-VERSION.json"));\nassert.equal(master.privacy.raven_chronicle_version_synced,true);\nassert.equal(master.privacy.raven_chronicle_observation_requires_active_session,true);\nassert.equal(master.privacy.raven_chronicle_paused_blocks_foreground_read,true);\nassert.equal(master.privacy.raven_chronicle_foreground_read_when_stopped,false);\nassert.equal(master.privacy.raven_chronicle_foreground_read_when_paused,false);\nassert.equal(master.privacy.raven_chronicle_stable,false);\nconsole.log("Raven Chronicle v1.7 explicit observation boundary candidate contract passed.");\n'''
p("tests/raven-chronicle-v17.test.mjs").write_text(semantic, encoding="utf-8")

# Freeze guard: the candidate must not alter any already-stable runtime surface.
after = {path: digest(path) for path in FROZEN}
changed_frozen = [path for path in FROZEN if before[path] != after[path]]
if changed_frozen:
    raise RuntimeError(f"Frozen runtime changed: {changed_frozen}")

print("Built Raven Chronicle v1.7 explicit observation boundary candidate.")

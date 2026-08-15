from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

ALLOWED = {
    "desktop-bridge/server_v17.py",
    "desktop-bridge/test_chronicle_v17.py",
    "RAH-RAVEN-CHRONICLE-VERSION.json",
    "RAH-RAVEN-VERSION.json",
    "tests/raven-chronicle-v17.test.mjs",
}

FROZEN = [
    "RAH-RAVEN-CHRONICLE-LIVE.html",
    "RAH-RAVEN-INSIGHTS.html",
    "RAH-RAVEN-DAILY-BRIEF.html",
    "desktop-bridge/chronicle_insights.py",
    "desktop-bridge/chronicle_ai.py",
    "desktop-bridge/raven_bridge.py",
    "desktop-bridge/server_v16.py",
    "RAH-RAVEN-FRISTVAKT.html",
    "RAH-RAVEN-FRISTVAKT-VERSION.json",
    "RAH-RAVEN-CASE-CENTER.html",
    "RAH-RAVEN-CASE-CENTER-VERSION.json",
    "RAH-COMMAND-CENTER-V0.5.html",
    "RAH-COMMAND-CENTER-VERSION.json",
    "rah-command-center-core.js",
    "rah-node-agent.py",
    "RAH-RAVEN-VISION-CORE.html",
    "raven-vision-core.js",
    "RAH-RAVEN-COUNCIL.html",
    "raven-council.js",
    "RAH-RAVEN-AGENT-RUNNER.html",
    "RAH-RAVEN-MEMORY-SYNC.html",
    "RAH-RAVEN-MISSION-CONTROL.html",
    "RAH-RAVEN-PROJECT.html",
    "RAH-RAVEN-CORE-DEMO.html",
    "RAH-RAVEN-NOW.html",
    "RAH-RAVEN-NOW-V2.html",
    "RAH-RAVEN-START.html",
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


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(*args: str, cwd: Path = ROOT) -> None:
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    subprocess.run(args, cwd=cwd, env=env, check=True)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"Expected exactly one {label} anchor, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    before = {name: sha(ROOT / name) for name in FROZEN}

    manifest_path = ROOT / "RAH-RAVEN-CHRONICLE-VERSION.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("version") != "1.7.0" or manifest.get("stage") != "stable":
        raise RuntimeError("Chronicle v1.7.0 Stable is required as the bugfix base")

    master_path = ROOT / "RAH-RAVEN-VERSION.json"
    master = json.loads(master_path.read_text(encoding="utf-8"))
    if master.get("release_gate", {}).get("stable_components") != EXPECTED_CORE:
        raise RuntimeError("Nine-core stable set changed before Chronicle bugfix")
    privacy = master.setdefault("privacy", {})
    if privacy.get("raven_chronicle_stable") is not True:
        raise RuntimeError("Chronicle must start from Stable")
    if privacy.get("raven_fristvakt_stable") is not True:
        raise RuntimeError("Fristvakt Stable must remain frozen")

    server_path = ROOT / "desktop-bridge/server_v17.py"
    server = server_path.read_text(encoding="utf-8")
    server = replace_once(
        server,
        "from server_v16 import HOST, PORT, app",
        "from server_v16 import HOST, LOCAL_BROWSER_ORIGINS, PORT, app",
        "server_v16 import",
    )
    server = replace_once(
        server,
        'APP_VERSION = "1.7.0"\nCHRONICLE_VERSION = "1.7.0"',
        'APP_VERSION = "1.7.1"\nCHRONICLE_VERSION = "1.7.1"',
        "Chronicle version",
    )
    guard = '''\n\nCHRONICLE_PROTECTED_PREFIX = "/chronicle"\n\n\n@app.before_request\ndef protect_chronicle_local_apis():\n    path = request.path\n    if path != CHRONICLE_PROTECTED_PREFIX and not path.startswith(CHRONICLE_PROTECTED_PREFIX + "/"):\n        return None\n    origin = (request.headers.get("Origin") or "").rstrip("/")\n    if origin and origin not in LOCAL_BROWSER_ORIGINS:\n        return jsonify({\n            "ok": False,\n            "error": "Dette lokale Chronicle-endepunktet er ikke tilgjengelig fra fremmede nettsteder.",\n        }), 403\n    return None\n'''
    server = replace_once(
        server,
        '\n\n@app.get("/chronicle/status")',
        guard + '\n\n@app.get("/chronicle/status")',
        "Chronicle route guard",
    )
    server_path.write_text(server, encoding="utf-8")

    test_path = ROOT / "desktop-bridge/test_chronicle_v17.py"
    test = test_path.read_text(encoding="utf-8")
    test = replace_once(
        test,
        'assert module.CHRONICLE_VERSION == "1.7.0"',
        'assert module.CHRONICLE_VERSION == "1.7.1"',
        "test Chronicle version",
    )
    origin_tests = '''\n\n        foreign = {"Origin": "https://foreign.example"}\n        blocked_start = client.post("/chronicle/session/start", headers=foreign)\n        assert blocked_start.status_code == 403\n        blocked_pause = client.post("/chronicle/pause", headers=foreign)\n        assert blocked_pause.status_code == 403\n        blocked_event = client.post(\n            "/chronicle/event",\n            headers=foreign,\n            data={"title": "Skal ikke lagres"},\n        )\n        assert blocked_event.status_code == 403\n        blocked_config = client.post(\n            "/chronicle/config",\n            headers=foreign,\n            data={"poll_seconds": "2"},\n        )\n        assert blocked_config.status_code == 403\n        blocked_export = client.get("/chronicle/export", headers=foreign)\n        assert blocked_export.status_code == 403\n\n        after_block = client.get("/chronicle/status").get_json()\n        assert after_block["recording"] is False\n        assert after_block["event_count"] == 0\n        assert client.get("/chronicle/status", headers={"Origin": "null"}).status_code == 200\n        local_origin = {"Origin": f"http://127.0.0.1:{module.PORT}"}\n        assert client.get("/chronicle/status", headers=local_origin).status_code == 200\n'''
    test = replace_once(
        test,
        '        client = module.app.test_client()\n\n        status = client.get("/chronicle/status")',
        '        client = module.app.test_client()' + origin_tests + '\n        status = client.get("/chronicle/status")',
        "origin regression insertion",
    )
    test_path.write_text(test, encoding="utf-8")

    manifest["version"] = "1.7.1"
    manifest["stage"] = "stable-bugfix-candidate"
    manifest["previous_stable_version"] = "1.7.0"
    manifest["runtime_feature_change"] = False
    features = manifest.setdefault("features", {})
    features["foreign_browser_origin_guard"] = True
    features["chronicle_routes_local_browser_origin_only"] = True
    features["cross_origin_mutation_blocked"] = True
    features["cors_wildcard"] = False
    manifest["next_milestone"] = "stable-gate"
    manifest.pop("stable_since", None)
    manifest["development_reopened"] = True
    manifest["development_paused"] = False
    manifest["change_policy"] = "bugfix-only"
    manifest["stable_release_gate"] = {
        "status": "candidate",
        "gate_version": "1.1.0",
        "runtime_files_frozen": False,
        "stable_raven_runtime_frozen": True,
        "change_policy": "bugfix-only",
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    privacy["raven_chronicle_foreign_browser_origin_guard"] = True
    privacy["raven_chronicle_routes_local_browser_origin_only"] = True
    privacy["raven_chronicle_cross_origin_mutation_blocked"] = True
    privacy["raven_chronicle_cors_wildcard"] = False
    privacy["raven_chronicle_bugfix_candidate"] = True
    privacy["raven_chronicle_candidate_over_previous_stable"] = True
    master_path.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    semantic = '''import assert from "node:assert/strict";\nimport fs from "node:fs";\n\nconst html=fs.readFileSync("RAH-RAVEN-CHRONICLE-LIVE.html","utf8");\nconst server=fs.readFileSync("desktop-bridge/server_v17.py","utf8");\nconst component=JSON.parse(fs.readFileSync("RAH-RAVEN-CHRONICLE-VERSION.json","utf8"));\nconst master=JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json","utf8"));\n\nassert.match(html,/CHRONICLE LIVE · DESKTOP BRIDGE v1\\.7/);\nassert.match(html,/RAH Raven Chronicle v1\\.7 · lokal-first · menneskestyrt samtykke/);\nassert.match(html,/const BASE='http:\\/\\/127\\.0\\.0\\.1:18765'/);\nassert.match(html,/refresh\\(\\);setInterval\\(refresh,5000\\)/);\nassert.match(html,/post\\('\\/chronicle\\/session\\/start'/);\nassert.doesNotMatch(html,/setInterval\\([^\\n]*session\\/start|refresh\\([^)]*session\\/start/);\n\nassert.equal(component.product,"RAH Raven Chronicle");\nassert.equal(component.version,"1.7.1");\nassert.equal(component.previous_stable_version,"1.7.0");\nassert.equal(component.stage,"stable-bugfix-candidate");\nassert.equal(component.runtime_feature_change,false);\nassert.equal(component.features.visible_session_required_for_foreground_read,true);\nassert.equal(component.features.paused_blocks_foreground_read,true);\nassert.equal(component.features.status_polling_reads_foreground_when_stopped,false);\nassert.equal(component.features.status_polling_reads_foreground_when_paused,false);\nassert.equal(component.features.active_window_endpoint_requires_active_unpaused_session,true);\nassert.equal(component.features.browser_bridge_loopback_only,true);\nassert.equal(component.features.foreign_browser_origin_guard,true);\nassert.equal(component.features.chronicle_routes_local_browser_origin_only,true);\nassert.equal(component.features.cross_origin_mutation_blocked,true);\nassert.equal(component.features.cors_wildcard,false);\nassert.equal(component.features.keylogging,false);\nassert.equal(component.features.clipboard_capture,false);\nassert.equal(component.features.audio_capture,false);\nassert.equal(component.features.camera_capture,false);\nassert.equal(component.features.automatic_sending,false);\nassert.equal(component.features.capability_set_changed,false);\nassert.equal(component.next_milestone,"stable-gate");\nassert.equal(component.development_reopened,true);\nassert.equal(component.development_paused,false);\nassert.equal(component.change_policy,"bugfix-only");\nassert.equal(component.stable_release_gate?.status,"candidate");\nassert.equal(component.stable_release_gate?.gate_version,"1.1.0");\nassert.equal(component.stable_release_gate?.runtime_files_frozen,false);\nassert.equal(component.stable_release_gate?.stable_raven_runtime_frozen,true);\n\nassert.match(server,/from server_v16 import HOST, LOCAL_BROWSER_ORIGINS, PORT, app/);\nassert.match(server,/CHRONICLE_PROTECTED_PREFIX = "\\/chronicle"/);\nassert.match(server,/@app\\.before_request[\\s\\S]*protect_chronicle_local_apis/);\nassert.match(server,/origin and origin not in LOCAL_BROWSER_ORIGINS/);\n\nconst stable={raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};\nassert.deepEqual(master.release_gate.stable_components,stable);\nassert.ok(master.files.includes("RAH-RAVEN-CHRONICLE-VERSION.json"));\nassert.equal(master.privacy.raven_chronicle_version_synced,true);\nassert.equal(master.privacy.raven_chronicle_observation_requires_active_session,true);\nassert.equal(master.privacy.raven_chronicle_paused_blocks_foreground_read,true);\nassert.equal(master.privacy.raven_chronicle_foreground_read_when_stopped,false);\nassert.equal(master.privacy.raven_chronicle_foreground_read_when_paused,false);\nassert.equal(master.privacy.raven_chronicle_keylogging,false);\nassert.equal(master.privacy.raven_chronicle_clipboard_capture,false);\nassert.equal(master.privacy.raven_chronicle_audio_capture,false);\nassert.equal(master.privacy.raven_chronicle_camera_capture,false);\nassert.equal(master.privacy.raven_chronicle_automatic_sending,false);\nassert.equal(master.privacy.raven_chronicle_foreign_browser_origin_guard,true);\nassert.equal(master.privacy.raven_chronicle_routes_local_browser_origin_only,true);\nassert.equal(master.privacy.raven_chronicle_cross_origin_mutation_blocked,true);\nassert.equal(master.privacy.raven_chronicle_cors_wildcard,false);\nassert.equal(master.privacy.raven_chronicle_bugfix_candidate,true);\nassert.equal(master.privacy.raven_chronicle_candidate_over_previous_stable,true);\nassert.equal(master.privacy.raven_chronicle_stable,true);\nassert.equal(master.privacy.raven_fristvakt_stable,true);\nassert.equal(master.privacy.case_center_stable,true);\nassert.equal(master.privacy.command_center_stable,true);\nconsole.log("Raven Chronicle v1.7.1 local-origin bugfix candidate passed over preserved v1.7.0 Stable contract.");\n'''
    (ROOT / "tests/raven-chronicle-v17.test.mjs").write_text(semantic, encoding="utf-8")

    changed = set(subprocess.check_output(["git", "diff", "--name-only"], cwd=ROOT, text=True).splitlines())
    if changed != ALLOWED:
        raise RuntimeError(f"Unexpected candidate diff: {sorted(changed)}")

    run("python", "-m", "py_compile", "server_v17.py", "test_chronicle_v17.py", cwd=ROOT / "desktop-bridge")
    run("python", "test_chronicle_v17.py", cwd=ROOT / "desktop-bridge")
    run("python", "test_chronicle_ai.py", cwd=ROOT / "desktop-bridge")
    run("python", "test_raven_bridge_security.py", cwd=ROOT / "desktop-bridge")
    run("node", "tests/raven-chronicle-v17.test.mjs")
    run("node", "tests/raven-release-gate.test.mjs")
    run("node", "tests/raven-fristvakt-v0.2.test.mjs")
    run("node", "tests/raven-case-center-v16.test.mjs")
    run("node", "tests/rah-command-center-v05.test.mjs")

    for cache in ROOT.rglob("__pycache__"):
        shutil.rmtree(cache, ignore_errors=True)

    after = {name: sha(ROOT / name) for name in FROZEN}
    moved = [name for name in FROZEN if before[name] != after[name]]
    if moved:
        raise RuntimeError(f"Frozen files changed: {moved}")
    if json.loads(master_path.read_text(encoding="utf-8"))["release_gate"]["stable_components"] != EXPECTED_CORE:
        raise RuntimeError("Nine-core stable set changed")

    print("Chronicle v1.7.1 local-origin bugfix candidate: all checks passed")


if __name__ == "__main__":
    main()

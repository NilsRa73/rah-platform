from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALLOWED = {
    "RAH-RAVEN-CHRONICLE-VERSION.json",
    "RAH-RAVEN-VERSION.json",
    "tests/raven-chronicle-v17.test.mjs",
}
FROZEN = [
    "desktop-bridge/server_v17.py",
    "desktop-bridge/test_chronicle_v17.py",
    "desktop-bridge/chronicle_insights.py",
    "desktop-bridge/chronicle_ai.py",
    "desktop-bridge/raven_bridge.py",
    "desktop-bridge/server_v16.py",
    ".github/workflows/validate-chronicle-v17.yml",
    "RAH-RAVEN-CHRONICLE-LIVE.html",
    "RAH-RAVEN-INSIGHTS.html",
    "RAH-RAVEN-INSIGHTS-VERSION.json",
    "tests/raven-insights-v0.1.test.mjs",
    "RAH-RAVEN-DAILY-BRIEF.html",
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
    "raven_vision":"0.6","raven_council":"0.3","agent_runner":"0.3",
    "memory_sync":"0.2","mission_control":"2.9","project_focus":"2.4",
    "raven_core":"1.12","raven_now":"2.17","raven_studio":"2.8",
}

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(*args: str, cwd: Path = ROOT) -> None:
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    subprocess.run(args, cwd=cwd, env=env, check=True)

def main() -> None:
    frozen_before = {name: digest(ROOT / name) for name in FROZEN}

    manifest_path = ROOT / "RAH-RAVEN-CHRONICLE-VERSION.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("version") != "1.7.1" or manifest.get("stage") != "stable-bugfix-candidate":
        raise RuntimeError("Chronicle v1.7.1 bugfix candidate is required")
    if manifest.get("previous_stable_version") != "1.7.0":
        raise RuntimeError("Previous Stable identity changed")
    features = manifest.get("features", {})
    for key in ("foreign_browser_origin_guard","chronicle_routes_local_browser_origin_only","cross_origin_mutation_blocked"):
        if features.get(key) is not True:
            raise RuntimeError(f"Missing candidate security boundary: {key}")
    if features.get("cors_wildcard") is not False:
        raise RuntimeError("Wildcard CORS boundary regressed")

    master_path = ROOT / "RAH-RAVEN-VERSION.json"
    master = json.loads(master_path.read_text(encoding="utf-8"))
    if master.get("release_gate", {}).get("stable_components") != EXPECTED_CORE:
        raise RuntimeError("Nine-core stable set changed")
    privacy = master.setdefault("privacy", {})
    if privacy.get("raven_chronicle_stable") is not True:
        raise RuntimeError("Previous Chronicle Stable marker must remain true during candidate")
    if privacy.get("raven_chronicle_bugfix_candidate") is not True:
        raise RuntimeError("Chronicle bugfix candidate marker missing")
    if privacy.get("raven_fristvakt_stable") is not True or privacy.get("case_center_stable") is not True:
        raise RuntimeError("Frozen platform stable markers changed")

    manifest["stage"] = "stable"
    manifest["next_milestone"] = None
    manifest["stable_since"] = "2026-08-15"
    manifest["development_paused"] = True
    manifest.pop("development_reopened", None)
    manifest["change_policy"] = "bugfix-only-until-explicit-reopen"
    manifest["stable_release_gate"] = {
        "status": "passed",
        "gate_version": "1.1.0",
        "runtime_files_frozen": True,
        "stable_raven_runtime_frozen": True,
        "change_policy": "bugfix-only-until-explicit-reopen",
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    privacy["raven_chronicle_stable"] = True
    privacy["raven_chronicle_bugfix_candidate"] = False
    privacy["raven_chronicle_candidate_over_previous_stable"] = False
    privacy["raven_chronicle_foreign_browser_origin_guard"] = True
    privacy["raven_chronicle_routes_local_browser_origin_only"] = True
    privacy["raven_chronicle_cross_origin_mutation_blocked"] = True
    privacy["raven_chronicle_cors_wildcard"] = False
    master_path.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    semantic_path = ROOT / "tests/raven-chronicle-v17.test.mjs"
    semantic = semantic_path.read_text(encoding="utf-8")
    replacements = {
        'assert.equal(component.stage,"stable-bugfix-candidate");': 'assert.equal(component.stage,"stable");',
        'assert.equal(component.next_milestone,"stable-gate");': 'assert.equal(component.next_milestone,null);',
        'assert.equal(component.development_reopened,true);\n': '',
        'assert.equal(component.development_paused,false);': 'assert.equal(component.development_paused,true);',
        'assert.equal(component.change_policy,"bugfix-only");': 'assert.equal(component.change_policy,"bugfix-only-until-explicit-reopen");',
        'assert.equal(component.stable_release_gate.status,"candidate");': 'assert.equal(component.stable_release_gate.status,"passed");',
        'assert.equal(component.stable_release_gate.runtime_files_frozen,false);': 'assert.equal(component.stable_release_gate.runtime_files_frozen,true);',
        'assert.equal(master.privacy.raven_chronicle_bugfix_candidate,true);': 'assert.equal(master.privacy.raven_chronicle_bugfix_candidate,false);',
        'assert.equal(master.privacy.raven_chronicle_candidate_over_previous_stable,true);': 'assert.equal(master.privacy.raven_chronicle_candidate_over_previous_stable,false);',
        'console.log("Raven Chronicle v1.7.1 local-origin bugfix candidate passed over preserved v1.7.0 Stable contract.");': 'console.log("Raven Chronicle v1.7.1 Stable local-origin boundary passed with runtime frozen.");',
    }
    for old, new in replacements.items():
        if old not in semantic:
            raise RuntimeError(f"Stable semantic anchor missing: {old}")
        semantic = semantic.replace(old, new, 1)
    semantic_path.write_text(semantic, encoding="utf-8")

    changed = set(subprocess.check_output(["git", "diff", "--name-only"], cwd=ROOT, text=True).splitlines())
    if changed != ALLOWED:
        raise RuntimeError(f"Unexpected Stable Gate diff: {sorted(changed)}")

    run("python", "test_chronicle_v17.py", cwd=ROOT / "desktop-bridge")
    run("python", "test_chronicle_ai.py", cwd=ROOT / "desktop-bridge")
    run("python", "test_raven_bridge_security.py", cwd=ROOT / "desktop-bridge")
    run("node", "tests/raven-chronicle-v17.test.mjs")
    run("node", "tests/raven-insights-v0.1.test.mjs")
    run("node", "tests/raven-release-gate.test.mjs")
    run("node", "tests/raven-fristvakt-v0.2.test.mjs")
    run("node", "tests/raven-case-center-v16.test.mjs")
    run("node", "tests/rah-command-center-v05.test.mjs")

    for cache in ROOT.rglob("__pycache__"):
        shutil.rmtree(cache, ignore_errors=True)

    frozen_after = {name: digest(ROOT / name) for name in FROZEN}
    moved = [name for name in FROZEN if frozen_before[name] != frozen_after[name]]
    if moved:
        raise RuntimeError(f"Frozen runtime/test files changed: {moved}")
    if json.loads(master_path.read_text(encoding="utf-8"))["release_gate"]["stable_components"] != EXPECTED_CORE:
        raise RuntimeError("Nine-core stable set changed after promotion")
    print("Chronicle v1.7.1 Stable Gate passed")

if __name__ == "__main__":
    main()

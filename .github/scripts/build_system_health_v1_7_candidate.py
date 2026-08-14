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


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected 1 anchor, got {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


before = {path: digest(path) for path in FROZEN}

# 1) Make the System Health runtime manual-only and use the canonical Raven Bridge.
js = p("system-health-v1.7.js")
replace_once(js, '  const BRIDGE = "http://127.0.0.1:8765";', '  const BRIDGE = "http://127.0.0.1:18765";', "canonical Bridge")
replace_once(js, "kontroller port 8765.", "kontroller port 18765.", "canonical Bridge repair text")
replace_once(
    js,
    "    saveHistory(summary);",
    "    saveHistory({ time: summary.time, ready: summary.ready, failed: summary.failed, total: summary.total });",
    "summary-only history",
)
replace_once(js, "    setTimeout(runFullCheck, 1200);\n", "", "remove automatic full check")

# 2) Restore the panel load hook now that loading it no longer performs diagnostics.
index = p("index.html")
index_text = index.read_text(encoding="utf-8")
hook = '  <script src="system-health-v1.7.js?v=1.7" defer></script>'
if hook in index_text:
    raise RuntimeError("System Health hook unexpectedly already present on candidate base")
anchor = '  <script src="voice-control-v1.6.js?v=1.6" defer></script>\n</body>'
if index_text.count(anchor) != 1:
    raise RuntimeError("System Health index anchor missing or ambiguous")
index.write_text(index_text.replace(anchor, f'  <script src="voice-control-v1.6.js?v=1.6" defer></script>\n{hook}\n</body>', 1), encoding="utf-8")

# 3) Sync user-facing documentation with actual behavior and canonical Bridge port.
doc = p("SYSTEM_HEALTH_V1_7.md")
doc_text = doc.read_text(encoding="utf-8")
doc_text = doc_text.replace("The module also runs one automatic check shortly after the page loads.", "The panel loads with the Command Center, but diagnostics run only after you press **Kjør full systemkontroll**. No automatic system check runs on page load.")
doc_text = doc_text.replace("http://127.0.0.1:8765/health", "http://127.0.0.1:18765/health")
doc_text = doc_text.replace("- Check history is stored in browser `localStorage` and can be cleared from the panel.", "- Check history is stored locally in browser `localStorage` as summary counts and timestamps only; service details are not persisted.\n- History can be cleared explicitly from the panel.")
doc.write_text(doc_text, encoding="utf-8")

# 4) Add a component candidate contract.
component = {
    "product": "RAH Raven System Health",
    "version": "1.7.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "index.html",
    "module": "system-health-v1.7.js",
    "local_only": True,
    "runtime_feature_change": False,
    "features": {
        "command_center_panel_loaded": True,
        "explicit_check_only": True,
        "automatic_check": False,
        "browser_bridge_loopback_only": True,
        "bridge_base": "http://127.0.0.1:18765",
        "external_bridge_addresses_allowed": False,
        "lm_studio_loopback_only": True,
        "lm_studio_models_url": "http://127.0.0.1:1234/v1/models",
        "history_local_only": True,
        "history_summary_only": True,
        "history_service_details_stored": False,
        "screenshot_capture": False,
        "password_storage": False,
        "secret_key_storage": False,
        "automatic_sending": False,
        "capability_set_changed": False,
    },
    "next_milestone": "stable-gate",
}
p("RAH-RAVEN-SYSTEM-HEALTH-VERSION.json").write_text(json.dumps(component, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# 5) Register the non-core component without changing the nine-core stable set.
master_path = p("RAH-RAVEN-VERSION.json")
master = json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
assert master["privacy"].get("raven_chronicle_stable") is True
for file_name in ["system-health-v1.7.js", "SYSTEM_HEALTH_V1_7.md", "RAH-RAVEN-SYSTEM-HEALTH-VERSION.json"]:
    if file_name not in master["files"]:
        master["files"].append(file_name)
master["privacy"].update({
    "system_health_explicit_check_only": True,
    "system_health_automatic_check": False,
    "system_health_local_bridge_only": True,
    "system_health_external_bridge_addresses_allowed": False,
    "system_health_canonical_bridge_port_synced": True,
    "system_health_history_summary_only": True,
    "system_health_history_service_details_stored": False,
    "system_health_stable": False,
})
master_path.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# 6) Replace the old integration-only test with a safety/functional candidate contract.
test = '''import assert from "node:assert/strict";\nimport fs from "node:fs";\n\nconst moduleText = fs.readFileSync("system-health-v1.7.js", "utf8");\nconst indexText = fs.readFileSync("index.html", "utf8");\nconst component = JSON.parse(fs.readFileSync("RAH-RAVEN-SYSTEM-HEALTH-VERSION.json", "utf8"));\nconst master = JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json", "utf8"));\n\nconst hookMatches = indexText.match(/system-health-v1\\.7\\.js\\?v=1\\.7/g) || [];\nassert.equal(hookMatches.length, 1);\nassert.match(moduleText, /const VERSION = "1\\.7\\.0"/);\nassert.match(moduleText, /const BRIDGE = "http:\\/\\/127\\.0\\.0\\.1:18765"/);\nassert.doesNotMatch(moduleText, /8765/);\nassert.match(moduleText, /const LM_STUDIO = "http:\\/\\/127\\.0\\.0\\.1:1234"/);\nassert.match(moduleText, /rahRunHealthCheck/);\nassert.match(moduleText, /window\\.runRavenSystemHealth = runFullCheck/);\nassert.doesNotMatch(moduleText, /setTimeout\\(runFullCheck|setInterval\\(runFullCheck/);\nassert.match(moduleText, /saveHistory\\(\\{ time: summary\\.time, ready: summary\\.ready, failed: summary\\.failed, total: summary\\.total \\}\\)/);\nassert.doesNotMatch(moduleText, /\\n\\s*saveHistory\\(summary\\);/);\nassert.doesNotMatch(moduleText, /service_role/i);\n\nassert.equal(component.product, "RAH Raven System Health");\nassert.equal(component.version, "1.7.0");\nassert.equal(component.stage, "candidate");\nassert.equal(component.runtime_feature_change, false);\nassert.equal(component.features.command_center_panel_loaded, true);\nassert.equal(component.features.explicit_check_only, true);\nassert.equal(component.features.automatic_check, false);\nassert.equal(component.features.browser_bridge_loopback_only, true);\nassert.equal(component.features.bridge_base, "http://127.0.0.1:18765");\nassert.equal(component.features.external_bridge_addresses_allowed, false);\nassert.equal(component.features.lm_studio_loopback_only, true);\nassert.equal(component.features.history_summary_only, true);\nassert.equal(component.features.history_service_details_stored, false);\nassert.equal(component.features.screenshot_capture, false);\nassert.equal(component.features.password_storage, false);\nassert.equal(component.features.secret_key_storage, false);\nassert.equal(component.features.automatic_sending, false);\nassert.equal(component.features.capability_set_changed, false);\nassert.equal(component.next_milestone, "stable-gate");\n\nconst stable = {raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};\nassert.deepEqual(master.release_gate.stable_components, stable);\nassert.equal(master.privacy.raven_chronicle_stable, true);\nassert.equal(master.privacy.system_health_explicit_check_only, true);\nassert.equal(master.privacy.system_health_automatic_check, false);\nassert.equal(master.privacy.system_health_local_bridge_only, true);\nassert.equal(master.privacy.system_health_external_bridge_addresses_allowed, false);\nassert.equal(master.privacy.system_health_canonical_bridge_port_synced, true);\nassert.equal(master.privacy.system_health_history_summary_only, true);\nassert.equal(master.privacy.system_health_history_service_details_stored, false);\nassert.equal(master.privacy.system_health_stable, false);\nconsole.log("Raven System Health v1.7 explicit-check candidate contract passed.");\n'''
p("tests/system-health.test.mjs").write_text(test, encoding="utf-8")

# Candidate work must not touch any stable runtime or the stable Chronicle runtime.
after = {path: digest(path) for path in FROZEN}
changed_frozen = [path for path in FROZEN if before[path] != after[path]]
if changed_frozen:
    raise RuntimeError(f"Frozen runtime changed: {changed_frozen}")

master = json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
print("Built Raven System Health v1.7 explicit-check candidate with nine-core + Chronicle freeze preserved.")

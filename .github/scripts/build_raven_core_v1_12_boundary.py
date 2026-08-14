from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def read_json(path: str) -> dict:
    return json.loads(read(path))


def write_json(path: str, data: dict) -> None:
    write(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"{label} anchor missing")
    return text.replace(old, new, 1)


# Runtime bugfix only: Core status requests may use only an explicit local loopback Bridge.
html_path = "RAH-RAVEN-CORE-DEMO.html"
html = read(html_path)
assert "RAH Raven Core Workflow v1.12" in html

html = replace_once(html, 'raven-vision-core.js?v=0.1', 'raven-vision-core.js?v=0.6', 'Vision dependency cache key')
html = replace_once(html, 'raven-council.js?v=0.1', 'raven-council.js?v=0.3', 'Council dependency cache key')

bridge_anchor = '  const BRIDGE_BASE = () => String(localStorage.getItem("rah.bridge.base") || "http://127.0.0.1:18765").replace(/\\/+$/, "");\n'
bridge_boundary = '''  function normalizeBridgeBase(raw) {\n    let url;\n    try { url = new URL(String(raw || "http://127.0.0.1:18765")); }\n    catch { throw new Error("Raven Core Bridge må bruke lokal loopback-adresse."); }\n    const host = String(url.hostname || "").toLowerCase();\n    if (!["127.0.0.1", "localhost", "::1", "[::1]"].includes(host)) throw new Error("Raven Core Bridge må bruke lokal loopback-adresse.");\n    if (!["http:", "https:"].includes(url.protocol)) throw new Error("Raven Core Bridge må bruke HTTP/HTTPS på lokal loopback.");\n    if (url.username || url.password) throw new Error("Raven Core Bridge tillater ikke credentials i adressen.");\n    if (url.search || url.hash) throw new Error("Raven Core Bridge tillater ikke query eller hash i baseadressen.");\n    if (url.pathname && url.pathname !== "/") throw new Error("Raven Core Bridge må bruke rotstien.");\n    return url.origin;\n  }\n  const BRIDGE_BASE = () => normalizeBridgeBase(localStorage.getItem("rah.bridge.base") || "http://127.0.0.1:18765");\n'''
html = replace_once(html, bridge_anchor, bridge_boundary, 'Core Bridge boundary')
html = replace_once(html, 'RAH Raven 2.0.25 · Core v1.12 support snapshot', 'RAH Raven 2.0.32 · Core v1.12 support snapshot', 'support snapshot Raven version')
html = replace_once(html, '`RAH Raven Core Workflow v1 — ${new Date().toLocaleString("no-NO")}`', '`RAH Raven Core Workflow v1.12 — ${new Date().toLocaleString("no-NO")}`', 'Core report version')
write(html_path, html)

# Candidate component contract. Version stays 1.12 because this is a freeze-compatible bugfix.
core_manifest = {
    "product": "RAH Raven Core Workflow",
    "version": "1.12.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "RAH-RAVEN-CORE-DEMO.html",
    "local_only": True,
    "runtime_feature_change": False,
    "dependency_versions": {
        "raven_vision_core": "0.6.0",
        "raven_council": "0.3.0",
        "raven_chronicle_sync": "0.1.0",
    },
    "features": {
        "local_bridge_only": True,
        "loopback_hosts": ["127.0.0.1", "localhost", "::1"],
        "external_bridge_addresses_allowed": False,
        "bridge_protocols": ["http", "https"],
        "bridge_credentials_allowed": False,
        "bridge_query_allowed": False,
        "bridge_hash_allowed": False,
        "bridge_non_root_path_allowed": False,
        "dependency_cache_keys_synced": True,
        "support_snapshot_raven_version_synced": True,
        "core_report_version_synced": True,
        "context_snapshot_read_only": True,
        "continue_navigation_only": True,
        "project_brain_write_requires_explicit_user_action": True,
        "mission_handoff_requires_explicit_user_action": True,
        "active_mission_replacement_requires_confirmation": True,
        "agent_execution": False,
        "automatic_memory_sync": False,
        "shared_checkpoint_policy_runtime_changed": False,
        "capability_set_changed": False,
    },
    "next_milestone": "stable-gate",
}
write_json("RAH-RAVEN-CORE-VERSION.json", core_manifest)

# Master Raven remains 2.0.32 temporary stable; the six existing stable components remain untouched.
manifest = read_json("RAH-RAVEN-VERSION.json")
assert manifest["version"] == "2.0.32"
assert manifest["release_gate"]["component_versions"]["raven_core"] == "1.12"
assert manifest["release_gate"]["stable_components"] == {
    "raven_vision": "0.6",
    "raven_council": "0.3",
    "agent_runner": "0.3",
    "memory_sync": "0.2",
    "mission_control": "2.9",
    "project_focus": "2.4",
}
version_file = "RAH-RAVEN-CORE-VERSION.json"
if version_file not in manifest["files"]:
    insert_at = manifest["files"].index("RAH-RAVEN-CORE-DEMO.html") + 1
    manifest["files"].insert(insert_at, version_file)
privacy = manifest["privacy"]
privacy["raven_core_local_bridge_only"] = True
privacy["raven_core_external_bridge_addresses_allowed"] = False
privacy["raven_core_dependency_versions_synced"] = True
privacy["raven_core_support_snapshot_version_synced"] = True
privacy["raven_core_report_version_synced"] = True
privacy["raven_core_stable"] = False
manifest["summary"] = "RAH Raven 2.0.32 remains the temporary stable freeze. Six core components are stable; Raven Core v1.12 is a safety candidate with loopback-only Bridge status requests and synced stable dependency cache keys."
write_json("RAH-RAVEN-VERSION.json", manifest)

# Core regression test: dependency versions, local boundary and identity sync.
core_test_path = "tests/raven-core-demo.test.mjs"
core_test = read(core_test_path)
core_test = replace_once(core_test, r'assert.match(html, /raven-vision-core\.js\?v=0\.1/);', r'assert.match(html, /raven-vision-core\.js\?v=0\.6/);', 'Core Vision dependency test')
core_test = replace_once(core_test, r'assert.match(html, /raven-council\.js\?v=0\.1/);', r'assert.match(html, /raven-council\.js\?v=0\.3/);', 'Core Council dependency test')
chronicle_anchor = r'assert.match(html, /raven-chronicle-sync\.js\?v=0\.1/);'
core_insert = r'''assert.match(html, /function normalizeBridgeBase\(raw\)/);
assert.match(html, /const BRIDGE_BASE = \(\) => normalizeBridgeBase/);
assert.match(html, /Raven Core Bridge må bruke lokal loopback-adresse/);
assert.match(html, /RAH Raven Core Workflow v1\.12 —/);
'''
core_test = replace_once(core_test, chronicle_anchor, chronicle_anchor + "\n" + core_insert, 'Core boundary static tests')
write(core_test_path, core_test)

# Handoff support snapshot must report the current frozen Raven version.
handoff_test_path = "tests/raven-core-chatgpt-handoff-center.test.mjs"
handoff_test = read(handoff_test_path)
handoff_test = replace_once(handoff_test, r'RAH Raven 2\.0\.25 · Core v1\.12 support snapshot', r'RAH Raven 2\.0\.32 · Core v1\.12 support snapshot', 'Core handoff Raven version test')
write(handoff_test_path, handoff_test)

# Dynamic local-boundary test exercises allowed and rejected Bridge bases before any network call.
boundary_test = '''import assert from "node:assert/strict";
import fs from "node:fs";

const html=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");
const manifest=JSON.parse(fs.readFileSync("RAH-RAVEN-CORE-VERSION.json","utf8"));
const start=html.indexOf("function normalizeBridgeBase(raw) {");
const end=html.indexOf("\n  const BRIDGE_BASE",start);
assert.ok(start>=0&&end>start,"normalizeBridgeBase body missing");
const fn=html.slice(start,end);
const body=fn.slice(fn.indexOf("{")+1,fn.lastIndexOf("}"));
const normalize=new Function("raw",body);

for(const value of [
  "http://127.0.0.1:18765",
  "https://localhost:18765/",
  "http://[::1]:18765/"
]) assert.ok(normalize(value),`allowed loopback rejected: ${value}`);

for(const value of [
  "https://example.com",
  "http://127.0.0.2:18765",
  "ftp://localhost:18765",
  "http://user:pass@localhost:18765",
  "http://localhost:18765/path",
  "http://localhost:18765/?q=1",
  "http://localhost:18765/#fragment"
]) assert.throws(()=>normalize(value),undefined,`unsafe Bridge base accepted: ${value}`);

assert.equal(manifest.product,"RAH Raven Core Workflow");
assert.equal(manifest.version,"1.12.0");
assert.equal(manifest.stage,"candidate");
assert.equal(manifest.runtime_feature_change,false);
assert.equal(manifest.features.local_bridge_only,true);
assert.equal(manifest.features.external_bridge_addresses_allowed,false);
assert.equal(manifest.features.bridge_credentials_allowed,false);
assert.equal(manifest.features.bridge_query_allowed,false);
assert.equal(manifest.features.bridge_hash_allowed,false);
assert.equal(manifest.features.bridge_non_root_path_allowed,false);
assert.equal(manifest.features.dependency_cache_keys_synced,true);
assert.equal(manifest.features.support_snapshot_raven_version_synced,true);
assert.equal(manifest.features.core_report_version_synced,true);
assert.equal(manifest.features.agent_execution,false);
assert.equal(manifest.features.automatic_memory_sync,false);
assert.equal(manifest.features.capability_set_changed,false);
assert.equal(manifest.next_milestone,"stable-gate");

assert.ok(html.includes('fetchJson(`${BRIDGE_BASE()}/health`)'));
assert.ok(html.includes('fetchJson(`${BRIDGE_BASE()}/lm/models`)'));
assert.equal(/api\.openai\.com|chatgpt\.com\/backend/i.test(html),false);

console.log("Raven Core v1.12 local Bridge boundary candidate passed.");
'''
write("tests/raven-core-local-boundary.test.mjs", boundary_test)

# Aggregate release gate recognizes Core as candidate without promoting it to stable.
release_path = "tests/raven-release-gate.test.mjs"
release = read(release_path)
privacy_anchor = 'assert.equal(privacy.project_focus_stable,true,"Project Focus v2.4 stable marker must stay true");'
privacy_insert = '''assert.equal(privacy.raven_core_local_bridge_only,true,"Raven Core Bridge status requests must be loopback-only");
assert.equal(privacy.raven_core_external_bridge_addresses_allowed,false,"Raven Core external Bridge addresses must stay blocked");
assert.equal(privacy.raven_core_dependency_versions_synced,true,"Raven Core dependency cache keys must match stable helper versions");
assert.equal(privacy.raven_core_support_snapshot_version_synced,true,"Raven Core support snapshot must report Raven 2.0.32");
assert.equal(privacy.raven_core_report_version_synced,true,"Raven Core report must report v1.12");
assert.equal(privacy.raven_core_stable,false,"Raven Core v1.12 remains candidate until stable gate passes");'''
release = replace_once(release, privacy_anchor, privacy_anchor + "\n" + privacy_insert, 'release Core candidate privacy')
manifest_anchor = 'assert.ok(manifest.files.includes("RAH-RAVEN-VISION-VERSION.json"),"Vision component manifest must ship in Raven package");'
core_manifest_checks = '''assert.ok(manifest.files.includes("RAH-RAVEN-CORE-VERSION.json"),"Raven Core component manifest must ship in Raven package");
const coreManifest=JSON.parse(read("RAH-RAVEN-CORE-VERSION.json"));
assert.equal(coreManifest.version,"1.12.0");
assert.equal(coreManifest.stage,"candidate");
assert.equal(coreManifest.runtime_feature_change,false);
assert.equal(coreManifest.dependency_versions.raven_vision_core,"0.6.0");
assert.equal(coreManifest.dependency_versions.raven_council,"0.3.0");
assert.equal(coreManifest.dependency_versions.raven_chronicle_sync,"0.1.0");
assert.equal(coreManifest.features.local_bridge_only,true);
assert.equal(coreManifest.features.external_bridge_addresses_allowed,false);
assert.equal(coreManifest.features.bridge_credentials_allowed,false);
assert.equal(coreManifest.features.bridge_query_allowed,false);
assert.equal(coreManifest.features.bridge_hash_allowed,false);
assert.equal(coreManifest.features.bridge_non_root_path_allowed,false);
assert.equal(coreManifest.features.dependency_cache_keys_synced,true);
assert.equal(coreManifest.features.context_snapshot_read_only,true);
assert.equal(coreManifest.features.continue_navigation_only,true);
assert.equal(coreManifest.features.agent_execution,false);
assert.equal(coreManifest.features.automatic_memory_sync,false);
assert.equal(coreManifest.features.shared_checkpoint_policy_runtime_changed,false);
assert.equal(coreManifest.features.capability_set_changed,false);
assert.equal(coreManifest.next_milestone,"stable-gate");

'''
release = replace_once(release, manifest_anchor, core_manifest_checks + manifest_anchor, 'release Core candidate manifest')
release = release.replace(
    'RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 + Project Focus v2.4 stable boundaries OK.',
    'RAH Raven 2.0.32 Temporary Stable Gate: six stable core components; Raven Core v1.12 candidate local Bridge boundary OK.'
)
write(release_path, release)

# Dedicated Core workflow tracks the candidate manifest and boundary test.
workflow_path = ".github/workflows/validate-raven-core-demo.yml"
workflow = read(workflow_path)
workflow = workflow.replace('      - RAH-RAVEN-CORE-DEMO.html\n', '      - RAH-RAVEN-CORE-DEMO.html\n      - RAH-RAVEN-CORE-VERSION.json\n')
workflow = workflow.replace('      - tests/raven-core-demo.test.mjs\n', '      - tests/raven-core-demo.test.mjs\n      - tests/raven-core-local-boundary.test.mjs\n      - tests/raven-release-gate.test.mjs\n')
step_anchor = '      - name: Run Raven Core v1.12 validation\n        run: node tests/raven-core-demo.test.mjs\n'
step_insert = '''      - name: Run Raven Core v1.12 local Bridge boundary validation
        run: node tests/raven-core-local-boundary.test.mjs
      - name: Run aggregate Raven 2.0.32 identity validation
        run: node tests/raven-release-gate.test.mjs
'''
workflow = replace_once(workflow, step_anchor, step_anchor + step_insert, 'Core workflow boundary steps')
workflow = workflow.replace('Run Raven Vision v0.5 handoff validation', 'Run Raven Vision v0.6 handoff validation')
write(workflow_path, workflow)

print("Raven Core v1.12 candidate built: local Bridge boundary + dependency/version sync; six stable components untouched.")

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

# Runtime bugfix only: Raven Now Bridge requests must remain on explicit local loopback.
html_path = "RAH-RAVEN-NOW-V2.html"
html = read(html_path)
assert "RAH Raven Now v2.17" in html
bridge_anchor = "  const bridgeBase=()=>String(localStorage.getItem('rah.bridge.base')||'http://127.0.0.1:18765').replace(/\\/+$/,'');\n"
bridge_boundary = '''  function normalizeBridgeBase(raw){\n    let url;\n    try{url=new URL(String(raw||'http://127.0.0.1:18765'))}\n    catch{throw new Error('Raven Now Bridge må bruke lokal loopback-adresse.')}\n    const host=String(url.hostname||'').toLowerCase();\n    if(!['127.0.0.1','localhost','::1','[::1]'].includes(host))throw new Error('Raven Now Bridge må bruke lokal loopback-adresse.');\n    if(!['http:','https:'].includes(url.protocol))throw new Error('Raven Now Bridge må bruke HTTP/HTTPS på lokal loopback.');\n    if(url.username||url.password)throw new Error('Raven Now Bridge tillater ikke credentials i adressen.');\n    if(url.search||url.hash)throw new Error('Raven Now Bridge tillater ikke query eller hash i baseadressen.');\n    if(url.pathname&&url.pathname!=='/')throw new Error('Raven Now Bridge må bruke rotstien.');\n    return url.origin;\n  }\n  const bridgeBase=()=>normalizeBridgeBase(localStorage.getItem('rah.bridge.base')||'http://127.0.0.1:18765');\n'''
html = replace_once(html, bridge_anchor, bridge_boundary, "Raven Now Bridge boundary")
write(html_path, html)

now_manifest = {
    "product": "RAH Raven Now",
    "version": "2.17.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "RAH-RAVEN-NOW-V2.html",
    "local_only": True,
    "runtime_feature_change": False,
    "features": {
        "read_only_dashboard": True,
        "local_bridge_only": True,
        "loopback_hosts": ["127.0.0.1", "localhost", "::1"],
        "external_bridge_addresses_allowed": False,
        "bridge_protocols": ["http", "https"],
        "bridge_credentials_allowed": False,
        "bridge_query_allowed": False,
        "bridge_hash_allowed": False,
        "bridge_non_root_path_allowed": False,
        "lm_studio_status_loopback_only": True,
        "context_snapshot_read_only": True,
        "continue_navigation_only": True,
        "state_writes": False,
        "project_switch": False,
        "mission_mutation": False,
        "mission_step_completion": False,
        "agent_execution": False,
        "handoff_history_explicit_save_delete_only": True,
        "handoff_history_metadata_only": True,
        "shared_checkpoint_policy_runtime_changed": False,
        "capability_set_changed": False
    },
    "next_milestone": "stable-gate"
}
write_json("RAH-RAVEN-NOW-VERSION.json", now_manifest)

manifest = read_json("RAH-RAVEN-VERSION.json")
assert manifest["version"] == "2.0.32"
assert manifest["release_gate"]["component_versions"]["raven_now"] == "2.17"
assert manifest["release_gate"]["stable_components"] == {
    "raven_vision":"0.6","raven_council":"0.3","agent_runner":"0.3","memory_sync":"0.2",
    "mission_control":"2.9","project_focus":"2.4","raven_core":"1.12"
}
if "RAH-RAVEN-NOW-VERSION.json" not in manifest["files"]:
    idx = manifest["files"].index("RAH-RAVEN-NOW-V2.html") + 1
    manifest["files"].insert(idx, "RAH-RAVEN-NOW-VERSION.json")
p = manifest["privacy"]
p["raven_now_local_bridge_only"] = True
p["raven_now_external_bridge_addresses_allowed"] = False
p["raven_now_bridge_credentials_allowed"] = False
p["raven_now_bridge_query_allowed"] = False
p["raven_now_bridge_hash_allowed"] = False
p["raven_now_bridge_non_root_path_allowed"] = False
p["raven_now_stable"] = False
manifest["summary"] = "RAH Raven 2.0.32 remains the temporary stable freeze. Seven core components are stable; Raven Now v2.17 is a read-only safety candidate with loopback-only Bridge status requests."
write_json("RAH-RAVEN-VERSION.json", manifest)

now_test_path = "tests/raven-now-v2.test.mjs"
now_test = read(now_test_path)
anchor = "assert.match(html,/v2\\.17 · READ ONLY/);"
insert = '''assert.match(html,/function normalizeBridgeBase\\(raw\\)/);\nassert.match(html,/const bridgeBase=\\(\\)=>normalizeBridgeBase/);\nassert.match(html,/Raven Now Bridge må bruke lokal loopback-adresse/);'''
now_test = replace_once(now_test, anchor, anchor + "\n" + insert, "Raven Now static boundary tests")
write(now_test_path, now_test)

boundary_test = r'''import assert from "node:assert/strict";
import fs from "node:fs";

const html=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");
const manifest=JSON.parse(fs.readFileSync("RAH-RAVEN-NOW-VERSION.json","utf8"));
const start=html.indexOf("function normalizeBridgeBase(raw){");
const end=html.indexOf("  const bridgeBase",start);
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

assert.equal(manifest.product,"RAH Raven Now");
assert.equal(manifest.version,"2.17.0");
assert.equal(manifest.stage,"candidate");
assert.equal(manifest.runtime_feature_change,false);
assert.equal(manifest.features.read_only_dashboard,true);
assert.equal(manifest.features.local_bridge_only,true);
assert.equal(manifest.features.external_bridge_addresses_allowed,false);
assert.equal(manifest.features.bridge_credentials_allowed,false);
assert.equal(manifest.features.bridge_query_allowed,false);
assert.equal(manifest.features.bridge_hash_allowed,false);
assert.equal(manifest.features.bridge_non_root_path_allowed,false);
assert.equal(manifest.features.lm_studio_status_loopback_only,true);
assert.equal(manifest.features.context_snapshot_read_only,true);
assert.equal(manifest.features.continue_navigation_only,true);
assert.equal(manifest.features.state_writes,false);
assert.equal(manifest.features.project_switch,false);
assert.equal(manifest.features.mission_mutation,false);
assert.equal(manifest.features.mission_step_completion,false);
assert.equal(manifest.features.agent_execution,false);
assert.equal(manifest.features.handoff_history_explicit_save_delete_only,true);
assert.equal(manifest.features.handoff_history_metadata_only,true);
assert.equal(manifest.features.shared_checkpoint_policy_runtime_changed,false);
assert.equal(manifest.features.capability_set_changed,false);
assert.equal(manifest.next_milestone,"stable-gate");

assert.ok(html.includes('fetch(`${bridgeBase()}/chronicle/brief?hours=24`'));
assert.ok(html.includes('fetch(`${bridgeBase()}/health`'));
assert.ok(html.includes("fetch('http://127.0.0.1:1234/v1/models'"));
assert.equal(/api\.openai\.com|chatgpt\.com\/backend/i.test(html),false);
console.log("Raven Now v2.17 local Bridge boundary candidate passed.");
'''
write("tests/raven-now-local-boundary.test.mjs", boundary_test)

release_path = "tests/raven-release-gate.test.mjs"
release = read(release_path)
privacy_anchor = 'assert.equal(privacy.raven_core_stable,true,"Raven Core v1.12 stable marker must stay true");'
privacy_insert = '''assert.equal(privacy.raven_now_local_bridge_only,true,"Raven Now Bridge requests must be loopback-only");
assert.equal(privacy.raven_now_external_bridge_addresses_allowed,false,"Raven Now external Bridge addresses must stay blocked");
assert.equal(privacy.raven_now_bridge_credentials_allowed,false,"Raven Now Bridge credentials must stay blocked");
assert.equal(privacy.raven_now_bridge_query_allowed,false,"Raven Now Bridge query must stay blocked");
assert.equal(privacy.raven_now_bridge_hash_allowed,false,"Raven Now Bridge hash must stay blocked");
assert.equal(privacy.raven_now_bridge_non_root_path_allowed,false,"Raven Now Bridge non-root paths must stay blocked");
assert.equal(privacy.raven_now_stable,false,"Raven Now v2.17 remains candidate until stable gate passes");'''
release = replace_once(release, privacy_anchor, privacy_anchor + "\n" + privacy_insert, "release Raven Now privacy")
manifest_anchor = 'assert.ok(manifest.files.includes("RAH-RAVEN-CORE-VERSION.json"),"Raven Core component manifest must ship in Raven package");'
now_checks = '''assert.ok(manifest.files.includes("RAH-RAVEN-NOW-VERSION.json"),"Raven Now component manifest must ship in Raven package");
const nowManifest=JSON.parse(read("RAH-RAVEN-NOW-VERSION.json"));
assert.equal(nowManifest.version,"2.17.0");
assert.equal(nowManifest.stage,"candidate");
assert.equal(nowManifest.runtime_feature_change,false);
assert.equal(nowManifest.features.read_only_dashboard,true);
assert.equal(nowManifest.features.local_bridge_only,true);
assert.equal(nowManifest.features.external_bridge_addresses_allowed,false);
assert.equal(nowManifest.features.bridge_credentials_allowed,false);
assert.equal(nowManifest.features.bridge_query_allowed,false);
assert.equal(nowManifest.features.bridge_hash_allowed,false);
assert.equal(nowManifest.features.bridge_non_root_path_allowed,false);
assert.equal(nowManifest.features.context_snapshot_read_only,true);
assert.equal(nowManifest.features.continue_navigation_only,true);
assert.equal(nowManifest.features.state_writes,false);
assert.equal(nowManifest.features.project_switch,false);
assert.equal(nowManifest.features.mission_mutation,false);
assert.equal(nowManifest.features.mission_step_completion,false);
assert.equal(nowManifest.features.agent_execution,false);
assert.equal(nowManifest.features.shared_checkpoint_policy_runtime_changed,false);
assert.equal(nowManifest.features.capability_set_changed,false);
assert.equal(nowManifest.next_milestone,"stable-gate");

'''
release = replace_once(release, manifest_anchor, now_checks + manifest_anchor, "release Raven Now manifest")
release = release.replace(
    "RAH Raven 2.0.32 Temporary Stable Gate: seven stable core components including Raven Core v1.12; local Bridge boundaries OK.",
    "RAH Raven 2.0.32 Temporary Stable Gate: seven stable core components; Raven Now v2.17 candidate local Bridge boundary OK."
)
write(release_path, release)

print("Raven Now v2.17 candidate built: local Bridge boundary; seven stable components untouched.")

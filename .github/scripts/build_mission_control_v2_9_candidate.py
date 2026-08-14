from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read_text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write_text(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def read_json(path: str) -> dict:
    return json.loads(read_text(path))


def write_json(path: str, data: dict) -> None:
    write_text(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


# Mission Control runtime: security boundary only, no new capabilities.
html_path = "RAH-RAVEN-MISSION-CONTROL.html"
html = read_text(html_path)
if "RAH Raven Mission Control v2.8" not in html:
    raise RuntimeError("Mission Control v2.8 identity anchor missing")
html = html.replace("RAH Raven Mission Control v2.8", "RAH Raven Mission Control v2.9")
html = html.replace("v2.8 · LOCAL FIRST", "v2.9 · LOCAL FIRST")
html = html.replace("mission-control-v2.8", "mission-control-v2.9")
old_bridge = '  function bridgeBase(){return String(localStorage.getItem("rah.bridge.base")||"http://127.0.0.1:18765").replace(/\\/+$/,"")}\n'
new_bridge = '''  function normalizeBridgeBase(raw){\n    const value=String(raw||"http://127.0.0.1:18765").trim();\n    let url;try{url=new URL(value)}catch{throw new Error("Ugyldig Desktop Bridge-adresse")};\n    if(url.protocol!=="http:"&&url.protocol!=="https:")throw new Error("Desktop Bridge må bruke HTTP eller HTTPS");\n    if(url.username||url.password)throw new Error("Desktop Bridge-adressen kan ikke inneholde brukernavn eller passord");\n    if(url.search||url.hash)throw new Error("Desktop Bridge-adressen kan ikke inneholde query eller fragment");\n    if(url.pathname&&url.pathname!=="/")throw new Error("Desktop Bridge-adressen må peke på rotadressen");\n    const host=String(url.hostname||"").toLowerCase().replace(/^\\[/,"").replace(/\\]$/,"");\n    if(!["127.0.0.1","localhost","::1"].includes(host))throw new Error("Mission Control tillater bare lokal Desktop Bridge");\n    return `${url.protocol}//${url.host}`;\n  }\n  function bridgeBase(){return normalizeBridgeBase(localStorage.getItem("rah.bridge.base")||"http://127.0.0.1:18765")}\n'''
if old_bridge not in html:
    raise RuntimeError("Mission Control bridgeBase anchor missing")
html = html.replace(old_bridge, new_bridge, 1)
write_text(html_path, html)

# Dedicated candidate component manifest.
mission_manifest = {
    "product": "RAH Raven Mission Control",
    "version": "2.9.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "RAH-RAVEN-MISSION-CONTROL.html",
    "shared_checkpoint_policy": "raven-checkpoint-policy.js",
    "local_only": True,
    "runtime_feature_change": False,
    "features": {
        "local_bridge_only": True,
        "loopback_hosts": ["127.0.0.1", "localhost", "::1"],
        "external_bridge_addresses_allowed": False,
        "chronicle_context_read_only": True,
        "mission_completion_requires_explicit_confirmation": True,
        "automatic_step_completion": False,
        "council_context_only": True,
        "agent_context_only": True,
        "chronicle_context_only": True,
        "recommended_checkpoint_navigation_read_only": True,
        "project_mission_relation_read_only": True,
        "shared_checkpoint_policy_runtime_changed": False,
        "capability_set_changed": False,
    },
    "next_milestone": "stable-gate",
}
write_json("RAH-RAVEN-MISSION-CONTROL-VERSION.json", mission_manifest)

# Master contract: Raven stays 2.0.32 temporary stable, existing stable components unchanged.
manifest = read_json("RAH-RAVEN-VERSION.json")
assert manifest["version"] == "2.0.32"
assert manifest["release_gate"]["stable_components"] == {
    "raven_vision": "0.6",
    "raven_council": "0.3",
    "agent_runner": "0.3",
    "memory_sync": "0.2",
}
files = manifest["files"]
mission_version_file = "RAH-RAVEN-MISSION-CONTROL-VERSION.json"
if mission_version_file not in files:
    insert_at = files.index("RAH-RAVEN-MISSION-CONTROL.html") + 1
    files.insert(insert_at, mission_version_file)
privacy = manifest["privacy"]
privacy["mission_control_local_bridge_only"] = True
privacy["mission_control_external_bridge_addresses_allowed"] = False
privacy["mission_control_chronicle_context_read_only"] = True
privacy["mission_control_automatic_step_completion"] = False
privacy["mission_control_stable"] = False
gate = manifest["release_gate"]
gate["component_versions"]["mission_control"] = "2.9"
gate["bugfix_component_updates"]["mission_control"] = "2.9"
write_json("RAH-RAVEN-VERSION.json", manifest)

# Mission Control dedicated regression test: preserve explicit writes and exercise boundary dynamically.
test_path = "tests/raven-mission-control.test.mjs"
test = read_text(test_path)
test = test.replace("RAH Raven Mission Control v2\\.8", "RAH Raven Mission Control v2\\.9")
test = test.replace("v2\\.8 · LOCAL FIRST", "v2\\.9 · LOCAL FIRST")
test = test.replace("mission-control-v2\\.8", "mission-control-v2\\.9")
anchor = 'assert.match(html,/\\/chronicle\\/brief\\?hours=24/);\n'
insert = r'''assert.match(html,/function normalizeBridgeBase\(raw\)/);
assert.match(html,/function bridgeBase\(\)\{return normalizeBridgeBase\(/);
const normalizeBody=between(html,'function normalizeBridgeBase(raw){','function bridgeBase()','bridge boundary');
const normalizeBridgeBase=new Function('raw',`function normalizeBridgeBase(raw){${normalizeBody}};return normalizeBridgeBase(raw);`);
assert.equal(normalizeBridgeBase('http://127.0.0.1:18765'),'http://127.0.0.1:18765');
assert.equal(normalizeBridgeBase('http://localhost:18765/'),'http://localhost:18765');
assert.equal(normalizeBridgeBase('https://localhost:18765'),'https://localhost:18765');
assert.equal(normalizeBridgeBase('http://[::1]:18765'),'http://[::1]:18765');
for(const bad of ['https://example.com','http://192.168.1.10:18765','file:///tmp/bridge','http://user:pass@127.0.0.1:18765','http://127.0.0.1:18765/private','http://127.0.0.1:18765?x=1','http://127.0.0.1:18765#x']) assert.throws(()=>normalizeBridgeBase(bad));
const chronicleBody=between(html,'async function loadChronicleContext(){','function latestChronicleLoop()','chronicle context');
assert.match(chronicleBody,/fetch\(`\$\{bridgeBase\(\)\}\/chronicle\/brief\?hours=24`/);
'''
if anchor not in test:
    raise RuntimeError("Mission Control test Chronicle anchor missing")
test = test.replace(anchor, anchor + insert, 1)
test = test.replace(
    "Raven Mission Control v2.8 shared Context Snapshot and safe mission controls passed.",
    "Raven Mission Control v2.9 local Bridge boundary, shared Context Snapshot and safe mission controls passed.",
)
write_text(test_path, test)

# Aggregate release gate understands candidate without promoting it to stable.
release_path = "tests/raven-release-gate.test.mjs"
release = read_text(release_path)
release = release.replace(
    'assert.equal(manifest.release_gate?.bugfix_component_updates?.memory_sync,"0.2");',
    'assert.equal(manifest.release_gate?.bugfix_component_updates?.memory_sync,"0.2");\nassert.equal(manifest.release_gate?.bugfix_component_updates?.mission_control,"2.9");',
    1,
)
release = release.replace(
    'mission_control:["RAH-RAVEN-MISSION-CONTROL.html","RAH Raven Mission Control v2.8","2.8"],',
    'mission_control:["RAH-RAVEN-MISSION-CONTROL.html","RAH Raven Mission Control v2.9","2.9"],',
    1,
)
privacy_anchor = 'assert.equal(privacy.memory_sync_stable,true,"Memory Sync v0.2 stable marker must stay true");'
privacy_insert = '''assert.equal(privacy.mission_control_local_bridge_only,true,"Mission Control Bridge must stay loopback-only");
assert.equal(privacy.mission_control_external_bridge_addresses_allowed,false,"Mission Control external Bridge addresses must stay blocked");
assert.equal(privacy.mission_control_chronicle_context_read_only,true,"Mission Control Chronicle context must remain read-only");
assert.equal(privacy.mission_control_automatic_step_completion,false,"Mission Control must not auto-complete steps");
assert.equal(privacy.mission_control_stable,false,"Mission Control v2.9 remains candidate until its stable gate passes");'''
if privacy_anchor not in release:
    raise RuntimeError("Release privacy anchor missing")
release = release.replace(privacy_anchor, privacy_anchor + "\n" + privacy_insert, 1)
mission_block_anchor = 'assert.ok(manifest.files.includes("RAH-RAVEN-MEMORY-SYNC-VERSION.json"),"Memory Sync component manifest must ship in Raven package");'
mission_block = '''assert.ok(manifest.files.includes("RAH-RAVEN-MISSION-CONTROL-VERSION.json"),"Mission Control component manifest must ship in Raven package");
const missionManifest=JSON.parse(read("RAH-RAVEN-MISSION-CONTROL-VERSION.json"));
assert.equal(missionManifest.version,"2.9.0");
assert.equal(missionManifest.stage,"candidate");
assert.equal(missionManifest.runtime_feature_change,false);
assert.equal(missionManifest.features.local_bridge_only,true);
assert.equal(missionManifest.features.external_bridge_addresses_allowed,false);
assert.equal(missionManifest.features.chronicle_context_read_only,true);
assert.equal(missionManifest.features.mission_completion_requires_explicit_confirmation,true);
assert.equal(missionManifest.features.automatic_step_completion,false);
assert.equal(missionManifest.features.council_context_only,true);
assert.equal(missionManifest.features.agent_context_only,true);
assert.equal(missionManifest.features.chronicle_context_only,true);
assert.equal(missionManifest.features.recommended_checkpoint_navigation_read_only,true);
assert.equal(missionManifest.features.project_mission_relation_read_only,true);
assert.equal(missionManifest.features.shared_checkpoint_policy_runtime_changed,false);
assert.equal(missionManifest.features.capability_set_changed,false);
assert.equal(missionManifest.next_milestone,"stable-gate");

'''
if mission_block_anchor not in release:
    raise RuntimeError("Release Mission Control insertion anchor missing")
release = release.replace(mission_block_anchor, mission_block + mission_block_anchor, 1)
release = release.replace(
    "RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 stable boundaries OK.",
    "RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 stable; Mission Control v2.9 candidate boundary OK.",
)
write_text(release_path, release)

print("Mission Control v2.9 candidate built: local Bridge boundary only; stable components untouched.")

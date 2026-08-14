from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read_text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write_text(path: str, value: str) -> None:
    (ROOT / path).write_text(value, encoding="utf-8")


def read_json(path: str) -> dict:
    return json.loads(read_text(path))


def write_json(path: str, value: dict) -> None:
    write_text(path, json.dumps(value, indent=2, ensure_ascii=False) + "\n")


# Memory Sync UI: security boundary only. No new metadata sources or automatic writes.
page_path = "RAH-RAVEN-MEMORY-SYNC.html"
page = read_text(page_path)
replacements = {
    "<title>RAH Raven Memory Sync v0.1</title>": "<title>RAH Raven Memory Sync v0.2</title>",
    '<span class="badge">v0.1</span>': '<span class="badge">v0.2 · LOCAL ONLY</span>',
    '<div class="field"><label>Bridge-adresse</label><input id="bridgeBase" value="http://127.0.0.1:18765"></div>': '<div class="field"><label>Bridge-adresse</label><input id="bridgeBase" value="http://127.0.0.1:18765"><small style="color:var(--muted)">Kun lokal loopback er tillatt: 127.0.0.1, localhost eller ::1. Eksterne adresser blokkeres før nettverkskall.</small></div>',
    '<p class="footer">Memory Sync skriver bare til den lokale Chronicle-filen etter ett eksplisitt klikk. Den endrer ikke prosjektkode.</p>': '<p class="footer">Memory Sync v0.2 skriver bare privat statusmetadata til lokal Chronicle etter ett eksplisitt klikk. Eksterne Bridge-adresser blokkeres før nettverkskall.</p>',
    '  const base = () => String($("bridgeBase").value || "http://127.0.0.1:18765").replace(/\\/+$/, "");': '  const DEFAULT_BRIDGE_BASE = "http://127.0.0.1:18765";\n  function normalizeBridgeBase(value=DEFAULT_BRIDGE_BASE) {\n    let url;\n    try { url = new URL(String(value || DEFAULT_BRIDGE_BASE)); }\n    catch { throw new Error("Memory Sync Bridge må bruke en lokal loopback-adresse."); }\n    const host = String(url.hostname || "").toLowerCase();\n    if(!["127.0.0.1","localhost","::1","[::1]"].includes(host)) throw new Error("Memory Sync Bridge må bruke en lokal loopback-adresse.");\n    if(!["http:","https:"].includes(url.protocol)) throw new Error("Memory Sync Bridge må bruke HTTP på lokal loopback.");\n    if(url.username || url.password || url.search || url.hash || !["","/"].includes(url.pathname)) throw new Error("Memory Sync Bridge-adressen kan ikke inneholde sti, innlogging, søk eller fragment.");\n    return `${url.protocol}//${url.host}`;\n  }\n  const base = () => normalizeBridgeBase($("bridgeBase").value || DEFAULT_BRIDGE_BASE);',
    '  $("bridgeBase").onchange=()=>{localStorage.setItem("rah.bridge.base",base());testBridge();};': '  $("bridgeBase").onchange=()=>{\n    try {\n      const normalized=base();\n      $("bridgeBase").value=normalized;\n      localStorage.setItem("rah.bridge.base",normalized);\n    } catch(error) {\n      bridgeReady=false;\n      setState("bridgeState","BLOKKERT","bad");\n      setState("chronicleState","VENTER","warn");\n      $("runStatus").textContent=error.message;\n      $("sync").disabled=true;\n      return;\n    }\n    testBridge();\n  };',
}
for old, new in replacements.items():
    if old not in page:
        raise RuntimeError(f"Memory Sync UI anchor missing: {old[:90]}")
    page = page.replace(old, new, 1)
write_text(page_path, page)

# Candidate component contract.
memory_manifest = {
    "product": "RAH Raven Memory Sync",
    "version": "0.2.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "RAH-RAVEN-MEMORY-SYNC.html",
    "sync_core": "raven-chronicle-sync.js",
    "sync_core_version": "0.1.0",
    "local_only": True,
    "runtime_feature_change": False,
    "features": {
        "local_bridge_only": True,
        "loopback_hosts": ["127.0.0.1", "localhost", "::1"],
        "external_bridge_addresses_allowed": False,
        "chronicle_write_requires_explicit_confirmation": True,
        "general_background_permission": False,
        "automatic_sync": False,
        "metadata_only": True,
        "allowed_sources": ["vision", "council", "agent-runner", "mission"],
        "images_included": False,
        "prompts_included": False,
        "model_answers_included": False,
        "document_text_included": False,
        "command_output_included": False,
        "error_logs_included": False,
        "sync_status_local_only": True,
        "forget_sync_status_deletes_chronicle_events": False,
        "sync_core_runtime_changed": False,
    },
    "next_milestone": "stable-gate",
}
write_json("RAH-RAVEN-MEMORY-SYNC-VERSION.json", memory_manifest)

# Master Raven contract remains 2.0.32 temporary stable; Memory Sync is candidate only.
manifest = read_json("RAH-RAVEN-VERSION.json")
assert manifest["version"] == "2.0.32"
assert manifest["release_gate"]["stable_components"] == {
    "raven_vision": "0.6",
    "raven_council": "0.3",
    "agent_runner": "0.3",
}
manifest["summary"] = (
    "RAH Raven 2.0.32 remains the temporary stable freeze. Vision Core v0.6, Council v0.3 and "
    "Agent Runner v0.3 remain stable. Memory Sync v0.2 is a safety-only candidate adding a "
    "loopback-only Bridge boundary while retaining explicit metadata-only Chronicle writes."
)
files = manifest["files"]
if "RAH-RAVEN-MEMORY-SYNC-VERSION.json" not in files:
    index = files.index("RAH-RAVEN-MEMORY-SYNC.html") + 1
    files.insert(index, "RAH-RAVEN-MEMORY-SYNC-VERSION.json")
privacy = manifest["privacy"]
privacy.update({
    "memory_sync_local_bridge_only": True,
    "memory_sync_external_bridge_addresses_allowed": False,
    "memory_sync_explicit_write_only": True,
    "memory_sync_metadata_only": True,
    "memory_sync_automatic_sync": False,
    "memory_sync_stable": False,
})
manifest["release_gate"]["component_versions"]["memory_sync"] = "0.2"
manifest["release_gate"]["bugfix_component_updates"]["memory_sync"] = "0.2"
write_json("RAH-RAVEN-VERSION.json", manifest)

# Dedicated Memory Sync contract test, including secret-leak probes through the sync core.
memory_test = r'''import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const CORE = require("../raven-chronicle-sync.js");
const page = fs.readFileSync("RAH-RAVEN-MEMORY-SYNC.html", "utf8");
const component = JSON.parse(fs.readFileSync("RAH-RAVEN-MEMORY-SYNC-VERSION.json", "utf8"));

assert.match(page, /RAH Raven Memory Sync v0\.2/);
assert.match(page, /v0\.2 · LOCAL ONLY/);
assert.match(page, /normalizeBridgeBase/);
assert.match(page, /127\.0\.0\.1/);
assert.match(page, /localhost/);
assert.match(page, /::1/);
assert.match(page, /external|Eksterne/i);
assert.match(page, /confirmSync/);
assert.match(page, /if\(!bridgeReady \|\| !pending\.length \|\| !\$\("confirmSync"\)\.checked\) return/);
assert.match(page, /\/chronicle\/event/);
assert.match(page, /method:"POST"/);
assert.doesNotMatch(page, /setInterval\s*\(\s*syncEvents|setTimeout\s*\(\s*syncEvents/);

assert.equal(component.version, "0.2.0");
assert.equal(component.stage, "candidate");
assert.equal(component.runtime_feature_change, false);
assert.equal(component.features.local_bridge_only, true);
assert.equal(component.features.external_bridge_addresses_allowed, false);
assert.equal(component.features.chronicle_write_requires_explicit_confirmation, true);
assert.equal(component.features.general_background_permission, false);
assert.equal(component.features.automatic_sync, false);
assert.equal(component.features.metadata_only, true);
assert.equal(component.features.sync_core_runtime_changed, false);

const secrets = [
  "VISION_PROMPT_SECRET",
  "VISION_ANSWER_SECRET",
  "COUNCIL_GOAL_SECRET",
  "COUNCIL_ADVICE_SECRET",
  "AGENT_STDOUT_SECRET",
  "AGENT_STDERR_SECRET",
  "AGENT_COMMAND_SECRET",
  "MISSION_TITLE_SECRET",
  "MISSION_DETAIL_SECRET",
];
const events = CORE.buildEvents({
  vision: { id: "v1", source: "manual-image", model: "local-model", createdAt: "2026-08-14T08:00:00Z", prompt: secrets[0], answer: secrets[1] },
  council: { id: "c1", project: "RAH Platform", model: "local-model", createdAt: "2026-08-14T08:01:00Z", goal: secrets[2], advice: secrets[3], roles: { planner: "x" }, plan: ["x"] },
  agent: { id: "a1", title: "Static validation", time: "2026-08-14T08:02:00Z", ok: true, durationMs: 7, readOnly: true, filesModified: false, stdout: secrets[4], stderr: secrets[5], command: [secrets[6]] },
  mission: { id: "m1", title: secrets[7], status: "ACTIVE", updatedAt: "2026-08-14T08:03:00Z", steps: [{ title: secrets[8], detail: secrets[8] }] },
});
assert.equal(events.length, 4);
const payloads = events.map(event => CORE.toChroniclePayload(event));
for (const payload of payloads) {
  assert.deepEqual(Object.keys(payload).sort(), ["category", "note", "privacy", "project", "title"]);
  assert.equal(payload.privacy, "private");
}
const serialized = JSON.stringify(payloads);
for (const secret of secrets) assert.equal(serialized.includes(secret), false, `private content leaked: ${secret}`);

console.log("Raven Memory Sync v0.2 local-boundary and metadata-only contract passed.");
'''
write_text("tests/raven-memory-sync.test.mjs", memory_test)

# Extend aggregate release gate with candidate identity and safety assertions.
test_path = "tests/raven-release-gate.test.mjs"
test = read_text(test_path)
repls = {
    'assert.equal(manifest.release_gate?.bugfix_component_updates?.agent_runner,"0.3");': 'assert.equal(manifest.release_gate?.bugfix_component_updates?.agent_runner,"0.3");\nassert.equal(manifest.release_gate?.bugfix_component_updates?.memory_sync,"0.2");',
    'memory_sync:["RAH-RAVEN-MEMORY-SYNC.html","RAH Raven Memory Sync v0.1","0.1"]': 'memory_sync:["RAH-RAVEN-MEMORY-SYNC.html","RAH Raven Memory Sync v0.2","0.2"]',
    'assert.equal(privacy.agent_runner_external_bridge_addresses_allowed,false,"Agent Runner external Bridge addresses must stay blocked");': 'assert.equal(privacy.agent_runner_external_bridge_addresses_allowed,false,"Agent Runner external Bridge addresses must stay blocked");\nassert.equal(privacy.memory_sync_external_bridge_addresses_allowed,false,"Memory Sync external Bridge addresses must stay blocked");\nassert.equal(privacy.memory_sync_local_bridge_only,true,"Memory Sync Bridge must stay loopback-only");\nassert.equal(privacy.memory_sync_explicit_write_only,true,"Memory Sync Chronicle writes must remain explicit");\nassert.equal(privacy.memory_sync_metadata_only,true,"Memory Sync must remain metadata-only");\nassert.equal(privacy.memory_sync_automatic_sync,false,"Memory Sync automatic sync must stay disabled");\nassert.equal(privacy.memory_sync_stable,false,"Memory Sync v0.2 remains candidate until its stable gate passes");',
    'const now=read("RAH-RAVEN-NOW-V2.html");': 'assert.ok(manifest.files.includes("RAH-RAVEN-MEMORY-SYNC-VERSION.json"),"Memory Sync component manifest must ship in Raven package");\nconst memoryManifest=JSON.parse(read("RAH-RAVEN-MEMORY-SYNC-VERSION.json"));\nassert.equal(memoryManifest.version,"0.2.0");\nassert.equal(memoryManifest.stage,"candidate");\nassert.equal(memoryManifest.runtime_feature_change,false);\nassert.equal(memoryManifest.features.local_bridge_only,true);\nassert.equal(memoryManifest.features.external_bridge_addresses_allowed,false);\nassert.equal(memoryManifest.features.chronicle_write_requires_explicit_confirmation,true);\nassert.equal(memoryManifest.features.general_background_permission,false);\nassert.equal(memoryManifest.features.automatic_sync,false);\nassert.equal(memoryManifest.features.metadata_only,true);\nassert.equal(memoryManifest.features.images_included,false);\nassert.equal(memoryManifest.features.prompts_included,false);\nassert.equal(memoryManifest.features.model_answers_included,false);\nassert.equal(memoryManifest.features.document_text_included,false);\nassert.equal(memoryManifest.features.command_output_included,false);\nassert.equal(memoryManifest.features.error_logs_included,false);\nassert.equal(memoryManifest.features.sync_core_runtime_changed,false);\n\nconst now=read("RAH-RAVEN-NOW-V2.html");',
    'console.log("RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 stable boundaries OK.");': 'console.log("RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 stable; Memory Sync v0.2 candidate boundary OK.");',
}
for old, new in repls.items():
    if old not in test:
        raise RuntimeError(f"Release gate anchor missing: {old}")
    test = test.replace(old, new, 1)
write_text(test_path, test)

print("Memory Sync v0.2 candidate built: loopback-only Bridge boundary + metadata-only contract; no sync-core expansion.")

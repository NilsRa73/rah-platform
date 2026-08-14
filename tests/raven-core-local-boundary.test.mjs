import assert from "node:assert/strict";
import fs from "node:fs";

const html=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");
const manifest=JSON.parse(fs.readFileSync("RAH-RAVEN-CORE-VERSION.json","utf8"));
const start=html.indexOf("function normalizeBridgeBase(raw) {");
const end=html.indexOf("  const BRIDGE_BASE",start);
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
assert.equal(manifest.stage,"stable");
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
assert.equal(manifest.next_milestone,null);
assert.equal(manifest.development_paused,true);
assert.equal(manifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(manifest.stable_release_gate?.status,"passed");
assert.equal(manifest.stable_release_gate?.runtime_files_frozen,true);

assert.ok(html.includes('fetchJson(`${BRIDGE_BASE()}/health`)'));
assert.ok(html.includes('fetchJson(`${BRIDGE_BASE()}/lm/models`)'));
assert.equal(/api\.openai\.com|chatgpt\.com\/backend/i.test(html),false);

console.log("Raven Core v1.12 stable local Bridge boundary passed.");

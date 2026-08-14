import assert from "node:assert/strict";
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

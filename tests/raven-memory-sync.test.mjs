import assert from "node:assert/strict";
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

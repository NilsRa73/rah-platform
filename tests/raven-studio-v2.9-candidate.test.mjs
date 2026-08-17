import assert from "node:assert/strict";
import fs from "node:fs";

const html=fs.readFileSync("RAH-RAVEN-START-V2.9-CANDIDATE.html","utf8");
const m=JSON.parse(fs.readFileSync("RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json","utf8"));

for(const marker of [
  'RAH-RAVEN-START.html',
  'RAH-RAVEN-VISION-CORE.html',
  'RAH-RAVEN-COUNCIL.html',
  'RAH-RAVEN-MISSION-CONTROL.html',
  'RAH-COMMAND-CENTER-V2.1.html',
  'http://127.0.0.1:18765/chronicle/ui',
  'http://127.0.0.1:18765/chronicle/insights-ui'
]) assert.ok(html.includes(marker),marker);

assert.match(html,/Vision: MODELL FUNNET/);
assert.match(html,/bekrefte faktisk bildekapabilitet/);
assert.doesNotMatch(html,/Vision: KLAR/);
assert.match(html,/council_proxy/);
assert.match(html,/127\.0\.0\.1:18765\/health/);
assert.match(html,/127\.0\.0\.1:18765\/lm\/models/);
assert.match(html,/127\.0\.0\.1:1234\/v1\/models/);
assert.doesNotMatch(html,/api\.openai\.com|supabase\.co|\/agent\/run/i);
assert.doesNotMatch(html,/method\s*:\s*["']POST["']/i);
assert.doesNotMatch(html,/localStorage\.setItem/);

assert.equal(m.version,"2.9.0");
assert.equal(m.stage,"candidate");
assert.equal(m.authority_delta,"none");
assert.equal(m.stable_runtime_files_modified,false);
assert.equal(m.stable_base.raven_studio,"2.8");
assert.equal(m.stable_base.raven_vision,"0.6");
assert.equal(m.stable_base.raven_council,"0.3");
assert.equal(m.stable_base.command_center,"2.1");
assert.equal(m.features.single_window_workspace,true);
assert.equal(m.features.vision_status_requires_explicit_image_test,true);
assert.equal(m.features.automatic_actions,false);
assert.equal(m.features.raven_state_writes,false);
assert.equal(m.features.agent_execution,false);
assert.equal(m.promotion_policy.replace_stable_2_8,false);
assert.equal(m.promotion_policy.stable_promotion_included,false);

console.log("Raven Studio v2.9 Unified CC Candidate contract passed.");

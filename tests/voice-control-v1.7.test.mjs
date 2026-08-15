import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const read = path => fs.readFileSync(path, "utf8");
const moduleText = read("voice-control-v1.7.js");
const html = read("index.html");
const component = JSON.parse(read("RAH-RAVEN-VOICE-CONTROL-VERSION.json"));
const master = JSON.parse(read("RAH-RAVEN-VERSION.json"));

const hookMatches = html.match(/voice-control-v1\.7\.js\?v=1\.7/g) || [];
assert.equal(hookMatches.length, 1);
assert.doesNotMatch(html, /voice-control-v1\.6\.js\?v=1\.6/);
assert.equal(fs.existsSync("voice-control-v1.6.js"), false);
assert.equal(fs.existsSync(".github/workflows/integrate-voice-control-v1.6.yml"), false);

assert.match(moduleText, /const VERSION = "1\.7\.0"/);
assert.match(moduleText, /const BRIDGE_HEALTH_URL = "http:\/\/127\.0\.0\.1:18765\/health"/);
assert.doesNotMatch(moduleText, /127\.0\.0\.1:8765|port 8765/);
assert.match(moduleText, /credentials: "omit"/);
assert.match(moduleText, /protectedActions\.has\(command\.id\)/);
assert.match(moduleText, /\["ja", "ja bekreft", "bekreft", "ok bekreft"\]\.includes\(q\)/);
assert.doesNotMatch(moduleText, /q\.includes\(p\)/);
assert.doesNotMatch(moduleText, /settings\.confirmations/);
assert.match(moduleText, /Sikkerhetsbekreftelser: PÅ \(låst\)/);

assert.equal(component.product, "RAH Raven Voice Control");
assert.equal(component.version, "1.7.0");
assert.equal(component.stage, "stable");
assert.equal(component.runtime_feature_change, false);
assert.equal(component.features.explicit_microphone_start, true);
assert.equal(component.features.automatic_listening, false);
assert.equal(component.features.hidden_microphone, false);
assert.equal(component.features.browser_speech_recognition_may_use_external_service, true);
assert.equal(component.features.bridge_local_only, true);
assert.equal(component.features.bridge_health_url, "http://127.0.0.1:18765/health");
assert.equal(component.features.external_bridge_addresses_allowed, false);
assert.equal(component.features.protected_confirmations_locked, true);
assert.equal(component.features.confirmation_response_exact_match, true);
assert.equal(component.features.incidental_phrase_execution, false);
assert.equal(component.features.mission_next_requires_confirmation, true);
assert.equal(component.features.cloud_sync_requires_confirmation, true);
assert.equal(component.features.destructive_actions_require_confirmation, true);
assert.equal(component.features.settings_parse_failure_safe, true);
assert.equal(component.features.automatic_sending, false);
assert.equal(component.features.capability_set_changed, false);
assert.equal(component.next_milestone, null);
assert.equal(component.stable_since, "2026-08-15");
assert.equal(component.development_paused, true);
assert.equal(component.change_policy, "bugfix-only-until-explicit-reopen");
assert.deepEqual(component.stable_release_gate, {
  status: "passed",
  gate_version: "1.0.0",
  runtime_files_frozen: true
});

assert.ok(master.files.includes("RAH-RAVEN-VOICE-CONTROL-VERSION.json"));
assert.ok(master.files.includes("voice-control-v1.7.js"));
assert.equal(master.privacy.voice_control_version_synced, true);
assert.equal(master.privacy.voice_control_explicit_microphone_start, true);
assert.equal(master.privacy.voice_control_automatic_listening, false);
assert.equal(master.privacy.voice_control_hidden_microphone, false);
assert.equal(master.privacy.voice_control_local_bridge_only, true);
assert.equal(master.privacy.voice_control_external_bridge_addresses_allowed, false);
assert.equal(master.privacy.voice_control_canonical_bridge_port_synced, true);
assert.equal(master.privacy.voice_control_protected_confirmations_locked, true);
assert.equal(master.privacy.voice_control_confirmation_response_exact_match, true);
assert.equal(master.privacy.voice_control_incidental_phrase_execution, false);
assert.equal(master.privacy.voice_control_mission_step_requires_confirmation, true);
assert.equal(master.privacy.voice_control_cloud_sync_requires_confirmation, true);
assert.equal(master.privacy.voice_control_automatic_sending, false);
assert.equal(master.privacy.voice_control_stable, true);

const stable = {raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};
assert.deepEqual(master.release_gate.stable_components, stable);

const storage = new Map([
  ["rah.voice.v1.7.settings", "{invalid json"],
  ["rah.voice.v1.6.settings", "{also invalid"]
]);
const clicks = new Map();
let openedUrl = null;
let missionRuns = 0;
const elements = {
  voiceTranscript: { textContent: "" },
  missionStatus: { textContent: "RUNNING" },
  clearData: { click: () => clicks.set("clearData", (clicks.get("clearData") || 0) + 1) },
  runNextMissionStep: { click: () => missionRuns += 1 }
};
const document = {
  readyState: "complete",
  getElementById: id => elements[id] || null,
  querySelector: () => null,
  querySelectorAll: () => [],
  addEventListener: () => {}
};
const context = {
  console: { ...console, info: () => {}, warn: () => {} },
  document,
  localStorage: {
    getItem: key => storage.has(key) ? storage.get(key) : null,
    setItem: (key, value) => storage.set(key, value)
  },
  setTimeout: () => 1,
  clearTimeout: () => {},
  fetch: async () => ({ ok: true, json: async () => ({ version: "test" }) }),
  SpeechSynthesisUtterance: class {},
  window: {
    notify: () => {},
    renderVoiceControl: () => {},
    runNextMissionStep: () => missionRuns += 1,
    open: url => { openedUrl = url; }
  }
};
context.window.window = context.window;
vm.createContext(context);
vm.runInContext(moduleText, context, { filename: "voice-control-v1.7.js" });

const voice = context.window.RAHVoice;
assert.equal(voice.version, "1.7.0");
assert.equal(voice.settings.speechEnabled, true, "invalid stored settings must fall back safely");
assert.equal(Object.hasOwn(voice.settings, "confirmations"), false, "protected confirmations must not be configurable");

assert.equal(await voice.process("kan du kanskje åpne github"), false, "incidental speech must not execute a command");
assert.equal(openedUrl, null);
assert.equal(await voice.process("åpne github"), true);
assert.equal(openedUrl, "https://github.com/NilsRa73/rah-platform");

assert.equal(await voice.process("slett lokale data"), true);
assert.equal(clicks.get("clearData") || 0, 0, "protected command must wait for confirmation");
assert.equal(await voice.process("ikke bekreft"), true);
assert.equal(clicks.get("clearData") || 0, 0, "negative phrase containing 'bekreft' must not confirm");
assert.equal(await voice.process("ja bekreft"), true);
assert.equal(clicks.get("clearData"), 1);

assert.equal(await voice.process("kjør neste steg"), true);
assert.equal(missionRuns, 0, "mission execution must wait for confirmation");
assert.equal(await voice.process("ja bekreft"), true);
assert.equal(missionRuns, 1);

const missionNext = voice.commands.find(command => command.id === "mission-next");
const missionResume = voice.commands.find(command => command.id === "mission-resume");
assert.equal(missionNext.phrases.includes("fortsett mission"), false);
assert.equal(missionResume.phrases.includes("fortsett mission"), true);

console.log("RAH Raven Voice Control v1.7 stable contract passed with runtime freeze preserved.");

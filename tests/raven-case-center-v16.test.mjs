import assert from "node:assert/strict";
import fs from "node:fs";

const shell = fs.readFileSync("RAH-RAVEN-CASE-CENTER.html", "utf8");
const server = fs.readFileSync("desktop-bridge/server_v16.py", "utf8");
const component = JSON.parse(fs.readFileSync("RAH-RAVEN-CASE-CENTER-VERSION.json", "utf8"));
const master = JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json", "utf8"));

assert.match(shell, /Case Center v1\.6/);
assert.match(shell, /http:\/\/127\.0\.0\.1:18765\/case/);
assert.doesNotMatch(shell, /localStorage\s*\.|sessionStorage\s*\.|new\s+SpeechRecognition|new\s+webkitSpeechRecognition/);
assert.doesNotMatch(shell, /professionalApproved|approveProfessional|FAGLIG GODKJENT/);
assert.doesNotMatch(shell, /fetch\s*\(/);

assert.match(server, /CASE_CENTER_VERSION = "1\.6\.0"/);
assert.match(server, /DIRECT_RUN_DISABLED = True/);
assert.match(server, /_normalize_loopback_host/);
assert.match(server, /_normalize_loopback_base/);
assert.match(server, /case_center_version/);
assert.doesNotMatch(server, /app\.run\(host=HOST, port=PORT/);

assert.equal(component.product, "RAH Raven Case Center");
assert.equal(component.version, "1.6.0");
assert.equal(component.stage, "candidate");
assert.equal(component.local_only, true);
assert.equal(component.features.canonical_bridge_entry_only, true);
assert.equal(component.features.direct_server_v16_disabled, true);
assert.equal(component.features.bridge_bind_loopback_only, true);
assert.equal(component.features.lm_studio_loopback_only, true);
assert.equal(component.features.external_ai_endpoints, false);
assert.equal(component.features.legacy_launcher_document_storage, false);
assert.equal(component.features.legacy_launcher_localstorage, false);
assert.equal(component.features.canonical_server_persists_documents, false);
assert.equal(component.features.analysis_requires_explicit_click, true);
assert.equal(component.features.human_review_required, true);
assert.equal(component.features.professional_approval_self_attestation, false);
assert.equal(component.features.automatic_sending, false);
assert.equal(component.next_milestone, "stable-gate");

const stable = {raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};
assert.deepEqual(master.release_gate.stable_components, stable);
assert.equal(master.privacy.raven_chronicle_stable, true);
assert.equal(master.privacy.system_health_stable, true);
assert.equal(master.privacy.case_center_stable, false);
assert.equal(master.privacy.case_center_canonical_bridge_entry_only, true);
assert.equal(master.privacy.case_center_direct_server_v16_disabled, true);
assert.equal(master.privacy.case_center_lm_studio_loopback_only, true);
assert.equal(master.privacy.case_center_legacy_launcher_localstorage, false);
assert.equal(master.privacy.case_center_professional_approval_self_attestation, false);
console.log("RAH Raven Case Center v1.6 candidate contract passed.");

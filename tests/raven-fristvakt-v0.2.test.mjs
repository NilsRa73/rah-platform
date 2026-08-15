import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-FRISTVAKT.html','utf8');
const manifest = JSON.parse(fs.readFileSync('RAH-RAVEN-FRISTVAKT-VERSION.json','utf8'));
const raven = JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const expectedCore = {
  raven_vision:'0.6', raven_council:'0.3', agent_runner:'0.3', memory_sync:'0.2',
  mission_control:'2.9', project_focus:'2.4', raven_core:'1.12', raven_now:'2.17', raven_studio:'2.8'
};

assert.equal(manifest.product,'RAH Raven Fristvakt');
assert.equal(manifest.version,'0.2.0');
assert.equal(manifest.stage,'stable');
assert.equal(manifest.local_only,true);
assert.equal(manifest.features.automatic_persistence,false);
assert.equal(manifest.features.browser_storage,false);
assert.equal(manifest.features.session_memory_only,true);
assert.equal(manifest.features.explicit_json_export,true);
assert.equal(manifest.features.explicit_json_import,true);
assert.equal(manifest.features.automatic_sending,false);
assert.equal(manifest.features.automatic_calling,false);
assert.equal(manifest.features.automatic_network_requests,false);
assert.equal(manifest.features.hardcoded_contact_number,false);
assert.equal(manifest.features.result_requires_user_confirmation,true);
assert.equal(manifest.release_gate.status,'passed');
assert.equal(manifest.release_gate.runtime_files_frozen,true);
assert.equal(manifest.development_paused,true);
assert.equal(manifest.change_policy,'bugfix-only-until-explicit-reopen');

assert.match(html,/RAH Raven Fristvakt v0\.2/);
assert.match(html,/Opplysningene holdes bare i minnet/);
assert.match(html,/verifisert 15\.08\.2026/);
assert.match(html,/10 virkedager/);
assert.match(html,/Mulig fristbrudd – må bekreftes/);
assert.match(html,/Fristvakt sender, ringer eller endrer ingenting/);
assert.match(html,/helsenorge\.no\/rettigheter\/dine-rettigheter-ved-fristbrudd/);
assert.match(html,/helsenorge\.no\/rettigheter\/sykehus-og-spesialist\/rett-til-nodvendig-helsehjelp/);
assert.doesNotMatch(html,/localStorage\s*\.|sessionStorage\s*\.|indexedDB\s*\./i);
assert.doesNotMatch(html,/\bfetch\s*\(|XMLHttpRequest|WebSocket|EventSource/i);
assert.doesNotMatch(html,/href=["']tel:/i);
assert.doesNotMatch(html,/23\s*32\s*70\s*03/);
assert.doesNotMatch(html,/setInterval\s*\(|setTimeout\s*\([^)]*(analyse|fetch)/i);
assert.doesNotMatch(html,/navigator\.(mediaDevices|clipboard)|getUserMedia|SpeechRecognition/i);

assert.deepEqual(raven.release_gate.stable_components, expectedCore);
assert.equal(raven.privacy.raven_care_stable,true);
assert.equal(raven.privacy.case_center_stable,true);
assert.equal(raven.privacy.command_center_stable,true);
assert.equal(raven.privacy.raven_fristvakt_version_synced,true);
assert.equal(raven.privacy.raven_fristvakt_session_memory_only,true);
assert.equal(raven.privacy.raven_fristvakt_automatic_persistence,false);
assert.equal(raven.privacy.raven_fristvakt_browser_storage,false);
assert.equal(raven.privacy.raven_fristvakt_automatic_network_requests,false);
assert.equal(raven.privacy.raven_fristvakt_hardcoded_contact_number,false);
assert.equal(raven.privacy.raven_fristvakt_runtime_frozen,true);
assert.equal(raven.privacy.raven_fristvakt_stable,true);

console.log('RAH Raven Fristvakt v0.2 safety boundary passed');

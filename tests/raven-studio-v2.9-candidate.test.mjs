import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const html=fs.readFileSync('RAH-RAVEN-START-V2.9-CANDIDATE.html','utf8');
const candidate=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json','utf8'));
const stable=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-VERSION.json','utf8'));
const cc=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const raven=JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const statusUrls=[
  'http://127.0.0.1:18765/health',
  'http://127.0.0.1:18765/lm/models',
  'http://127.0.0.1:1234/v1/models'
];

test('Candidate is a thin shell over current frozen Stable bases',()=>{
  assert.equal(candidate.product,'RAH Raven Studio');
  assert.equal(candidate.version,'2.9.0');
  assert.equal(candidate.stage,'candidate');
  assert.equal(candidate.authority_delta,'none');
  assert.equal(candidate.stable_runtime_files_modified,false);
  assert.equal(candidate.stable_base.raven_studio,'2.8.0');
  assert.equal(candidate.stable_base.raven_vision,'0.6');
  assert.equal(candidate.stable_base.raven_council,'0.3');
  assert.equal(candidate.stable_base.command_center,'2.3.0');
  assert.equal(candidate.stable_base.command_center_package_generation,8);
  assert.equal(candidate.stable_base.raven,'2.0.32');
  assert.equal(stable.version,'2.8.0');
  assert.equal(stable.stage,'stable');
  assert.equal(stable.development_paused,true);
  assert.equal(cc.version,'2.3.0');
  assert.equal(cc.stage,'stable');
  assert.equal(cc.canonical_package_generation,8);
  assert.equal(raven.version,'2.0.32');
});

test('Unified navigation points at current Stable components',()=>{
  for(const marker of [
    'RAH-RAVEN-START.html',
    'RAH-RAVEN-VISION-CORE.html',
    'RAH-RAVEN-COUNCIL.html',
    'RAH-RAVEN-MISSION-CONTROL.html',
    'RAH-COMMAND-CENTER-V2.3.html',
    'http://127.0.0.1:18765/chronicle/ui',
    'http://127.0.0.1:18765/chronicle/insights-ui'
  ]) assert.ok(html.includes(marker),marker);
  assert.doesNotMatch(html,/RAH-COMMAND-CENTER-V2\.1\.html|Devices \/ Fleet CC 2\.1/);
  assert.equal(candidate.features.devices_fleet_cc23_main_navigation,true);
});

test('Status reads are fixed loopback-only and cannot accept arbitrary URLs',()=>{
  assert.deepEqual(candidate.features.status_urls,statusUrls);
  assert.equal(candidate.features.fixed_status_url_allowlist,true);
  assert.equal(candidate.features.status_polling_loopback_only,true);
  assert.equal(candidate.features.external_status_addresses_allowed,false);
  for(const url of statusUrls) assert.ok(html.includes(url),url);
  assert.match(html,/STATUS_ALLOWLIST\.has\(url\)/);
  assert.match(html,/throw new Error\("status-url-not-allowed"\)/);
  assert.match(html,/fetch\(url,\{cache:"no-store",credentials:"omit"\}\)/);
  const urls=[...html.matchAll(/https?:\/\/[^"'<>\s]+/g)].map(x=>x[0]);
  for(const raw of urls){const u=new URL(raw);assert.equal(u.protocol,'http:');assert.equal(u.hostname,'127.0.0.1');}
});

test('Candidate shell remains observation/navigation-only',()=>{
  assert.equal(candidate.features.automatic_actions,false);
  assert.equal(candidate.features.raven_state_writes,false);
  assert.equal(candidate.features.mission_mutation,false);
  assert.equal(candidate.features.mission_step_completion,false);
  assert.equal(candidate.features.agent_execution,false);
  assert.equal(candidate.features.automatic_sending,false);
  assert.equal(candidate.features.shell_access,false);
  assert.equal(candidate.features.file_api,false);
  assert.equal(candidate.features.network_discovery,false);
  assert.equal(candidate.features.remote_control_authority,false);
  assert.doesNotMatch(html,/method\s*:\s*["']POST["']/i);
  assert.doesNotMatch(html,/localStorage\.setItem|sessionStorage\.setItem|\/agent\/run|api\.openai\.com|supabase\.co/i);
  assert.doesNotMatch(html,/\/scan|\/discover|\/command|\/shell|\/files|\/process|\/execute/i);
});

test('Vision status does not claim image capability without explicit image test',()=>{
  assert.equal(candidate.features.vision_status_requires_explicit_image_test,true);
  assert.match(html,/Vision: MODELL FUNNET/);
  assert.match(html,/bekrefte faktisk bildekapabilitet/);
  assert.doesNotMatch(html,/Vision: KLAR/);
});

test('Candidate cannot self-promote or replace Studio 2.8 Stable',()=>{
  assert.equal(candidate.promotion_policy.replace_stable_2_8,false);
  assert.equal(candidate.promotion_policy.requires_owned_windows_runtime_test,true);
  assert.equal(candidate.promotion_policy.stable_promotion_included,false);
  assert.equal(candidate.promotion_policy.candidate_can_promote_itself,false);
});

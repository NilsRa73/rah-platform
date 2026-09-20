import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const historical=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json','utf8'));
const stable3=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V3.0.json','utf8'));
const html=fs.readFileSync('RAH-RAVEN-START-V2.9-CANDIDATE.html','utf8');

test('Studio 2.9 is explicitly retired in favor of Studio 3.0 Stable',()=>{
  assert.equal(historical.product,'RAH Raven Studio');
  assert.equal(historical.version,'2.9.0');
  assert.equal(historical.stage,'retired');
  assert.equal(historical.superseded_by.version,'3.0.0');
  assert.equal(historical.superseded_by.launcher,'START-HER-RAH-RAVEN-STUDIO.cmd');
  assert.equal(historical.promotion_policy.stable_promotion_included,false);
  assert.equal(historical.promotion_policy.candidate_can_promote_itself,false);
  assert.equal(historical.promotion_policy.retired_no_promotion,true);
  assert.equal(stable3.version,'3.0.0');
  assert.equal(stable3.stage,'stable');
  assert.equal(stable3.release_gate.status,'passed');
});

test('Historical 2.9 artifact retains its original authority-neutral safety boundary',()=>{
  assert.equal(historical.authority_delta,'none');
  assert.equal(historical.stable_runtime_files_modified,false);
  assert.equal(historical.features.external_status_addresses_allowed,false);
  assert.equal(historical.features.status_polling_loopback_only,true);
  assert.equal(historical.features.automatic_actions,false);
  assert.equal(historical.features.raven_state_writes,false);
  assert.equal(historical.features.mission_mutation,false);
  assert.equal(historical.features.agent_execution,false);
  assert.equal(historical.features.shell_access,false);
  assert.equal(historical.features.file_api,false);
  assert.equal(historical.features.network_discovery,false);
  assert.equal(historical.features.remote_control_authority,false);
});

test('Historical 2.9 HTML remains a local-only artifact and is not the current launcher',()=>{
  assert.ok(html.includes('127.0.0.1:18765'));
  assert.ok(html.includes('127.0.0.1:1234'));
  assert.notEqual(stable3.entry,'RAH-RAVEN-START-V2.9-CANDIDATE.html');
  assert.equal(stable3.launcher,'START-HER-RAH-RAVEN-STUDIO.cmd');
});

console.log('Raven Studio 2.9 retirement contract: PASS; Studio 3.0 Stable is canonical.');

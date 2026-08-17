import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const stable=require('../rah-command-center-core-v2.1.js');
const candidate=require('../rah-command-center-core-v2.2-candidate.js');
const manifest=JSON.parse(fs.readFileSync('RAH-CC22-FLEET-SNAPSHOT-INVALIDATION-CANDIDATE.json','utf8'));
const html=fs.readFileSync('RAH-COMMAND-CENTER-V2.2-CANDIDATE.html','utf8');
const priorHtml=fs.readFileSync('RAH-COMMAND-CENTER-V2.1-CANDIDATE.html','utf8');

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('2.2 Candidate extends exact 2.1 Stable authority with no Node delta',()=>{
  assert.equal(stable.CC_VERSION,'2.1.0');
  assert.equal(candidate.CC_VERSION,'2.2.0-candidate');
  assert.equal(candidate.FLEET_SNAPSHOT_VERSION,'rah-cc-fleet-snapshot-v1');
  assert.equal(candidate.FLEET_SNAPSHOT_INVALIDATION_VERSION,'rah-cc-fleet-snapshot-invalidation-v1');
  assert.equal(candidate.FLEET_SNAPSHOT_FAILURE_POLICY,'invalidate-selected-row-on-refresh-failure');
  assert.deepEqual(candidate.CAPABILITY_IDS,caps);
  assert.deepEqual(candidate.ACTION_IDS,actions);
  assert.deepEqual(candidate.AUTHENTICATED_PATHS,routes);
  assert.equal(candidate.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v7');
  assert.equal(candidate.NODE_AUTH_PROTOCOL,'rah-node-auth-v2');
  assert.equal(candidate.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
});

test('invalidation removes only the explicitly selected stale memory row',()=>{
  const rows=new Map([
    ['node-a',Object.freeze({deviceId:'node-a',online:true,persistent:false})],
    ['node-b',Object.freeze({deviceId:'node-b',online:true,persistent:false})]
  ]);
  assert.equal(candidate.invalidateFleetSnapshotRow(rows,'node-a'),true);
  assert.equal(rows.has('node-a'),false);
  assert.equal(rows.has('node-b'),true);
  assert.equal(rows.size,1);
  assert.equal(candidate.invalidateFleetSnapshotRow(rows,'node-a'),false);
  assert.equal(candidate.invalidateFleetSnapshotRow(rows,''),false);
  assert.equal(candidate.invalidateFleetSnapshotRow({},'node-b'),false);
  assert.equal(rows.has('node-b'),true);
});

test('Candidate manifest is authority-neutral and explicitly fail-closed',()=>{
  assert.equal(manifest.candidate,'2.2.0-candidate');
  assert.equal(manifest.released_from_stable,'2.1.0');
  assert.equal(manifest.stage,'candidate');
  assert.equal(manifest.stable_runtime_modified,false);
  assert.equal(manifest.authority_surface_changed,false);
  assert.equal(manifest.node_agent_runtime_changed,false);
  assert.equal(manifest.fleet_snapshot_invalidation.failure_policy,'invalidate-selected-row-on-refresh-failure');
  assert.equal(manifest.fleet_snapshot_invalidation.selected_row_removed_before_failure_render,true);
  assert.equal(manifest.fleet_snapshot_invalidation.snapshot_persistence,false);
  assert.equal(manifest.fleet_snapshot_invalidation.background_polling,false);
  assert.equal(manifest.fleet_snapshot_invalidation.network_discovery,false);
  assert.deepEqual(manifest.fleet_snapshot_invalidation.new_business_routes,[]);
  assert.deepEqual(manifest.fleet_snapshot_invalidation.new_actions,[]);
  assert.deepEqual(manifest.fleet_snapshot_invalidation.new_capabilities,[]);
  assert.deepEqual(manifest.preserved_authority.capabilities,caps);
  assert.deepEqual(manifest.preserved_authority.actions,actions);
  assert.deepEqual(manifest.preserved_authority.business_routes,routes);
  assert.equal(manifest.preserved_authority.node_agent_version,'1.3.0');
});

test('2.2 UI patch targets the exact historical stale-row failure and invalidates before error render',()=>{
  const oldRefresh="async function refreshFleet(){const devices=loadDevices(),d=devices.find(x=>x.id===q('fleetDevice').value),token=q('fleetToken').value.trim(),out=q('fleetResult');try{";
  const oldFailure="}catch(e){out.className='result bad';out.textContent=e.message}finally{q('fleetToken').value=''}}";
  assert.ok(priorHtml.includes(oldRefresh),'CC2.1 refresh marker drifted');
  assert.ok(priorHtml.includes(oldFailure),'CC2.1 stale-row failure marker drifted');
  for(const marker of [
    "SOURCE='RAH-COMMAND-CENTER-V2.1-CANDIDATE.html'",
    "rah-command-center-core-v2.1.js",
    "rah-command-center-core-v2.2-candidate.js",
    "window.RAHCommandCenterFleetSnapshotInvalidationCandidate",
    "const selectedId=q('fleetDevice').value",
    "core.invalidateFleetSnapshotRow(fleetRows,selectedId);renderRows();out.className='result bad'",
    "q('fleetToken').value=''"
  ])assert.ok(html.includes(marker),marker);
  const invalidateAt=html.indexOf("core.invalidateFleetSnapshotRow(fleetRows,selectedId)");
  const renderAt=html.indexOf('renderRows()',invalidateAt);
  const errorAt=html.indexOf("out.className='result bad'",invalidateAt);
  assert.ok(invalidateAt>=0&&renderAt>invalidateAt&&errorAt>renderAt,'failed refresh must invalidate selected row, re-render, then show error');
});

test('Candidate remains manual, memory-only and contains no authority-expansion mechanism',()=>{
  assert.doesNotMatch(html,/setInterval\s*\(/);
  assert.doesNotMatch(html,/setTimeout\s*\(\s*refreshFleet/);
  assert.doesNotMatch(html,/localStorage\.setItem\([^)]*fleet/i);
  assert.doesNotMatch(html,/localStorage\.setItem\([^)]*token/i);
  assert.doesNotMatch(html,/\/scan|\/discover|\/command|\/shell|\/files|\/process|\/execute/);
  assert.doesNotMatch(html,/Authorization\s*:\s*['"]Bearer/i);
});

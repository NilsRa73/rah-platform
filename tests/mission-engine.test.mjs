import assert from 'node:assert/strict';
import fs from 'node:fs';

const engine = fs.readFileSync('mission-engine.js', 'utf8');
const html = fs.readFileSync('index.html', 'utf8');
const component = JSON.parse(fs.readFileSync('RAH-RAVEN-MISSION-ENGINE-VERSION.json', 'utf8'));
const master = JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json', 'utf8'));

assert.match(engine, /RAH Mission Engine v1\.6/);
assert.match(engine, /const VERSION = "1\.6\.0"/);
assert.match(engine, /function ensureMissionShape/);
assert.match(engine, /async function startStep/);
assert.match(engine, /function completeStep/);
assert.match(engine, /function finishMission/);
assert.match(engine, /async function executeConfirmedAction/);
assert.match(engine, /window\.rahMission = Object\.freeze/);
assert.match(engine, /explicitExecutionOnly: true/);
assert.match(engine, /executionRequiresConfirmation: true/);
assert.match(engine, /completionRequiresConfirmation: true/);
assert.match(engine, /automaticStepCompletion: false/);
assert.match(engine, /runNextCompletesWaitingStep: false/);
assert.match(engine, /unknownActionsRejected: true/);
assert.match(engine, /automaticStartupWrite: false/);

const startStart = engine.indexOf('async function startStep');
const completeStart = engine.indexOf('function completeStep');
const startBlock = engine.slice(startStart, completeStart);
assert.ok(startStart >= 0 && completeStart > startStart, 'startStep block must exist');
assert.ok(startBlock.indexOf('window.confirm(confirmationText(step))') >= 0, 'step execution must require an explicit confirmation');
assert.ok(startBlock.indexOf('window.confirm(confirmationText(step))') < startBlock.indexOf('executeConfirmedAction(step.action, mission, step)'), 'confirmation must happen before action execution');
assert.match(startBlock, /step\.status = "WAITING"/);
assert.doesNotMatch(startBlock, /completeStep\(index\s*,\s*result\)/);

const runNextStart = engine.indexOf('function runNext');
const issueStart = engine.indexOf('function createIssueForMission');
const runNextBlock = engine.slice(runNextStart, issueStart);
assert.ok(runNextStart >= 0 && issueStart > runNextStart, 'runNext block must exist');
assert.match(runNextBlock, /step\.status === "WAITING"/);
assert.doesNotMatch(runNextBlock, /completeStep\(/);
assert.doesNotMatch(runNextBlock, /finishMission\(/);

const completeBlock = engine.slice(completeStart, engine.indexOf('function reopenStep'));
assert.match(completeBlock, /step\.status !== "WAITING"/);
assert.match(completeBlock, /window\.confirm/);
assert.match(completeBlock, /step\.status = "COMPLETED"/);

assert.match(engine, /Mission action er ikke tillatt/);
assert.doesNotMatch(engine, /return MANUAL_ACTIONS\.has\(action\)[\s\S]*?"Handlingen ble utført\."/);

const startupStart = engine.indexOf('// Restore shape in memory only.');
const cloudListenerStart = engine.indexOf('document.addEventListener("rah:cloud-sync-applied"');
const startupBlock = engine.slice(startupStart, cloudListenerStart);
assert.ok(startupStart >= 0 && cloudListenerStart > startupStart, 'startup boundary must be explicit');
assert.doesNotMatch(startupBlock, /saveState\(|persist\(|startStep\(|completeStep\(|finishMission\(/);

// index.html is frozen. Keep the existing cache query even though the loaded file is v1.6.
assert.match(html, /mission-engine\.js\?v=1\.5/);
assert.match(html, /cloud-sync\.js\?v=1\.0/);
assert.ok(html.indexOf('cloud-sync.js?v=1.0') < html.indexOf('mission-engine.js?v=1.5'), 'cloud sync must load before mission engine');
assert.equal(fs.existsSync('.github/workflows/integrate-mission-engine.yml'), false, 'legacy index-mutating integration workflow must stay retired');

assert.equal(component.product, 'RAH Mission Engine');
assert.equal(component.version, '1.6.0');
assert.equal(component.stage, 'candidate');
assert.equal(component.runtime_feature_change, false);
assert.equal(component.features.explicit_step_execution_only, true);
assert.equal(component.features.execution_requires_confirmation, true);
assert.equal(component.features.completion_requires_confirmation, true);
assert.equal(component.features.automatic_step_completion, false);
assert.equal(component.features.run_next_completes_waiting_step, false);
assert.equal(component.features.waiting_step_requires_explicit_complete, true);
assert.equal(component.features.unknown_actions_rejected, true);
assert.equal(component.features.startup_state_write, false);
assert.equal(component.features.project_sync_requires_confirmation, true);
assert.equal(component.features.clipboard_write_requires_confirmation, true);
assert.equal(component.features.brain_write_requires_confirmation, true);
assert.equal(component.features.automatic_sending, false);
assert.equal(component.features.legacy_index_mutator_retired, true);
assert.equal(component.features.index_hook_frozen, true);
assert.equal(component.features.capability_set_changed, false);
assert.equal(component.next_milestone, 'stable-gate');

const stable = {raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};
assert.deepEqual(master.release_gate.stable_components, stable);
assert.equal(master.privacy.voice_control_stable, true);
assert.equal(master.privacy.project_brain_cloud_sync_stable, true);
assert.equal(master.privacy.case_center_stable, true);
assert.equal(master.privacy.system_health_stable, true);
assert.equal(master.privacy.raven_chronicle_stable, true);

console.log('RAH Mission Engine v1.6 explicit-boundary candidate contract passed.');

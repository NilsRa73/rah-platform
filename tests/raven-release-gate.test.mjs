import assert from "node:assert/strict";
import fs from "node:fs";

const read = p => fs.readFileSync(p,"utf8");
const manifest = JSON.parse(read("RAH-RAVEN-VERSION.json"));
assert.equal(manifest.product,"RAH Raven");
assert.equal(manifest.version,"2.0.32");
assert.equal(manifest.launcher,"3.0");
assert.equal(manifest.release_gate?.stage,"temporary-stable");
assert.equal(manifest.release_gate?.temporary_stable_target,"2.0.32");
assert.equal(manifest.release_gate?.runtime_feature_change,false);
assert.equal(manifest.release_gate?.frozen_from,"2.0.31");
assert.equal(manifest.release_gate?.development_paused,true);
assert.equal(manifest.release_gate?.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(manifest.release_gate?.bugfix_component_updates?.raven_vision,"0.6");
assert.equal(manifest.release_gate?.bugfix_component_updates?.raven_council,"0.3");
assert.equal(manifest.release_gate?.bugfix_component_updates?.agent_runner,"0.3");
assert.equal(manifest.release_gate?.bugfix_component_updates?.memory_sync,"0.2");
assert.equal(manifest.release_gate?.bugfix_component_updates?.mission_control,"2.9");
assert.equal(manifest.release_gate?.bugfix_component_updates?.project_focus,"2.4");

const expected = {
  raven_now:["RAH-RAVEN-NOW-V2.html","RAH Raven Now v2.17","2.17"],
  raven_studio:["RAH-RAVEN-START.html","RAH Raven Studio v2.8","2.8"],
  raven_core:["RAH-RAVEN-CORE-DEMO.html","RAH Raven Core Workflow v1.12","1.12"],
  raven_vision:["RAH-RAVEN-VISION-CORE.html","RAH Raven Vision Core v0.6","0.6"],
  mission_control:["RAH-RAVEN-MISSION-CONTROL.html","RAH Raven Mission Control v2.9","2.9"],
  project_focus:["RAH-RAVEN-PROJECT.html","RAH Raven Project Focus v2.4","2.4"],
  raven_council:["RAH-RAVEN-COUNCIL.html","RAH Raven Council v0.3","0.3"],
  agent_runner:["RAH-RAVEN-AGENT-RUNNER.html","RAH Raven Agent Runner v0.3","0.3"],
  memory_sync:["RAH-RAVEN-MEMORY-SYNC.html","RAH Raven Memory Sync v0.2","0.2"]
};
for(const [key,[file,marker,version]] of Object.entries(expected)){
  assert.equal(manifest.release_gate.component_versions[key],version,`${key} version pin`);
  assert.ok(manifest.files.includes(file),`${file} must be in package manifest`);
  assert.match(read(file),new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g,"\\$&")),`${file} identity`);
}

for(const file of manifest.files) assert.ok(fs.existsSync(file),`Missing manifest file: ${file}`);
const privacy=manifest.privacy;
for(const key of ["keylogging","clipboard_capture","hidden_microphone","hidden_camera","automatic_sending","hidden_screen_capture"])
  assert.equal(privacy[key],false,`${key} must stay false`);
for(const key of [
  "vision_local_bridge_only",
  "vision_helper_version_synced",
  "council_local_bridge_only",
  "council_helper_version_synced",
  "agent_runner_local_bridge_only",
  "agent_runner_version_synced",
  "raven_core_continue_navigation_only",
  "raven_core_continue_no_storage_writes",
  "vision_chatgpt_mode_no_auto_send",
  "chatgpt_handoff_history_shared_policy_read_only",
  "chatgpt_handoff_receipt_shared_policy_read_only"
]) assert.equal(privacy[key],true,`${key} must stay true`);

assert.equal(privacy.vision_external_bridge_addresses_allowed,false,"Vision external Bridge addresses must stay blocked");
assert.equal(privacy.council_external_bridge_addresses_allowed,false,"Council external Bridge addresses must stay blocked");
assert.equal(privacy.agent_runner_external_bridge_addresses_allowed,false,"Agent Runner external Bridge addresses must stay blocked");
assert.equal(privacy.memory_sync_external_bridge_addresses_allowed,false,"Memory Sync external Bridge addresses must stay blocked");
assert.equal(privacy.memory_sync_local_bridge_only,true,"Memory Sync Bridge must stay loopback-only");
assert.equal(privacy.memory_sync_explicit_write_only,true,"Memory Sync Chronicle writes must remain explicit");
assert.equal(privacy.memory_sync_metadata_only,true,"Memory Sync must remain metadata-only");
assert.equal(privacy.memory_sync_automatic_sync,false,"Memory Sync automatic sync must stay disabled");
assert.equal(privacy.memory_sync_stable,true,"Memory Sync v0.2 stable marker must stay true");
assert.equal(privacy.mission_control_local_bridge_only,true,"Mission Control Bridge must stay loopback-only");
assert.equal(privacy.mission_control_external_bridge_addresses_allowed,false,"Mission Control external Bridge addresses must stay blocked");
assert.equal(privacy.mission_control_chronicle_context_read_only,true,"Mission Control Chronicle context must remain read-only");
assert.equal(privacy.mission_control_automatic_step_completion,false,"Mission Control must not auto-complete steps");
assert.equal(privacy.mission_control_stable,true,"Mission Control v2.9 stable marker must stay true");
assert.equal(privacy.project_focus_explicit_activation_only,true,"Project Focus activation must remain explicit");
assert.equal(privacy.project_focus_stale_selection_guard,true,"Project Focus must revalidate the selected project before write");
assert.equal(privacy.project_focus_active_mission_write,false,"Project Focus must not write activeMission");
assert.equal(privacy.project_focus_mission_step_completion,false,"Project Focus must not complete mission steps");
assert.equal(privacy.project_focus_agent_execution,false,"Project Focus must not execute Agent Runner");
assert.equal(privacy.project_focus_network_requests,false,"Project Focus must remain network-free");
assert.equal(privacy.project_focus_stable,true,"Project Focus v2.4 stable marker must stay true");
assert.equal(privacy.raven_core_local_bridge_only,true,"Raven Core Bridge status requests must be loopback-only");
assert.equal(privacy.raven_core_external_bridge_addresses_allowed,false,"Raven Core external Bridge addresses must stay blocked");
assert.equal(privacy.raven_core_dependency_versions_synced,true,"Raven Core dependency cache keys must match stable helper versions");
assert.equal(privacy.raven_core_support_snapshot_version_synced,true,"Raven Core support snapshot must report Raven 2.0.32");
assert.equal(privacy.raven_core_report_version_synced,true,"Raven Core report must report v1.12");
assert.equal(privacy.raven_core_stable,false,"Raven Core v1.12 remains candidate until stable gate passes");
assert.equal(privacy.agent_runner_stable,true,"Agent Runner v0.3 stable marker must stay true");
assert.ok(manifest.files.includes("RAH-RAVEN-CORE-VERSION.json"),"Raven Core component manifest must ship in Raven package");
const coreManifest=JSON.parse(read("RAH-RAVEN-CORE-VERSION.json"));
assert.equal(coreManifest.version,"1.12.0");
assert.equal(coreManifest.stage,"candidate");
assert.equal(coreManifest.runtime_feature_change,false);
assert.equal(coreManifest.dependency_versions.raven_vision_core,"0.6.0");
assert.equal(coreManifest.dependency_versions.raven_council,"0.3.0");
assert.equal(coreManifest.dependency_versions.raven_chronicle_sync,"0.1.0");
assert.equal(coreManifest.features.local_bridge_only,true);
assert.equal(coreManifest.features.external_bridge_addresses_allowed,false);
assert.equal(coreManifest.features.bridge_credentials_allowed,false);
assert.equal(coreManifest.features.bridge_query_allowed,false);
assert.equal(coreManifest.features.bridge_hash_allowed,false);
assert.equal(coreManifest.features.bridge_non_root_path_allowed,false);
assert.equal(coreManifest.features.dependency_cache_keys_synced,true);
assert.equal(coreManifest.features.context_snapshot_read_only,true);
assert.equal(coreManifest.features.continue_navigation_only,true);
assert.equal(coreManifest.features.agent_execution,false);
assert.equal(coreManifest.features.automatic_memory_sync,false);
assert.equal(coreManifest.features.shared_checkpoint_policy_runtime_changed,false);
assert.equal(coreManifest.features.capability_set_changed,false);
assert.equal(coreManifest.next_milestone,"stable-gate");

assert.ok(manifest.files.includes("RAH-RAVEN-VISION-VERSION.json"),"Vision component manifest must ship in Raven package");
const visionManifest=JSON.parse(read("RAH-RAVEN-VISION-VERSION.json"));
assert.equal(visionManifest.version,"0.6.0");
assert.equal(visionManifest.stage,"stable");
assert.equal(visionManifest.runtime_feature_change,false);
assert.equal(visionManifest.development_paused,true);
assert.equal(visionManifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(visionManifest.stable_release_gate?.status,"passed");
assert.equal(visionManifest.stable_release_gate?.runtime_files_frozen,true);
assert.equal(visionManifest.features.local_bridge_only,true);
assert.equal(visionManifest.features.external_bridge_addresses_allowed,false);

assert.ok(manifest.files.includes("RAH-RAVEN-COUNCIL-VERSION.json"),"Council component manifest must ship in Raven package");
assert.equal(privacy.council_stable,true,"Council stable marker must stay true");
assert.equal(manifest.release_gate?.stable_components?.raven_vision,"0.6");
assert.equal(manifest.release_gate?.stable_components?.raven_council,"0.3");
assert.equal(manifest.release_gate?.stable_components?.agent_runner,"0.3");
assert.equal(manifest.release_gate?.stable_components?.memory_sync,"0.2");
assert.equal(manifest.release_gate?.stable_components?.mission_control,"2.9");
assert.equal(manifest.release_gate?.stable_components?.project_focus,"2.4");
const councilManifest=JSON.parse(read("RAH-RAVEN-COUNCIL-VERSION.json"));
assert.equal(councilManifest.version,"0.3.0");
assert.equal(councilManifest.stage,"stable");
assert.equal(councilManifest.runtime_feature_change,false);
assert.equal(councilManifest.development_paused,true);
assert.equal(councilManifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(councilManifest.features.local_bridge_only,true);
assert.equal(councilManifest.features.external_bridge_addresses_allowed,false);
assert.equal(councilManifest.features.bridge_tools_executed,false);
assert.equal(councilManifest.features.bridge_automatic_actions,false);
assert.equal(councilManifest.features.project_brain_write_requires_explicit_click,true);
assert.equal(councilManifest.features.mission_handoff_requires_explicit_click,true);
assert.equal(councilManifest.stable_release_gate?.status,"passed");
assert.equal(councilManifest.stable_release_gate?.runtime_files_frozen,true);

assert.ok(manifest.files.includes("RAH-RAVEN-AGENT-RUNNER-VERSION.json"),"Agent Runner component manifest must ship in Raven package");
const agentManifest=JSON.parse(read("RAH-RAVEN-AGENT-RUNNER-VERSION.json"));
assert.equal(agentManifest.version,"0.3.0");
assert.equal(agentManifest.stage,"stable");
assert.equal(agentManifest.development_paused,true);
assert.equal(agentManifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(agentManifest.runtime_feature_change,false);
assert.equal(agentManifest.features.local_bridge_only,true);
assert.equal(agentManifest.features.external_bridge_addresses_allowed,false);
assert.equal(agentManifest.features.backend_version_synced,true);
assert.equal(agentManifest.features.mode,"read-only-allowlist");
assert.equal(agentManifest.features.arbitrary_commands,false);
assert.equal(agentManifest.features.file_writes,false);
assert.equal(agentManifest.features.automatic_execution,false);
assert.equal(agentManifest.features.capability_set_changed,false);
assert.equal(agentManifest.stable_release_gate?.status,"passed");
assert.equal(agentManifest.stable_release_gate?.runtime_files_frozen,true);
assert.equal(agentManifest.next_milestone,null);

assert.ok(manifest.files.includes("RAH-RAVEN-MISSION-CONTROL-VERSION.json"),"Mission Control component manifest must ship in Raven package");
const missionManifest=JSON.parse(read("RAH-RAVEN-MISSION-CONTROL-VERSION.json"));
assert.equal(missionManifest.version,"2.9.0");
assert.equal(missionManifest.stage,"stable");
assert.equal(missionManifest.development_paused,true);
assert.equal(missionManifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(missionManifest.runtime_feature_change,false);
assert.equal(missionManifest.features.local_bridge_only,true);
assert.equal(missionManifest.features.external_bridge_addresses_allowed,false);
assert.equal(missionManifest.features.chronicle_context_read_only,true);
assert.equal(missionManifest.features.mission_completion_requires_explicit_confirmation,true);
assert.equal(missionManifest.features.automatic_step_completion,false);
assert.equal(missionManifest.features.council_context_only,true);
assert.equal(missionManifest.features.agent_context_only,true);
assert.equal(missionManifest.features.chronicle_context_only,true);
assert.equal(missionManifest.features.recommended_checkpoint_navigation_read_only,true);
assert.equal(missionManifest.features.project_mission_relation_read_only,true);
assert.equal(missionManifest.features.shared_checkpoint_policy_runtime_changed,false);
assert.equal(missionManifest.features.capability_set_changed,false);
assert.equal(missionManifest.stable_release_gate?.status,"passed");
assert.equal(missionManifest.stable_release_gate?.runtime_files_frozen,true);
assert.equal(missionManifest.next_milestone,null);

assert.ok(manifest.files.includes("RAH-RAVEN-PROJECT-FOCUS-VERSION.json"),"Project Focus component manifest must ship in Raven package");
const projectFocusManifest=JSON.parse(read("RAH-RAVEN-PROJECT-FOCUS-VERSION.json"));
assert.equal(projectFocusManifest.version,"2.4.0");
assert.equal(projectFocusManifest.stage,"stable");
assert.equal(projectFocusManifest.development_paused,true);
assert.equal(projectFocusManifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(projectFocusManifest.runtime_feature_change,false);
assert.equal(projectFocusManifest.features.explicit_project_activation,true);
assert.equal(projectFocusManifest.features.active_project_write_requires_explicit_confirmation,true);
assert.equal(projectFocusManifest.features.stale_selection_guard,true);
assert.equal(projectFocusManifest.features.project_identity_revalidated_before_write,true);
assert.equal(projectFocusManifest.features.active_mission_write,false);
assert.equal(projectFocusManifest.features.mission_step_completion,false);
assert.equal(projectFocusManifest.features.agent_execution,false);
assert.equal(projectFocusManifest.features.network_requests,false);
assert.equal(projectFocusManifest.features.reconciliation_navigation_only,true);
assert.equal(projectFocusManifest.features.shared_checkpoint_policy_runtime_changed,false);
assert.equal(projectFocusManifest.features.capability_set_changed,false);
assert.equal(projectFocusManifest.stable_release_gate?.status,"passed");
assert.equal(projectFocusManifest.stable_release_gate?.runtime_files_frozen,true);
assert.equal(projectFocusManifest.next_milestone,null);

assert.ok(manifest.files.includes("RAH-RAVEN-MEMORY-SYNC-VERSION.json"),"Memory Sync component manifest must ship in Raven package");
const memoryManifest=JSON.parse(read("RAH-RAVEN-MEMORY-SYNC-VERSION.json"));
assert.equal(memoryManifest.version,"0.2.0");
assert.equal(memoryManifest.stage,"stable");
assert.equal(memoryManifest.development_paused,true);
assert.equal(memoryManifest.change_policy,"bugfix-only-until-explicit-reopen");
assert.equal(memoryManifest.runtime_feature_change,false);
assert.equal(memoryManifest.features.local_bridge_only,true);
assert.equal(memoryManifest.features.external_bridge_addresses_allowed,false);
assert.equal(memoryManifest.features.chronicle_write_requires_explicit_confirmation,true);
assert.equal(memoryManifest.features.general_background_permission,false);
assert.equal(memoryManifest.features.automatic_sync,false);
assert.equal(memoryManifest.features.metadata_only,true);
assert.equal(memoryManifest.features.images_included,false);
assert.equal(memoryManifest.features.prompts_included,false);
assert.equal(memoryManifest.features.model_answers_included,false);
assert.equal(memoryManifest.features.document_text_included,false);
assert.equal(memoryManifest.features.command_output_included,false);
assert.equal(memoryManifest.features.error_logs_included,false);
assert.equal(memoryManifest.features.sync_core_runtime_changed,false);
assert.equal(memoryManifest.stable_release_gate?.status,"passed");
assert.equal(memoryManifest.stable_release_gate?.runtime_files_frozen,true);
assert.equal(memoryManifest.next_milestone,null);

const now=read("RAH-RAVEN-NOW-V2.html");
assert.match(now,/id="continueButton"/);
assert.match(now,/raven-checkpoint-policy\.js/);
const core=read("RAH-RAVEN-CORE-DEMO.html");
assert.match(core,/id="coreContinue"/);
assert.match(core,/id="copyCoreStatus"/);
assert.match(core,/KOPIER STATUS/);
assert.match(core,/STATUS TXT/);
const receipt=read("raven-handoff-receipt.js");
assert.doesNotMatch(receipt,/localStorage|sessionStorage|fetch\(|XMLHttpRequest|writeState\(|location\s*=|window\.open/);

console.log("RAH Raven 2.0.32 Temporary Stable Gate: six stable core components; Raven Core v1.12 candidate local Bridge boundary OK.");

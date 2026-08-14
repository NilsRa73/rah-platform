from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def read_json(path: str) -> dict:
    return json.loads(read(path))


def write_json(path: str, data: dict) -> None:
    write(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"{label} anchor missing")
    return text.replace(old, new, 1)


# Runtime bugfix only: explicit activation must still target the project the user saw.
html_path = "RAH-RAVEN-PROJECT.html"
html = read(html_path)
assert "RAH Raven Project Focus v2.4" in html
assert "fetch(" not in html and "XMLHttpRequest" not in html and "WebSocket" not in html

save_anchor = "  const saveState=s=>localStorage.setItem(STATE_KEY,JSON.stringify(s));\n"
identity = """  const projectToken=value=>{\n    if(!value||typeof value!=='object')return '';\n    const id=String(value.id||'').trim();\n    if(id)return `id:${id}`;\n    return `snapshot:${JSON.stringify(value)}`;\n  };\n"""
html = replace_once(html, save_anchor, save_anchor + identity, "project identity helper")

project_anchor = "  const p=valid?projects[index]:null;\n"
html = replace_once(html, project_anchor, project_anchor + "  const selectedProjectToken=projectToken(p);\n", "selected project token")

click_anchor = "    if(index<0||index>=s.projects.length)return alert('Prosjektlisten har endret seg. Gå tilbake til Raven Now og åpne prosjektet på nytt.');\n"
guard = """    const liveProject=s.projects[index];\n    if(projectToken(liveProject)!==selectedProjectToken)return alert('Prosjektet har endret seg siden du åpnet Project Focus. Åpne prosjektet på nytt og bekreft igjen.');\n"""
html = replace_once(html, click_anchor, click_anchor + guard, "stale selection guard")

notice_old = "Project Focus kan bare endre `activeProject` etter eksplisitt bekreftelse. «Vis missionens prosjekt» er bare navigasjon. Den erstatter ikke aktiv mission, endrer ikke mission-steg og markerer aldri noe ferdig."
notice_new = "Project Focus kan bare endre `activeProject` etter eksplisitt bekreftelse, og prosjektet verifiseres på nytt rett før write. «Vis missionens prosjekt» er bare navigasjon. Den erstatter ikke aktiv mission, endrer ikke mission-steg og markerer aldri noe ferdig."
html = replace_once(html, notice_old, notice_new, "control boundary notice")
write(html_path, html)

# Candidate component manifest. Version stays 2.4 because this is a bugfix-only boundary hardening.
project_manifest = {
    "product": "RAH Raven Project Focus",
    "version": "2.4.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "RAH-RAVEN-PROJECT.html",
    "shared_checkpoint_policy": "raven-checkpoint-policy.js",
    "local_only": True,
    "runtime_feature_change": False,
    "features": {
        "explicit_project_activation": True,
        "active_project_write_requires_explicit_confirmation": True,
        "stale_selection_guard": True,
        "project_identity_revalidated_before_write": True,
        "active_mission_write": False,
        "mission_step_completion": False,
        "agent_execution": False,
        "network_requests": False,
        "reconciliation_navigation_only": True,
        "shared_checkpoint_policy_runtime_changed": False,
        "capability_set_changed": False,
    },
    "next_milestone": "stable-gate",
}
write_json("RAH-RAVEN-PROJECT-FOCUS-VERSION.json", project_manifest)

# Master Raven remains 2.0.32 temporary stable; existing five stable modules stay untouched.
manifest = read_json("RAH-RAVEN-VERSION.json")
assert manifest["version"] == "2.0.32"
assert manifest["release_gate"]["component_versions"]["project_focus"] == "2.4"
assert manifest["release_gate"]["stable_components"] == {
    "raven_vision": "0.6",
    "raven_council": "0.3",
    "agent_runner": "0.3",
    "memory_sync": "0.2",
    "mission_control": "2.9",
}
files = manifest["files"]
version_file = "RAH-RAVEN-PROJECT-FOCUS-VERSION.json"
if version_file not in files:
    insert_at = files.index("RAH-RAVEN-PROJECT.html") + 1
    files.insert(insert_at, version_file)
privacy = manifest["privacy"]
privacy["project_focus_explicit_activation_only"] = True
privacy["project_focus_stale_selection_guard"] = True
privacy["project_focus_active_mission_write"] = False
privacy["project_focus_mission_step_completion"] = False
privacy["project_focus_agent_execution"] = False
privacy["project_focus_network_requests"] = False
privacy["project_focus_stable"] = False
write_json("RAH-RAVEN-VERSION.json", manifest)

# Dedicated Project Focus regression test.
test_path = "tests/raven-project-focus.test.mjs"
test = read(test_path)
anchor = "assert.match(html,/s\\.activeProject=index/);\n"
insert = r'''assert.match(html,/const projectToken=value=>/);
assert.match(html,/const selectedProjectToken=projectToken\(p\)/);
assert.match(html,/const liveProject=s\.projects\[index\]/);
assert.match(html,/projectToken\(liveProject\)!==selectedProjectToken/);
assert.match(html,/Prosjektet har endret seg siden du åpnet Project Focus/);
const guardPos=html.indexOf('projectToken(liveProject)!==selectedProjectToken');
const writePos=html.indexOf('s.activeProject=index');
assert.ok(guardPos>=0&&writePos>guardPos,'stale selection guard must run before activeProject write');
assert.doesNotMatch(html,/fetch\s*\(/);
assert.doesNotMatch(html,/XMLHttpRequest|WebSocket/);
'''
test = replace_once(test, anchor, insert + anchor, "Project Focus stale guard test")
test = test.replace(
    "Raven Project Focus v2.4 shared project-mission relation and explicit activation passed.",
    "Raven Project Focus v2.4 explicit activation + stale selection guard passed.",
)
write(test_path, test)

# Aggregate release test recognizes the candidate without promoting it to stable.
release_path = "tests/raven-release-gate.test.mjs"
release = read(release_path)
privacy_anchor = 'assert.equal(privacy.mission_control_stable,true,"Mission Control v2.9 stable marker must stay true");'
privacy_insert = '''assert.equal(privacy.project_focus_explicit_activation_only,true,"Project Focus activation must remain explicit");
assert.equal(privacy.project_focus_stale_selection_guard,true,"Project Focus must revalidate the selected project before write");
assert.equal(privacy.project_focus_active_mission_write,false,"Project Focus must not write activeMission");
assert.equal(privacy.project_focus_mission_step_completion,false,"Project Focus must not complete mission steps");
assert.equal(privacy.project_focus_agent_execution,false,"Project Focus must not execute Agent Runner");
assert.equal(privacy.project_focus_network_requests,false,"Project Focus must remain network-free");
assert.equal(privacy.project_focus_stable,false,"Project Focus v2.4 remains candidate until stable gate passes");'''
release = replace_once(release, privacy_anchor, privacy_anchor + "\n" + privacy_insert, "release project privacy")

manifest_anchor = 'assert.ok(manifest.files.includes("RAH-RAVEN-MEMORY-SYNC-VERSION.json"),"Memory Sync component manifest must ship in Raven package");'
project_block = '''assert.ok(manifest.files.includes("RAH-RAVEN-PROJECT-FOCUS-VERSION.json"),"Project Focus component manifest must ship in Raven package");
const projectFocusManifest=JSON.parse(read("RAH-RAVEN-PROJECT-FOCUS-VERSION.json"));
assert.equal(projectFocusManifest.version,"2.4.0");
assert.equal(projectFocusManifest.stage,"candidate");
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
assert.equal(projectFocusManifest.next_milestone,"stable-gate");

'''
release = replace_once(release, manifest_anchor, project_block + manifest_anchor, "release project manifest")
release = release.replace(
    "RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 + Agent Runner v0.3 + Memory Sync v0.2 + Mission Control v2.9 stable boundaries OK.",
    "RAH Raven 2.0.32 Temporary Stable Gate: five stable core components; Project Focus v2.4 candidate stale-selection boundary OK.",
)
write(release_path, release)

print("Project Focus v2.4 candidate built: stale selection guard only; five stable components untouched.")

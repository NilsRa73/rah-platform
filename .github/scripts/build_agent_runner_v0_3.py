from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_required(path: str, old: str, new: str, count: int = 1) -> None:
    text = read(path)
    if old not in text:
        raise SystemExit(f"Required marker not found in {path}: {old[:100]!r}")
    write(path, text.replace(old, new, count))


# 1) Agent Runner UI identity + explicit loopback-only Bridge boundary.
html_path = "RAH-RAVEN-AGENT-RUNNER.html"
replace_required(html_path, "<title>RAH Raven Agent Runner v0.2</title>", "<title>RAH Raven Agent Runner v0.3</title>")
replace_required(html_path, "<span class=\"badge\">v0.2 · READ ONLY</span>", "<span class=\"badge\">v0.3 · READ ONLY</span>")
replace_required(
    html_path,
    '<div class="field"><label>Bridge-adresse</label><input id="bridgeBase" value="http://127.0.0.1:18765"></div>',
    '<div class="field"><label>Bridge-adresse</label><input id="bridgeBase" value="http://127.0.0.1:18765"><small style="color:var(--muted)">Kun lokal loopback er tillatt: 127.0.0.1, localhost eller ::1. Eksterne adresser blokkeres før nettverkskall.</small></div>',
)
replace_required(
    html_path,
    'const rahState=()=>readJson(STATE_KEY,{}),base=()=>String($("bridgeBase").value||"http://127.0.0.1:18765").replace(/\\/+$/,"");',
    '''const DEFAULT_BRIDGE_BASE="http://127.0.0.1:18765";
  function normalizeBridgeBase(value=DEFAULT_BRIDGE_BASE){let url;try{url=new URL(String(value||DEFAULT_BRIDGE_BASE))}catch{throw new Error("Agent Runner Bridge må bruke en lokal loopback-adresse.")}const host=String(url.hostname||"").toLowerCase();if(!["127.0.0.1","localhost","::1","[::1]"].includes(host))throw new Error("Agent Runner Bridge må bruke en lokal loopback-adresse.");if(!["http:","https:"].includes(url.protocol))throw new Error("Agent Runner Bridge må bruke HTTP på lokal loopback.");if(url.username||url.password||url.search||url.hash||!["","/"].includes(url.pathname))throw new Error("Agent Runner Bridge-adressen kan ikke inneholde sti, innlogging, søk eller fragment.");return `${url.protocol}//${url.host}`}
  const rahState=()=>readJson(STATE_KEY,{}),base=()=>normalizeBridgeBase($("bridgeBase").value||DEFAULT_BRIDGE_BASE);''',
)
replace_required(
    html_path,
    "Agent Runner v0.2 er begrenset til allowlistet lesing og tester.",
    "Agent Runner v0.3 er begrenset til allowlistet lesing og tester.",
)

# 2) Backend contract/version sync only; capabilities remain unchanged.
runner_path = "desktop-bridge/agent_runner.py"
replace_required(runner_path, '"""RAH Raven Agent Runner v0.1.', '"""RAH Raven Agent Runner v0.3.0.')
replace_required(runner_path, 'AGENT_RUNNER_VERSION = "0.1.1"', 'AGENT_RUNNER_VERSION = "0.3.0"')

# 3) Component manifest: candidate safety patch, not stable yet.
agent_manifest = {
    "product": "RAH Raven Agent Runner",
    "version": "0.3.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "RAH-RAVEN-AGENT-RUNNER.html",
    "backend": "desktop-bridge/agent_runner.py",
    "backend_version": "0.3.0",
    "local_only": True,
    "runtime_feature_change": False,
    "development_paused": False,
    "change_policy": "boundary-and-contract-sync-only-until-stable-gate",
    "features": {
        "local_bridge_only": True,
        "loopback_hosts": ["127.0.0.1", "localhost", "::1"],
        "external_bridge_addresses_allowed": False,
        "backend_version_synced": True,
        "mode": "read-only-allowlist",
        "arbitrary_commands": False,
        "file_writes": False,
        "automatic_execution": False,
        "each_run_requires_explicit_confirmation": True,
        "mission_step_completion_requires_separate_confirmation": True,
        "capability_set_changed": False,
    },
    "stable_release_gate": {
        "status": "pending",
        "runtime_files_frozen": False,
    },
    "next_milestone": "stable-gate",
}
write("RAH-RAVEN-AGENT-RUNNER-VERSION.json", json.dumps(agent_manifest, ensure_ascii=False, indent=2) + "\n")

# 4) Raven 2.0.32 remains frozen; register Agent Runner v0.3 as a bugfix component update.
manifest_path = ROOT / "RAH-RAVEN-VERSION.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["summary"] = (
    "RAH Raven 2.0.32 remains the temporary stable freeze. Vision Core v0.6 and Council v0.3 remain stable local-only components. "
    "Agent Runner v0.3 is a no-feature safety candidate that adds a loopback-only Bridge boundary and synchronizes its UI/backend contract."
)
files = manifest.setdefault("files", [])
agent_manifest_name = "RAH-RAVEN-AGENT-RUNNER-VERSION.json"
if agent_manifest_name not in files:
    insert_at = files.index("RAH-RAVEN-AGENT-RUNNER.html") + 1 if "RAH-RAVEN-AGENT-RUNNER.html" in files else len(files)
    files.insert(insert_at, agent_manifest_name)
privacy = manifest.setdefault("privacy", {})
privacy["agent_runner_local_bridge_only"] = True
privacy["agent_runner_external_bridge_addresses_allowed"] = False
privacy["agent_runner_version_synced"] = True
privacy["agent_runner_stable"] = False
release = manifest.setdefault("release_gate", {})
release.setdefault("component_versions", {})["agent_runner"] = "0.3"
release.setdefault("bugfix_component_updates", {})["agent_runner"] = "0.3"
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# 5) Agent Runner validation.
test_path = "tests/raven-agent-runner.test.mjs"
test = read(test_path)
test = test.replace('/Raven Agent Runner v0\\.2/', '/Raven Agent Runner v0\\.3/')
test = test.replace('/AGENT_RUNNER_VERSION = "0\\.1\\.1"/', '/AGENT_RUNNER_VERSION = "0\\.3\\.0"/')
test = test.replace(
    'assert.match(page, /http:\\\/\\\\/127\\.0\\.0\\.1:18765/);',
    'assert.match(page, /http:\\\/\\\\/127\\.0\\.0\\.1:18765/);\nassert.match(page, /function normalizeBridgeBase/);\nassert.match(page, /127\\.0\\.0\\.1.*localhost.*::1/);\nassert.match(page, /må bruke en lokal loopback-adresse/);\nassert.match(page, /external|Eksterne adresser blokkeres/i);\nassert.doesNotMatch(page, /base=\\(\\)=>String\\(\\$\\("bridgeBase"\\)/);',
)
test = test.replace(
    "console.log('Raven Agent Runner v0.2 UI / runner v0.1.1 validation passed.');",
    "console.log('Raven Agent Runner v0.3 UI / runner v0.3.0 local-boundary validation passed.');",
)
write(test_path, test)

# 6) Aggregate Raven gate knows the candidate component without declaring it stable.
release_test_path = "tests/raven-release-gate.test.mjs"
release_test = read(release_test_path)
release_test = release_test.replace(
    'assert.equal(manifest.release_gate?.bugfix_component_updates?.raven_council,"0.3");',
    'assert.equal(manifest.release_gate?.bugfix_component_updates?.raven_council,"0.3");\nassert.equal(manifest.release_gate?.bugfix_component_updates?.agent_runner,"0.3");',
)
release_test = release_test.replace(
    'agent_runner:["RAH-RAVEN-AGENT-RUNNER.html","RAH Raven Agent Runner v0.2","0.2"],',
    'agent_runner:["RAH-RAVEN-AGENT-RUNNER.html","RAH Raven Agent Runner v0.3","0.3"],',
)
release_test = release_test.replace(
    '  "council_helper_version_synced",',
    '  "council_helper_version_synced",\n  "agent_runner_local_bridge_only",\n  "agent_runner_version_synced",',
)
release_test = release_test.replace(
    'assert.equal(privacy.council_external_bridge_addresses_allowed,false,"Council external Bridge addresses must stay blocked");',
    'assert.equal(privacy.council_external_bridge_addresses_allowed,false,"Council external Bridge addresses must stay blocked");\nassert.equal(privacy.agent_runner_external_bridge_addresses_allowed,false,"Agent Runner external Bridge addresses must stay blocked");\nassert.equal(privacy.agent_runner_stable,false,"Agent Runner v0.3 remains candidate until its stable gate passes");',
)
anchor = 'assert.equal(councilManifest.stable_release_gate?.runtime_files_frozen,true);\n'
agent_checks = '''\nassert.ok(manifest.files.includes("RAH-RAVEN-AGENT-RUNNER-VERSION.json"),"Agent Runner component manifest must ship in Raven package");
const agentManifest=JSON.parse(read("RAH-RAVEN-AGENT-RUNNER-VERSION.json"));
assert.equal(agentManifest.version,"0.3.0");
assert.equal(agentManifest.stage,"candidate");
assert.equal(agentManifest.runtime_feature_change,false);
assert.equal(agentManifest.features.local_bridge_only,true);
assert.equal(agentManifest.features.external_bridge_addresses_allowed,false);
assert.equal(agentManifest.features.backend_version_synced,true);
assert.equal(agentManifest.features.mode,"read-only-allowlist");
assert.equal(agentManifest.features.arbitrary_commands,false);
assert.equal(agentManifest.features.file_writes,false);
assert.equal(agentManifest.features.automatic_execution,false);
assert.equal(agentManifest.features.capability_set_changed,false);
'''
if anchor not in release_test:
    raise SystemExit("Council stable gate anchor not found in release test")
release_test = release_test.replace(anchor, anchor + agent_checks, 1)
release_test = release_test.replace(
    'console.log("RAH Raven 2.0.32 Temporary Stable Gate: component identity, stable Vision v0.6 + Council v0.3 and safety boundaries OK.");',
    'console.log("RAH Raven 2.0.32 Temporary Stable Gate: Vision v0.6 + Council v0.3 stable; Agent Runner v0.3 candidate boundary OK.");',
)
write(release_test_path, release_test)

# 7) Keep package/release/one-click workflows aligned with the manifest.
for workflow in [
    ".github/workflows/validate-raven-release-gate.yml",
    ".github/workflows/validate-raven-one-click.yml",
    ".github/workflows/validate-raven-package.yml",
]:
    p = ROOT / workflow
    text = p.read_text(encoding="utf-8")
    if "RAH-RAVEN-AGENT-RUNNER-VERSION.json" not in text:
        if "RAH-RAVEN-COUNCIL-VERSION.json" in text:
            text = text.replace(
                "RAH-RAVEN-COUNCIL-VERSION.json'",
                "RAH-RAVEN-COUNCIL-VERSION.json'\n      - 'RAH-RAVEN-AGENT-RUNNER-VERSION.json'",
            ) if "'RAH-RAVEN-COUNCIL-VERSION.json'" in text else text.replace(
                'RAH-RAVEN-COUNCIL-VERSION.json"',
                'RAH-RAVEN-COUNCIL-VERSION.json"\n      - "RAH-RAVEN-AGENT-RUNNER-VERSION.json"',
            )
    text = text.replace("'agent_runner':'0.2'", "'agent_runner':'0.3'")
    text = text.replace(
        "assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3'}",
        "assert m['release_gate']['bugfix_component_updates']=={'raven_vision':'0.6','raven_council':'0.3','agent_runner':'0.3'}",
    )
    text = text.replace(
        "assert gate['bugfix_component_updates']['raven_council']=='0.3'",
        "assert gate['bugfix_component_updates']['raven_council']=='0.3'\n          assert gate['bugfix_component_updates']['agent_runner']=='0.3'",
    )
    text = text.replace(
        "assert gate['component_versions']['raven_council']=='0.3'",
        "assert gate['component_versions']['raven_council']=='0.3'\n          assert gate['component_versions']['agent_runner']=='0.3'",
    )
    text = text.replace(
        "'council_external_bridge_addresses_allowed'",
        "'council_external_bridge_addresses_allowed','agent_runner_external_bridge_addresses_allowed'",
    )
    text = text.replace(
        "'council_local_bridge_only','council_helper_version_synced','council_stable',",
        "'council_local_bridge_only','council_helper_version_synced','council_stable','agent_runner_local_bridge_only','agent_runner_version_synced',",
    )
    text = text.replace(
        "assert privacy['council_helper_version_synced'] is True",
        "assert privacy['council_helper_version_synced'] is True\n          assert privacy['agent_runner_local_bridge_only'] is True\n          assert privacy['agent_runner_version_synced'] is True\n          assert privacy['agent_runner_external_bridge_addresses_allowed'] is False",
    )
    text = text.replace(
        "'RAH-RAVEN-VISION-VERSION.json','RAH-RAVEN-COUNCIL-VERSION.json')",
        "'RAH-RAVEN-VISION-VERSION.json','RAH-RAVEN-COUNCIL-VERSION.json','RAH-RAVEN-AGENT-RUNNER-VERSION.json')",
    )
    p.write_text(text, encoding="utf-8")

print("Agent Runner v0.3 local Bridge boundary + contract sync built.")

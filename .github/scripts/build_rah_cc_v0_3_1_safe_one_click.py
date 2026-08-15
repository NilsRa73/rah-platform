from __future__ import annotations

import json
import subprocess
from pathlib import Path

BASE_SHA = "c347ad8d6604743e3eab6ac46a3c0740fda36b7b"
ROOT = Path(__file__).resolve().parents[2]

HTML = ROOT / "RAH-COMMAND-CENTER-V0.3.html"
CORE = ROOT / "rah-command-center-core.js"
MANIFEST = ROOT / "RAH-COMMAND-CENTER-VERSION.json"
CORE_TEST = ROOT / "tests/rah-command-center-core.test.mjs"
INTEGRATION_TEST = ROOT / "tests/rah-command-center-v03.test.mjs"
PACKAGING_TEST = ROOT / "tests/rah-command-center-packaging.test.mjs"
LAUNCHER = ROOT / "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat"

EXPECTED_CORE = {
    "raven_vision": "0.6",
    "raven_council": "0.3",
    "agent_runner": "0.3",
    "memory_sync": "0.2",
    "mission_control": "2.9",
    "project_focus": "2.4",
    "raven_core": "1.12",
    "raven_now": "2.17",
    "raven_studio": "2.8",
}


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    assert count == 1, f"Expected one {label} anchor, found {count}"
    return text.replace(old, new, 1)


# Guard the shared Raven release contract before touching Command Center files.
raven = json.loads((ROOT / "RAH-RAVEN-VERSION.json").read_text(encoding="utf-8"))
assert raven["version"] == "2.0.32"
assert raven["release_gate"]["stable_components"] == EXPECTED_CORE
assert raven["privacy"]["raven_care_stable"] is True

# Core: keep the nine-core snapshot authoritative, but make support links package-only
# instead of hardcoded stability/version claims.
core = CORE.read_text(encoding="utf-8")
core = replace_once(core, "const CC_VERSION = '0.3.0';", "const CC_VERSION = '0.3.1';", "CC version")
old_extra = """  const EXTRA_COMPONENTS = Object.freeze([\n    { id: 'mission_engine', label: 'Mission Engine', version: '1.6.0', entry: 'index.html', stable: true },\n    { id: 'home_control', label: 'Home Control', version: '1.15.0', entry: 'RAH-HOME-CONTROL.html', stable: true },\n    { id: 'ai_photos', label: 'AI Photos · Golden Gallery', version: '1.0.0', entry: 'RAH-AI-PHOTOS.html', stable: true },\n    { id: 'system_health', label: 'System Health', version: '1.7', entry: 'RAH-RAVEN-NOW-V2.html', stable: true },\n    { id: 'voice_control', label: 'Voice Control', version: '1.7', entry: 'RAH-RAVEN-NOW-V2.html', stable: true },\n    { id: 'cloud_sync', label: 'Project Brain Cloud Sync', version: '1.1', entry: 'index.html', stable: true }\n  ]);\n"""
new_extra = """  const PACKAGE_COMPONENTS = Object.freeze([\n    { id: 'mission_engine', label: 'Mission Engine', entry: 'index.html' },\n    { id: 'home_control', label: 'Home Control', entry: 'RAH-HOME-CONTROL.html' },\n    { id: 'ai_photos', label: 'AI Photos · Golden Gallery', entry: 'RAH-AI-PHOTOS.html' },\n    { id: 'system_health', label: 'System Health', entry: 'RAH-RAVEN-NOW-V2.html' },\n    { id: 'voice_control', label: 'Voice Control', entry: 'RAH-RAVEN-NOW-V2.html' },\n    { id: 'cloud_sync', label: 'Project Brain Cloud Sync', entry: 'index.html' }\n  ]);\n"""
core = replace_once(core, old_extra, new_extra, "package component block")
core = replace_once(core, "    EXTRA_COMPONENTS,", "    PACKAGE_COMPONENTS,", "package component export")
CORE.write_text(core, encoding="utf-8")

# UI: stage-neutral runtime. Only the frozen nine-core set is shown as STABLE;
# support links are explicitly PACKAGED and have no hardcoded version assertion.
html = HTML.read_text(encoding="utf-8")
html = html.replace("RAH Raven Command Center v0.3", "RAH Raven Command Center v0.3.1")
html = html.replace("CC v0.3 · Raven 2.0.32", "CC v0.3.1 · Raven 2.0.32")
html = html.replace("<div class=\"eyebrow\">STABLE SERVICES</div><h2>Supporting local modules</h2>", "<div class=\"eyebrow\">PACKAGE MODULES</div><h2>Supporting local launch links</h2>")
html = html.replace("Not checked. CC v0.3 never probes the Bridge until you click the button.", "Not checked. CC v0.3.1 never probes the Bridge until you click the button.")
html = html.replace("RAH Raven Command Center v0.3 candidate · no mission mutation · no project activation · no agent execution · no automatic sending.", "RAH Raven Command Center v0.3.1 · read-only package integration · no mission mutation · no project activation · no agent execution · no automatic sending.")
old_render = """      const desc=useDescriptions ? descriptions[item.id] : 'Stable local supporting module in the Raven package.';\n      el.innerHTML='<header><div><h3></h3><div class=\"muted version\"></div></div><span class=\"state\">STABLE</span></header><p></p><button>Open module</button>';\n      el.querySelector('h3').textContent=item.label; el.querySelector('.version').textContent='v'+item.version; el.querySelector('p').textContent=desc;\n"""
new_render = """      const desc=useDescriptions ? descriptions[item.id] : 'Local package launch link. Stability and version remain authoritative in the module manifest, not here.';\n      el.innerHTML='<header><div><h3></h3><div class=\"muted version\"></div></div><span class=\"state\"></span></header><p></p><button>Open module</button>';\n      el.querySelector('h3').textContent=item.label; el.querySelector('.version').textContent=useDescriptions ? 'v'+item.version : 'package link'; el.querySelector('.state').textContent=useDescriptions ? 'STABLE' : 'PACKAGED'; el.querySelector('p').textContent=desc;\n"""
html = replace_once(html, old_render, new_render, "card rendering boundary")
html = replace_once(html, "renderCards(core.EXTRA_COMPONENTS, document.getElementById('extraGrid'), false);", "renderCards(core.PACKAGE_COMPONENTS, document.getElementById('extraGrid'), false);", "package render call")
assert "v0.3 candidate" not in html.lower()
assert "core.EXTRA_COMPONENTS" not in html
HTML.write_text(html, encoding="utf-8")

# Offline-first launcher: no network, no updater download, no powershell execution.
LAUNCHER.write_text(r'''@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Command Center

set "CC_PAGE=%~dp0RAH-COMMAND-CENTER-V0.3.html"

if not exist "%CC_PAGE%" goto :missing

echo.
echo  RAH RAVEN COMMAND CENTER v0.3.1
echo  =================================
echo  Lokal offline-first start. Ingen filer lastes ned eller oppdateres automatisk.
echo.
start "" "%CC_PAGE%"
exit /b 0

:missing
echo.
echo FEIL: RAH-COMMAND-CENTER-V0.3.html ble ikke funnet i denne mappen.
echo Ingen filer er endret eller lastet ned.
echo.
pause
exit /b 1
''', encoding="utf-8")

manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
assert manifest["version"] == "0.3.0"
assert manifest["stage"] == "core-integration-candidate"
assert manifest["release_gate"]["status"] == "candidate"
manifest["version"] = "0.3.1"
manifest["stage"] = "safe-one-click-candidate"
manifest["package_files"] = [
    "RAH-COMMAND-CENTER-V0.3.html",
    "rah-command-center-core.js",
    "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat",
]
features = manifest["features"]
features.update({
    "stage_neutral_runtime_label": True,
    "supporting_module_links_navigation_only": True,
    "supporting_module_stability_claims": False,
    "supporting_module_versions_hardcoded": False,
    "offline_first_one_click_launcher": True,
    "launcher_network_requests": False,
    "automatic_update": False,
    "launcher_powershell_execution": False,
})
manifest["release_gate"] = {
    "status": "candidate",
    "requires_tests": [
        "tests/rah-command-center-core.test.mjs",
        "tests/rah-command-center-v03.test.mjs",
        "tests/rah-command-center-packaging.test.mjs",
    ],
    "stable_raven_runtime_frozen": True,
    "change_policy": "command-center-only-safe-packaging-before-stable",
}
MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

CORE_TEST.write_text(r'''import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const core = require('../rah-command-center-core.js');

assert.equal(core.CC_VERSION, '0.3.1');
assert.equal(core.RAVEN_VERSION, '2.0.32');

const fallback = core.buildCoreSnapshot(null);
assert.equal(fallback.stableCount, 9);
assert.equal(fallback.totalCount, 9);
assert.equal(fallback.source, 'embedded-fallback');
assert.equal(fallback.components.find(c => c.id === 'raven_council').version, '0.3');

const live = core.buildCoreSnapshot({
  version: '2.0.32',
  release_gate: {
    stage: 'temporary-stable',
    stable_components: {
      raven_vision: '0.6', raven_council: '0.3', agent_runner: '0.3', memory_sync: '0.2',
      mission_control: '2.9', project_focus: '2.4', raven_core: '1.12', raven_now: '2.17', raven_studio: '2.8'
    }
  }
}, 'manifest');
assert.equal(live.source, 'manifest');
assert.equal(live.components.find(c => c.id === 'mission_control').version, '2.9');

assert.equal(core.PACKAGE_COMPONENTS.length, 6);
for (const item of core.PACKAGE_COMPONENTS) {
  assert.equal(Object.hasOwn(item, 'version'), false, `${item.id} must not hardcode a version`);
  assert.equal(Object.hasOwn(item, 'stable'), false, `${item.id} must not hardcode stable status`);
  assert.equal(core.isSafeRelativeEntry(item.entry), true);
}
assert.equal(core.EXTRA_COMPONENTS, undefined);

assert.equal(core.isCanonicalBridgeUrl('http://127.0.0.1:18765'), true);
assert.equal(core.isCanonicalBridgeUrl('http://localhost:18765'), false);
assert.equal(core.isCanonicalBridgeUrl('https://127.0.0.1:18765'), false);
assert.equal(core.isCanonicalBridgeUrl('http://127.0.0.1:9999'), false);
assert.equal(core.bridgeHealthUrl('http://evil.example'), 'http://127.0.0.1:18765/health');

assert.equal(core.isSafeRelativeEntry('RAH-RAVEN-NOW-V2.html'), true);
assert.equal(core.isSafeRelativeEntry('../secret.txt'), false);
assert.equal(core.isSafeRelativeEntry('https://example.com'), false);

const ready = core.summarizeBridgeHealth({case_center:true, chronicle:true, council_proxy:true, agent_runner:true});
assert.equal(ready.ok, true);
const partial = core.summarizeBridgeHealth({case_center:true, chronicle:true, council_proxy:false, agent_runner:true});
assert.equal(partial.ok, false);

console.log('RAH Command Center core v0.3.1 tests passed');
''', encoding="utf-8")

INTEGRATION_TEST.write_text(r'''import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const root = process.cwd();
const require = createRequire(import.meta.url);
const core = require(path.join(root, 'rah-command-center-core.js'));
const raven = JSON.parse(fs.readFileSync(path.join(root, 'RAH-RAVEN-VERSION.json'), 'utf8'));
const cc = JSON.parse(fs.readFileSync(path.join(root, 'RAH-COMMAND-CENTER-VERSION.json'), 'utf8'));
const html = fs.readFileSync(path.join(root, 'RAH-COMMAND-CENTER-V0.3.html'), 'utf8');

const expected = {
  raven_vision: '0.6', raven_council: '0.3', agent_runner: '0.3', memory_sync: '0.2',
  mission_control: '2.9', project_focus: '2.4', raven_core: '1.12', raven_now: '2.17', raven_studio: '2.8'
};

assert.equal(cc.version, '0.3.1');
assert.equal(cc.stage, 'safe-one-click-candidate');
assert.equal(cc.raven_contract, '2.0.32');
assert.equal(cc.features.stable_runtime_files_changed, false);
assert.equal(cc.features.stage_neutral_runtime_label, true);
assert.equal(cc.features.supporting_module_links_navigation_only, true);
assert.equal(cc.features.supporting_module_stability_claims, false);
assert.equal(cc.features.supporting_module_versions_hardcoded, false);
assert.equal(cc.features.bridge_health_check_explicit_only, true);
assert.equal(cc.features.automatic_agent_execution, false);
assert.equal(cc.features.automatic_mission_mutation, false);
assert.equal(cc.features.automatic_sending, false);
assert.deepEqual(raven.release_gate.stable_components, expected);
assert.equal(raven.privacy.raven_care_stable, true);

const snapshot = core.buildCoreSnapshot(raven, 'manifest');
assert.equal(snapshot.ravenVersion, '2.0.32');
assert.equal(snapshot.stableCount, 9);
assert.equal(snapshot.totalCount, 9);

assert.match(html, /CONTINUE RAH/);
assert.match(html, /PACKAGE MODULES/);
assert.match(html, /PACKAGED/);
assert.match(html, /Check local Bridge/);
assert.match(html, /Not checked\. CC v0\.3\.1 never probes the Bridge until you click the button\./);
assert.doesNotMatch(html, /v0\.3(?:\.1)? candidate/i);
assert.doesNotMatch(html, /Stable local supporting module/);
assert.doesNotMatch(html, /core\.EXTRA_COMPONENTS/);
assert.doesNotMatch(html, /\/agent\/run/);
assert.doesNotMatch(html, /setInterval\s*\(/);
assert.doesNotMatch(html, /navigator\.mediaDevices|getUserMedia|clipboard\.readText/i);

console.log('RAH Command Center v0.3.1 integration boundary passed');
''', encoding="utf-8")

PACKAGING_TEST.write_text(r'''import assert from 'node:assert/strict';
import fs from 'node:fs';

const launcher = fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat', 'utf8');
const cc = JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json', 'utf8'));

assert.equal(cc.version, '0.3.1');
assert.equal(cc.features.offline_first_one_click_launcher, true);
assert.equal(cc.features.launcher_network_requests, false);
assert.equal(cc.features.automatic_update, false);
assert.equal(cc.features.launcher_powershell_execution, false);
assert.deepEqual(cc.package_files, [
  'RAH-COMMAND-CENTER-V0.3.html',
  'rah-command-center-core.js',
  'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
]);

assert.match(launcher, /RAH-COMMAND-CENTER-V0\.3\.html/);
assert.match(launcher, /start "" "%CC_PAGE%"/);
assert.match(launcher, /Ingen filer lastes ned eller oppdateres automatisk/);
assert.doesNotMatch(launcher, /Invoke-WebRequest|curl\b|wget\b|bitsadmin|Start-BitsTransfer/i);
assert.doesNotMatch(launcher, /powershell|pwsh/i);
assert.doesNotMatch(launcher, /raw\.githubusercontent\.com|https?:\/\//i);
assert.doesNotMatch(launcher, /git\s+(pull|fetch|clone)/i);

console.log('RAH Command Center v0.3.1 packaging test passed: offline-first launcher has no updater or network path.');
''', encoding="utf-8")

# Run candidate regressions.
for test in (
    "tests/rah-command-center-core.test.mjs",
    "tests/rah-command-center-v03.test.mjs",
    "tests/rah-command-center-packaging.test.mjs",
    "tests/raven-release-gate.test.mjs",
    "tests/raven-care-v0.1.test.mjs",
):
    subprocess.run(["node", "--test", test], cwd=ROOT, check=True)

allowed = {
    ".github/scripts/build_rah_cc_v0_3_1_safe_one_click.py",
    ".github/workflows/build-rah-cc-v0.3.1-safe-one-click.yml",
    "RAH-COMMAND-CENTER-V0.3.html",
    "RAH-COMMAND-CENTER-VERSION.json",
    "rah-command-center-core.js",
    "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat",
    "tests/rah-command-center-core.test.mjs",
    "tests/rah-command-center-v03.test.mjs",
    "tests/rah-command-center-packaging.test.mjs",
}
changed = set(subprocess.check_output(["git", "diff", "--name-only", BASE_SHA], cwd=ROOT, text=True).splitlines())
extra = changed - allowed
assert not extra, f"Candidate touched non-Command-Center files: {sorted(extra)}"
assert "RAH-RAVEN-VERSION.json" not in changed
assert "RAH-RAVEN-START.html" not in changed
assert "RAH-RAVEN-CARE.html" not in changed
assert json.loads((ROOT / "RAH-RAVEN-VERSION.json").read_text(encoding="utf-8"))["release_gate"]["stable_components"] == EXPECTED_CORE

print("RAH Command Center v0.3.1 safe one-click candidate passed with all stable Raven surfaces frozen.")

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const manifest = JSON.parse(fs.readFileSync('apps/rah-ai-investigator/RAH-INVESTIGATOR-VERSION.json','utf8'));
const source = fs.readFileSync('apps/rah-ai-investigator/source/rah_investigator.py','utf8');
const workflow = fs.readFileSync('.github/workflows/validate-rah-ai-investigator-rc2-windows-exe.yml','utf8');

test('Investigator RC2 remains Candidate and non-promoting', () => {
  assert.equal(manifest.product, 'RAH AI Investigator');
  assert.equal(manifest.version, '1.0-RC2');
  assert.equal(manifest.stage, 'candidate');
  assert.equal(manifest.authority_delta, 'none');
  assert.equal(manifest.local_first, true);
  assert.equal(manifest.network_requests_in_core, false);
  assert.equal(manifest.external_tool_auto_execution, false);
  assert.equal(manifest.validation.stable_release_gate, false);
  assert.equal(manifest.owned_windows_acceptance.can_only_mark_eligible_for_stable_review, true);
  assert.equal(manifest.owned_windows_acceptance.can_promote_stable, false);
});

test('Canonical core exposes deterministic local self-test and no network stack', () => {
  assert.match(source, /def self_test\(\)/);
  assert.match(source, /RAH Investigator RC2 self-test PASS/);
  assert.match(source, /sub\.add_parser\("self-test"/);
  assert.match(source, /"networkRequests": False/);
  assert.match(source, /"externalToolExecution": False/);
  for (const forbidden of [
    /\bimport requests\b/,
    /\bfrom requests\b/,
    /urllib\.request/,
    /http\.client/,
    /\bimport socket\b/,
    /\bfrom socket\b/,
    /\bimport subprocess\b/,
    /\bfrom subprocess\b/,
    /os\.system\s*\(/,
    /os\.popen\s*\(/
  ]) assert.doesNotMatch(source, forbidden);
});

test('Windows EXE workflow builds only canonical local normalizer and self-tests built binary', () => {
  assert.match(workflow, /runs-on: windows-latest/);
  assert.match(workflow, /python-version: '3\.12'/);
  assert.match(workflow, /pyinstaller/i);
  assert.match(workflow, /apps\\rah-ai-investigator\\source\\rah_investigator\.py/);
  assert.match(workflow, /RAH-AI-Investigator-RC2\.exe/);
  assert.match(workflow, /self-test/);
  assert.match(workflow, /actions\/upload-artifact@v4/);
  assert.match(workflow, /rah-ai-investigator-rc2-windows-exe-ci/);
  assert.match(workflow, /contents: read/);

  for (const forbidden of [
    /sherlock/i,
    /phoneinfoga/i,
    /spiderfoot/i,
    /Invoke-WebRequest/i,
    /Invoke-RestMethod/i,
    /\bcurl\b/i,
    /\bwget\b/i,
    /git clone/i,
    /winget/i,
    /choco/i
  ]) assert.doesNotMatch(workflow, forbidden);
});

console.log('RAH AI Investigator RC2 Windows EXE gate contract: PASS');

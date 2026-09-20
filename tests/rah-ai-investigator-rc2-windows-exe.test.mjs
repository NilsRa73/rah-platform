import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const manifest=JSON.parse(fs.readFileSync('apps/rah-ai-investigator/RAH-INVESTIGATOR-VERSION.json','utf8'));
const release=JSON.parse(fs.readFileSync('apps/rah-ai-investigator/RAH-INVESTIGATOR-STABLE-RELEASE.json','utf8'));
const source=fs.readFileSync('apps/rah-ai-investigator/source/rah_investigator.py','utf8');
const workflow=fs.readFileSync('.github/workflows/validate-rah-ai-investigator-rc2-windows-exe.yml','utf8');

test('Investigator 1.0 is Stable and frozen after green release validation',()=>{
  assert.equal(manifest.product,'RAH AI Investigator');
  assert.equal(manifest.version,'1.0.0');
  assert.equal(manifest.stage,'stable');
  assert.equal(manifest.authority_delta,'none');
  assert.equal(manifest.local_first,true);
  assert.equal(manifest.network_requests_in_core,false);
  assert.equal(manifest.external_tool_auto_execution,false);
  assert.equal(manifest.validation.stable_release_gate,true);
  assert.equal(manifest.stable_release_gate.status,'passed');
  assert.equal(manifest.stable_release_gate.runtime_files_frozen,true);
  assert.equal(manifest.development_paused,true);
  assert.equal(release.stage,'stable-release');
  assert.equal(release.validation.status,'passed');
});

test('Stable core exposes deterministic local self-test and no network stack',()=>{
  assert.match(source,/VERSION = "1\.0\.0"/);
  assert.match(source,/RAH Investigator 1\.0 Stable self-test PASS/);
  assert.match(source,/sub\.add_parser\("self-test"/);
  assert.match(source,/"networkRequests": False/);
  assert.match(source,/"externalToolExecution": False/);
  for(const forbidden of [
    /\bimport requests\b/,/\bfrom requests\b/,/urllib\.request/,/http\.client/,
    /\bimport socket\b/,/\bfrom socket\b/,/\bimport subprocess\b/,
    /\bfrom subprocess\b/,/os\.system\s*\(/,/os\.popen\s*\(/
  ]) assert.doesNotMatch(source,forbidden);
});

test('Windows EXE workflow builds and tests only the Stable local normalizer',()=>{
  assert.match(workflow,/runs-on: windows-latest/);
  assert.match(workflow,/pyinstaller/i);
  assert.match(workflow,/RAH-AI-Investigator-1\.0\.exe/);
  assert.match(workflow,/self-test/);
  assert.match(workflow,/case\.version -ne '1\.0\.0'/);
  assert.match(workflow,/rah-ai-investigator-v1\.0-stable-windows-exe/);
  assert.match(workflow,/contents: read/);
  assert.doesNotMatch(workflow,/RAH-AI-Investigator-RC2\.exe|1\.0-RC2|stage -ne 'candidate'/);
  for(const forbidden of [/sherlock/i,/phoneinfoga/i,/spiderfoot/i,/Invoke-WebRequest/i,/Invoke-RestMethod/i,/\bcurl\b/i,/\bwget\b/i,/git clone/i,/winget/i,/choco/i]){
    assert.doesNotMatch(workflow,forbidden);
  }
});

console.log('RAH AI Investigator 1.0 Stable Windows EXE gate contract: PASS');

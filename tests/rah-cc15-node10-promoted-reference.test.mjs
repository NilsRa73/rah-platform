import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const ref=JSON.parse(fs.readFileSync('RAH-CC15-NODE10-PROMOTED-IMPLEMENTATION-REFERENCE.json','utf8'));
const core=fs.readFileSync('rah-command-center-core-v1.5.js','utf8');
const html=fs.readFileSync('RAH-COMMAND-CENTER-V1.5.html','utf8');
const node=fs.readFileSync('rah-node-agent-v1.0.py','utf8');
const hash=path=>execFileSync('git',['hash-object',path],{encoding:'utf8'}).trim();

test('promoted implementation reference pins Stable identity and exact 4/3/5 authority',()=>{
  assert.equal(ref.stage,'promoted-implementation-reference');
  assert.equal(ref.authorityDelta,'none');
  assert.equal(ref.stable.commandCenterVersion,'1.5.0');
  assert.equal(ref.stable.nodeAgentVersion,'1.0.0');
  assert.equal(ref.stable.nodeActionsProtocol,'rah-node-actions-v5');
  assert.equal(ref.authoritySurface.capabilities.length,4);
  assert.equal(ref.authoritySurface.actions.length,3);
  assert.equal(ref.authoritySurface.routes.length,5);
});

test('promoted Candidate blobs are immutable runtime dependencies, not deletable archives',()=>{
  assert.equal(ref.promotedImplementation.referenceOnlyMetadata,true);
  assert.equal(ref.promotedImplementation.runtimeFilesMustRemainPresent,true);
  assert.equal(ref.promotedImplementation.safeToDelete,false);
  for(const item of [ref.promotedImplementation.commandCenterCoreCandidate,ref.promotedImplementation.commandCenterHtmlCandidate,ref.promotedImplementation.nodeAgentCandidate])assert.equal(hash(item.path),item.gitBlobSha,item.path);
  assert.ok(core.includes("require('./rah-command-center-core-v1.5-candidate.js')"));
  assert.ok(html.includes("const SOURCE='RAH-COMMAND-CENTER-V1.5-CANDIDATE.html'"));
  assert.ok(node.includes("CANDIDATE_PATH=Path(__file__).with_name('rah-node-agent-v1.0-candidate.py')"));
});

test('Stable wrapper and rollback blobs remain pinned',()=>{
  for(const item of Object.values(ref.stableWrappers))assert.equal(hash(item.path),item.gitBlobSha,item.path);
  assert.equal(ref.directRollback.commandCenterVersion,'1.4.0');
  assert.equal(ref.directRollback.nodeAgentVersion,'0.9.0');
  assert.equal(ref.directRollback.dataMigration,'none');
  assert.equal(ref.directRollback.secretMigration,'none');
});

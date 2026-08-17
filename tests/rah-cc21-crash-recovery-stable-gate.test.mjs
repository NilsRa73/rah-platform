import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const gate=JSON.parse(fs.readFileSync('RAH-CC21-CRASH-RECOVERY-STABLE-GATE.json','utf8'));
const candidate=JSON.parse(fs.readFileSync(gate.acceptedEvidence.candidate.path,'utf8'));
const readiness=JSON.parse(fs.readFileSync(gate.acceptedEvidence.readiness.path,'utf8'));
const manifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const hash=path=>execFileSync('git',['hash-object',path],{encoding:'utf8'}).trim();

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('Stable gate is evidence-only and pins the accepted crash-recovery Candidate exactly',()=>{
  assert.equal(gate.stage,'stable-promotion-gate');
  assert.equal(gate.status,'ready-for-explicit-stable-release');
  assert.equal(gate.authorityDelta,'none');
  assert.equal(gate.acceptedMainCommit,'99f0eab770ceee7dca20ab030a7ceb421a0f2250');
  for(const item of Object.values(gate.acceptedEvidence)){
    assert.ok(fs.existsSync(item.path),item.path);
    assert.equal(hash(item.path),item.gitBlobSha,`${item.path}: accepted evidence blob drift`);
  }
  assert.equal(candidate.stage,'candidate-updater-crash-recovery');
  assert.equal(candidate.candidateId,gate.acceptedEvidence.candidate.candidateId);
  assert.equal(readiness.readinessId,gate.acceptedEvidence.readiness.readinessId);
});

test('gate baseline remains CC2.1 / Node1.3 generation 6 with exact 49 package and 50 transaction files',()=>{
  assert.deepEqual(gate.baseline,{ravenVersion:'2.0.32',commandCenterVersion:'2.1.0',nodeAgentVersion:'1.3.0',nodeActionsProtocol:'rah-node-actions-v7',authProtocol:'rah-node-auth-v2',policyId:'rah-capability-allowlist-v1',canonicalPackageGeneration:6,canonicalPackageFileCount:49,transactionFileCount:50,immutableReleaseCommit:'a6b77f93dca5f774cdb76deb707edc71f86638a1'});
  assert.equal(manifest.version,'2.1.0');
  assert.equal(manifest.stage,'stable');
  assert.equal(manifest.canonical_package_generation,6);
  assert.equal(manifest.package_files.length,49);
  assert.equal(new Set(manifest.package_files).size,49);
});

test('gate cannot mutate updater/runtime/package or expand authority',()=>{
  assert.deepEqual(gate.promotionScope,{gateChangesUpdater:false,gateChangesCommandCenterRuntime:false,gateChangesNodeRuntime:false,gateChangesCanonicalPackage:false,stableReleaseMayChangeAcceptedUpdaterBytes:false,stableReleaseMayExpandAuthority:false,newCandidateRequiredOnAcceptedByteDrift:true});
  assert.deepEqual(gate.authoritySurface.capabilities,caps);
  assert.deepEqual(gate.authoritySurface.actions,actions);
  assert.deepEqual(gate.authoritySurface.businessRoutes,routes);
  assert.deepEqual(candidate.authoritySurface,gate.authoritySurface);
});

test('gate explicitly requires the full Fase24 through Fase29 regression chain',()=>{
  const req=new Set(gate.promotionRequirements);
  for(const item of [
    'accepted-updater-blob-is-unchanged',
    'accepted-candidate-contract-blob-is-unchanged',
    'readiness-evidence-blob-is-unchanged',
    'candidate-regression-test-blob-is-unchanged',
    'canonical-package-contract-passes',
    'recursive-dependency-integrity-passes',
    'immutable-release-trust-anchor-passes',
    'downloaded-git-blob-verification-passes',
    'transactional-staging-and-rollback-passes',
    'stable-node-agent-1.3-token-proof-passes',
    'crash-recovery-candidate-regression-passes',
    'powershell-parser-passes',
    'fileshare-none-exclusive-lock-smoke-passes'
  ])assert.ok(req.has(item),item);
});

test('broad power remains explicitly forbidden',()=>{
  const forbidden=new Set(gate.forbiddenPower);
  for(const item of ['shell','generic-command-execution','generic-process-launch','caller-controlled-executable-path','caller-controlled-generic-argument-array','generic-file-api','generic-endpoint-dispatch','native-raven-remote-control-api','bearer-token-persistence','challenge-persistence','approval-proof-persistence','password-persistence','peer-id-persistence'])assert.ok(forbidden.has(item),item);
});

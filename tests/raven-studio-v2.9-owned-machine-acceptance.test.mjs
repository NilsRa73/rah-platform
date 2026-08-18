import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const ps=fs.readFileSync('ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.ps1','utf8');
const bat=fs.readFileSync('ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.bat','utf8');
const bridgeBat=fs.readFileSync('desktop-bridge/start-bridge.bat','utf8');
const candidate=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json','utf8'));
const stable=JSON.parse(fs.readFileSync('RAH-RAVEN-STUDIO-VERSION.json','utf8'));
const cc=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const urls=[
  'http://127.0.0.1:18765/health',
  'http://127.0.0.1:18765/lm/models',
  'http://127.0.0.1:1234/v1/models'
];

test('acceptance kit is pinned to current Candidate and Stable bases',()=>{
  assert.equal(candidate.version,'2.9.0');
  assert.equal(candidate.stage,'candidate');
  assert.equal(stable.version,'2.8.0');
  assert.equal(stable.stage,'stable');
  assert.equal(cc.version,'2.3.0');
  assert.equal(cc.canonical_package_generation,8);
  for(const marker of ["$Candidate.version-ne'2.9.0'","$Stable.version-ne'2.8.0'","$Cc.version-ne'2.3.0'","canonical_package_generation-ne8","$Raven.version-ne'2.0.32'"])assert.ok(ps.includes(marker),marker);
});

test('network checks are GET-only and restricted to the exact loopback status set',()=>{
  for(const url of urls)assert.ok(ps.includes(url),url);
  assert.match(ps,/\$StatusUrls -notcontains \$Uri/);
  assert.match(ps,/Invoke-RestMethod -Method Get -Uri \$Uri/);
  assert.doesNotMatch(ps,/Invoke-RestMethod\s+-Method\s+(Post|Put|Patch|Delete)/i);
  assert.doesNotMatch(ps,/https?:\/\/(?!127\.0\.0\.1)/i);
});

test('manual evidence is explicit and noninteractive mode cannot fabricate UI acceptance',()=>{
  assert.match(ps,/Skriv YES bare hvis dette faktisk er kontrollert/);
  assert.match(ps,/if\(\$NonInteractive\)\{return \$false\}/);
  for(const marker of ['candidateShellLoaded','stableComponentNavigation','bridgeWorkspaceNavigation','statusUiBehavior'])assert.ok(ps.includes(marker),marker);
});

test('acceptance can only make Candidate eligible for review and never promote Stable',()=>{
  assert.match(ps,/eligibleForStableReview=\$EligibleForStableReview/);
  assert.match(ps,/stablePromotion='BLOCKED'/);
  assert.match(ps,/stablePromotionAutomated=\$false/);
  assert.match(ps,/stableFilesModifiedByAcceptance=\$false/);
  assert.equal(candidate.promotion_policy.stable_promotion_included,false);
  assert.equal(candidate.promotion_policy.candidate_can_promote_itself,false);
  assert.doesNotMatch(ps,/git\s+(push|commit|merge)|update_ref|merge_pull_request/i);
});

test('acceptance persists only summary metadata, not endpoint bodies or model/user content',()=>{
  assert.match(ps,/endpointResponseBodiesPersisted=\$false/);
  assert.match(ps,/modelNamesPersisted=\$false/);
  assert.match(ps,/modelAnswerTextPersisted=\$false/);
  assert.match(ps,/userContentPersisted=\$false/);
  assert.match(ps,/Set-Content -LiteralPath \$SummaryPath/);
  assert.doesNotMatch(ps,/Set-Content -LiteralPath \$(StableManifest|CandidateManifest|CcManifest|RavenManifest)/);
});

test('one-click launcher preflights only the fixed canonical local Bridge before acceptance',()=>{
  assert.match(bat,/desktop-bridge\\start-bridge\.bat/i);
  assert.match(bat,/http:\/\/127\.0\.0\.1:18765\/health/i);
  assert.match(bat,/\$h\.ok -eq \$true -and \$h\.council_proxy -eq \$true/i);
  assert.match(bat,/start "RAH Raven Desktop Bridge 18765" \/min cmd\.exe \/d \/c call "%BRIDGE_LAUNCHER%"/i);
  assert.match(bat,/ACCEPT-RAH-RAVEN-STUDIO-2\.9-CANDIDATE\.ps1/);
  assert.match(bat,/Dette promoterer aldri Stable automatisk/);
  assert.match(bat,/--self-test/i);
  assert.match(bat,/Studio acceptance startes IKKE/i);
  const bridgeFailedLabel=bat.lastIndexOf(':bridge_failed');
  const missingBridgeLabel=bat.lastIndexOf(':missing_bridge_launcher');
  assert.ok(bridgeFailedLabel>=0 && missingBridgeLabel>bridgeFailedLabel);
  const failedBlock=bat.slice(bridgeFailedLabel,missingBridgeLabel);
  assert.match(failedBlock,/exit \/b 3/i);
  assert.doesNotMatch(failedBlock,/powershell\.exe[^\r\n]*ACCEPT_PS1/i);
  assert.doesNotMatch(bat,/curl|wget|Invoke-WebRequest/i);
  const batUrls=[...bat.matchAll(/https?:\/\/[^\s'"%]+/gi)].map(m=>m[0].replace(/[.)]+$/,''));
  assert.ok(batUrls.length>=1);
  for(const url of batUrls)assert.equal(url,'http://127.0.0.1:18765/health');
});

test('canonical Bridge launcher is pinned to raven_bridge.py on 18765',()=>{
  assert.match(bridgeBat,/raven_bridge\.py/i);
  assert.match(bridgeBat,/http:\/\/127\.0\.0\.1:18765\/health/i);
  assert.match(bridgeBat,/council_proxy/i);
  assert.doesNotMatch(bridgeBat,/:8765(?:\D|$)/);
});

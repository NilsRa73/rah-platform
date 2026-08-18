param([switch]$NonInteractive,[switch]$NoLaunch)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$CandidateHtml=Join-Path $Root 'RAH-RAVEN-START-V2.9-CANDIDATE.html'
$CandidateManifest=Join-Path $Root 'RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json'
$StableManifest=Join-Path $Root 'RAH-RAVEN-STUDIO-VERSION.json'
$CcManifest=Join-Path $Root 'RAH-COMMAND-CENTER-VERSION.json'
$RavenManifest=Join-Path $Root 'RAH-RAVEN-VERSION.json'
$StatusUrls=@(
  'http://127.0.0.1:18765/health',
  'http://127.0.0.1:18765/lm/models',
  'http://127.0.0.1:1234/v1/models'
)

function Require-File([string]$Path,[string]$Label){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "$Label mangler: $Path"}
}
function Confirm-Completed([string]$Prompt){
  if($NonInteractive){return $false}
  $answer=Read-Host "$Prompt Skriv YES bare hvis dette faktisk er kontrollert"
  return $answer.Trim().ToUpperInvariant() -eq 'YES'
}
function Get-FixedStatus([string]$Uri){
  if($StatusUrls -notcontains $Uri){throw 'status-url-not-allowed'}
  return Invoke-RestMethod -Method Get -Uri $Uri -TimeoutSec 5 -ErrorAction Stop
}

Require-File $CandidateHtml 'Studio 2.9 Candidate HTML'
Require-File $CandidateManifest 'Studio 2.9 Candidate manifest'
Require-File $StableManifest 'Studio Stable manifest'
Require-File $CcManifest 'Command Center manifest'
Require-File $RavenManifest 'Raven manifest'

$Candidate=Get-Content -LiteralPath $CandidateManifest -Raw -Encoding UTF8|ConvertFrom-Json
$Stable=Get-Content -LiteralPath $StableManifest -Raw -Encoding UTF8|ConvertFrom-Json
$Cc=Get-Content -LiteralPath $CcManifest -Raw -Encoding UTF8|ConvertFrom-Json
$Raven=Get-Content -LiteralPath $RavenManifest -Raw -Encoding UTF8|ConvertFrom-Json

if($Candidate.version-ne'2.9.0'-or$Candidate.stage-ne'candidate'){throw 'Studio Candidate-kontrakten er ikke 2.9.0 Candidate.'}
if($Candidate.authority_delta-ne'none'-or$Candidate.stable_runtime_files_modified-ne$false){throw 'Studio Candidate authority/freeze-kontrakt avviker.'}
if($Stable.version-ne'2.8.0'-or$Stable.stage-ne'stable'){throw 'Studio 2.8 Stable er ikke intakt.'}
if($Cc.version-ne'2.3.0'-or$Cc.stage-ne'stable'-or[int]$Cc.canonical_package_generation-ne8){throw 'Canonical Command Center er ikke 2.3.0 generation 8.'}
if($Raven.version-ne'2.0.32'){throw 'Raven-kontrakten er ikke 2.0.32.'}
if($Candidate.promotion_policy.stable_promotion_included-ne$false-or$Candidate.promotion_policy.candidate_can_promote_itself-ne$false){throw 'Candidate lifecycle-kontrakten tillater uventet promotion.'}

Write-Host '============================================================' -ForegroundColor DarkYellow
Write-Host 'RAH RAVEN STUDIO 2.9 - OWNED WINDOWS ACCEPTANCE' -ForegroundColor Yellow
Write-Host '============================================================' -ForegroundColor DarkYellow
Write-Host 'Denne testen kan aldri promotere Stable automatisk.' -ForegroundColor Yellow
Write-Host 'Den tester bare lokal Candidate, faste loopback-statuskilder og eksplisitt UI-kontroll.'
Write-Host ''
Write-Host '[PASS] Manifest: Studio 2.9 Candidate / Studio 2.8 Stable / CC2.3 gen8 / Raven 2.0.32.' -ForegroundColor Green

$BridgePass=$false
$CouncilProxyPass=$false
$LmPass=$false
$LmModelCount=0
try{
  $Health=Get-FixedStatus $StatusUrls[0]
  $BridgePass=($Health.ok -eq $true)
  $CouncilProxyPass=($Health.council_proxy -eq $true)
}catch{}

try{
  if($BridgePass){$Models=Get-FixedStatus $StatusUrls[1]}else{$Models=Get-FixedStatus $StatusUrls[2]}
  $LmModelCount=@($Models.data).Count
  $LmPass=$LmModelCount-gt0
}catch{}

Write-Host ("Bridge loopback : "+$(if($BridgePass){'PASS'}else{'FAIL'})) -ForegroundColor $(if($BridgePass){'Green'}else{'Yellow'})
Write-Host ("Council proxy    : "+$(if($CouncilProxyPass){'PASS'}else{'FAIL'})) -ForegroundColor $(if($CouncilProxyPass){'Green'}else{'Yellow'})
Write-Host ("LM model count   : $LmModelCount") -ForegroundColor $(if($LmPass){'Green'}else{'Yellow'})

if(-not$NoLaunch-and-not$NonInteractive){
  Start-Process -FilePath $CandidateHtml
  Write-Host 'Candidate er åpnet i standard nettleser.' -ForegroundColor Cyan
}

$ShellLoaded=Confirm-Completed 'Vises Studio 2.9 Candidate-shellen normalt, uten blank eller blokkert hovedramme?'
$StableNavigation=Confirm-Completed 'Fungerer navigasjon i samme workspace til Studio 2.8, Vision, Council, Mission og Devices/Fleet CC2.3?'
$BridgeNavigation=Confirm-Completed 'Når Desktop Bridge kjører: åpner Chronicle og Insights i samme workspace?'
$StatusUi=Confirm-Completed 'Oppdateres Bridge/LM/Council-statusene, og unngår Vision å påstå KLAR uten en ekte bildetest?'

$EligibleForStableReview=(
  $BridgePass -and
  $CouncilProxyPass -and
  $LmPass -and
  $ShellLoaded -and
  $StableNavigation -and
  $BridgeNavigation -and
  $StatusUi
)

$EvidenceRoot=if($env:LOCALAPPDATA){Join-Path $env:LOCALAPPDATA 'RAH Raven\acceptance'}else{Join-Path $Root '.rah-local-evidence'}
New-Item -ItemType Directory -Path $EvidenceRoot -Force|Out-Null
$SummaryPath=Join-Path $EvidenceRoot 'raven-studio-v2.9-owned-machine-acceptance.json'
$Summary=[ordered]@{
  schemaVersion=1
  product='RAH Raven Studio'
  candidateVersion='2.9.0'
  acceptance='owned-windows-machine'
  generatedAt=(Get-Date).ToUniversalTime().ToString('o')
  contract=[ordered]@{
    stableStudioVersion='2.8.0'
    commandCenterVersion='2.3.0'
    commandCenterPackageGeneration=8
    ravenVersion='2.0.32'
    authorityDelta='none'
  }
  machineEvidence=[ordered]@{
    bridgeLoopback=$BridgePass
    councilProxy=$CouncilProxyPass
    lmHasModel=$LmPass
    lmModelCount=$LmModelCount
    endpointResponseBodiesPersisted=$false
    modelNamesPersisted=$false
    modelAnswerTextPersisted=$false
    userContentPersisted=$false
  }
  manualUiReview=[ordered]@{
    candidateShellLoaded=$ShellLoaded
    stableComponentNavigation=$StableNavigation
    bridgeWorkspaceNavigation=$BridgeNavigation
    statusUiBehavior=$StatusUi
  }
  eligibleForStableReview=$EligibleForStableReview
  stablePromotion='BLOCKED'
  stablePromotionAutomated=$false
  stableFilesModifiedByAcceptance=$false
  nextAction=$(if($EligibleForStableReview){'Candidate may enter a separate manual Stable-readiness review. This acceptance does not promote it.'}else{'Start the required local services, complete every explicit UI check, and rerun. Stable remains blocked.'})
}
$Summary|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $SummaryPath -Encoding UTF8

Write-Host ''
Write-Host '============================================================' -ForegroundColor DarkYellow
Write-Host 'STUDIO 2.9 ACCEPTANCE RESULT' -ForegroundColor Yellow
Write-Host '============================================================' -ForegroundColor DarkYellow
Write-Host "Evidence: $SummaryPath"
Write-Host "Eligible for Stable review: $EligibleForStableReview"
Write-Host 'Stable promotion: BLOCKED'
Write-Host 'Automatic promotion: NO'

if($EligibleForStableReview){exit 0}
exit 2

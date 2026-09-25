[CmdletBinding()]
param([switch]$SelfTest,[switch]$NoLaunch)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$Studio=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.html'
$Diagnostics=Join-Path $Root 'RAH-RAVEN-STUDIO-DIAGNOSTICS-V3.1-CANDIDATE.5.html'
$Repair=Join-Path $Root 'SAFE-REPAIR-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.ps1'
$Manifest=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.json'
$BridgeUrl='http://127.0.0.1:18765/health'
$LmUrl='http://127.0.0.1:1234/v1/models'
$LogRoot='C:\RAH\Logs'
$ReportPath=Join-Path $LogRoot 'RAVEN-STUDIO-ONECLICK-LATEST.json'
$Steps=[System.Collections.Generic.List[object]]::new()

function Add-Step([string]$Phase,[string]$Name,[string]$Status,[string]$Detail){
  $Steps.Add([pscustomobject]@{
    phase=$Phase
    name=$Name
    status=$Status
    detail=$Detail
    at=(Get-Date).ToString('o')
  })
  Write-Host ("[{0}] {1} / {2} - {3}" -f $Status,$Phase,$Name,$Detail)
}

function Test-JsonUrl([string]$Url,[int]$TimeoutSec=2){
  try{return Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec $TimeoutSec -ErrorAction Stop}
  catch{return $null}
}

function Get-Snapshot([string]$Phase){
  $bridge=Test-JsonUrl $BridgeUrl 2
  $bridgeOk=[bool]($bridge -and $bridge.ok -eq $true)
  Add-Step $Phase 'Desktop Bridge' ($(if($bridgeOk){'PASS'}else{'FAIL'})) ($(if($bridgeOk){"v$($bridge.version) on 18765"}else{'No valid /health response'}))

  $agentOk=[bool]($bridgeOk -and $bridge.agent_runner -eq $true -and [string]$bridge.agent_runner_mode -eq 'read-only-allowlist')
  Add-Step $Phase 'Agent Runner' ($(if($agentOk){'PASS'}else{'FAIL'})) ($(if($agentOk){"v$($bridge.agent_runner_version) read-only-allowlist"}else{'Safe Agent Runner mode not confirmed'}))

  $lm=Test-JsonUrl $LmUrl 2
  $lmReachable=[bool]$lm
  $models=if($lm -and $lm.data){@($lm.data).Count}else{0}
  $lmStatus=if(-not $lmReachable){'WARN'}elseif($models -gt 0){'PASS'}else{'WARN'}
  $lmDetail=if(-not $lmReachable){'Optional LM Studio offline'}elseif($models -gt 0){"LM Studio models=$models"}else{'LM Studio reachable, no model loaded'}
  Add-Step $Phase 'LM Studio' $lmStatus $lmDetail

  return [pscustomobject]@{
    bridge=$bridge
    bridge_ok=$bridgeOk
    agent_ok=$agentOk
    lm_reachable=$lmReachable
    lm_models=$models
    core_ok=[bool]($bridgeOk -and $agentOk)
  }
}

function Save-Report($Pre,$Post,[bool]$RepairAttempted,[int]$RepairExit,[string]$Result,[string]$Detail){
  New-Item -ItemType Directory -Force -Path $LogRoot|Out-Null
  [pscustomobject]@{
    schema='rah-raven-studio-oneclick-v1'
    candidate='3.1.0-candidate.5'
    generatedAt=(Get-Date).ToString('o')
    computer=$env:COMPUTERNAME
    result=$Result
    detail=$Detail
    precheck=$Pre
    repair=[pscustomobject]@{attempted=$RepairAttempted;exit_code=$RepairExit}
    postcheck=$Post
    steps=@($Steps)
    safety=[pscustomobject]@{
      admin_required=$false
      installs=$false
      firewall_changes=$false
      network_changes=$false
      model_downloads=$false
      process_kills=$false
      background_bridge_window_hidden=$true
    }
  }|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

function Open-Studio([string]$Result,[string]$Detail){
  if($NoLaunch){return}
  $encoded=[uri]::EscapeDataString($Detail)
  Start-Process -FilePath ($Studio + '?startup=' + $Result + '&detail=' + $encoded)
}

function Test-Contracts {
  foreach($p in @($Studio,$Diagnostics,$Repair,$Manifest)){
    if(-not (Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing required file: $p"}
  }
  $m=Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$m.version -ne '3.1.0-candidate.5'){throw 'Manifest version mismatch'}
  if(-not $m.one_click_startup.precheck){throw 'Manifest PRECHECK contract missing'}
  if(-not $m.one_click_startup.safe_repair){throw 'Manifest SAFE REPAIR contract missing'}
  if(-not $m.one_click_startup.postcheck){throw 'Manifest POSTCHECK contract missing'}
  Write-Host 'RAH RAVEN STUDIO v3.1 CANDIDATE.5 CONTRACT: PASS'
}

if($SelfTest){
  try{Test-Contracts;exit 0}catch{Write-Host "[FAIL] $($_.Exception.Message)";exit 1}
}

$pre=$null;$post=$null;$repairAttempted=$false;$repairExit=0;$result='FAIL';$detail=''
try{
  Write-Host '============================================================'
  Write-Host ' RAH RAVEN STUDIO v3.1 CANDIDATE.5 - ONE CLICK STARTUP'
  Write-Host ' PRECHECK -> SAFE REPAIR -> POSTCHECK -> STUDIO'
  Write-Host '============================================================'
  Test-Contracts

  Write-Host ''
  Write-Host '--- PRECHECK ------------------------------------------------'
  $pre=Get-Snapshot 'PRECHECK'

  if(-not $pre.core_ok){
    $repairAttempted=$true
    Add-Step 'REPAIR' 'Safe Repair' 'RUN' 'Executing narrow Candidate.5 Safe Repair'
    & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Repair -NoOpenDiagnostics
    $repairExit=$LASTEXITCODE
    Add-Step 'REPAIR' 'Safe Repair' ($(if($repairExit -eq 0){'PASS'}else{'FAIL'})) "exit=$repairExit"
  }else{
    Add-Step 'REPAIR' 'Safe Repair' 'SKIP' 'Core already healthy; no repair needed'
  }

  Write-Host ''
  Write-Host '--- POSTCHECK -----------------------------------------------'
  $post=Get-Snapshot 'POSTCHECK'

  if($post.core_ok){
    $result='PASS'
    if($post.lm_reachable -and $post.lm_models -gt 0){
      $detail='Bridge + Agent Runner ready. LM Studio model loaded.'
    }elseif($post.lm_reachable){
      $detail='Bridge + Agent Runner ready. LM Studio has no loaded model (optional).'
    }else{
      $detail='Bridge + Agent Runner ready. LM Studio offline (optional).'
    }
  }else{
    $result='FAIL'
    if(-not $post.bridge_ok){$detail='Desktop Bridge is still unavailable after Safe Repair.'}
    elseif(-not $post.agent_ok){$detail='Bridge responds, but Agent Runner safe mode is not confirmed.'}
    else{$detail='Raven core postcheck failed.'}
  }

  Save-Report $pre $post $repairAttempted $repairExit $result $detail

  Write-Host ''
  Write-Host '============================================================'
  Write-Host " STARTUP $result"
  Write-Host " $detail"
  Write-Host " Report: $ReportPath"
  Write-Host '============================================================'

  Open-Studio $result $detail
}catch{
  $detail=$_.Exception.Message
  Add-Step 'FINAL' 'Unhandled error' 'FAIL' $detail
  Save-Report $pre $post $repairAttempted $repairExit 'FAIL' $detail
  Write-Host "[FAIL] $detail"
  Open-Studio 'FAIL' $detail
  exit 1
}

if($result -eq 'PASS'){exit 0}
exit 1

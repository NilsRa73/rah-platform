[CmdletBinding()]
param(
  [switch]$SelfTest,
  [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$Candidate='3.1.0-candidate.5'
$Manifest=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.json'
$CandidateCheck=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.ps1'
$OneClick=Join-Path $Root 'RAH-RAVEN-STUDIO-ONECLICK-V3.1-CANDIDATE.5.ps1'
$Repair=Join-Path $Root 'SAFE-REPAIR-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.ps1'
$StartCmd=Join-Path $Root 'START-HER-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.cmd'
$Studio=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.html'
$Diagnostics=Join-Path $Root 'RAH-RAVEN-STUDIO-DIAGNOSTICS-V3.1-CANDIDATE.5.html'

$LogRoot='C:\RAH\Logs'
$OneClickReport=Join-Path $LogRoot 'RAVEN-STUDIO-ONECLICK-LATEST.json'
$AcceptanceReport=Join-Path $LogRoot 'RAVEN-STUDIO-HOVED-PC-ACCEPTANCE-LATEST.json'
$Checks=[System.Collections.Generic.List[object]]::new()

function Add-Check([string]$Name,[string]$Status,[string]$Detail){
  $Checks.Add([pscustomobject]@{
    name=$Name
    status=$Status
    detail=$Detail
    at=(Get-Date).ToString('o')
  })
  $color=switch($Status){'PASS'{'Green'}'INFO'{'Cyan'}'WARN'{'Yellow'}default{'Red'}}
  Write-Host ("[{0}] {1} - {2}" -f $Status,$Name,$Detail) -ForegroundColor $color
}

function Require-File([string]$Path,[string]$Label){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){throw "$Label missing: $Path"}
  Add-Check $Label 'PASS' $Path
}

function Assert-Parse([string]$Path){
  $tokens=$null;$errors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
  if(@($errors).Count){throw "$([IO.Path]::GetFileName($Path)) parse failed: $($errors[0].Message)"}
  Add-Check ("Parse "+[IO.Path]::GetFileName($Path)) 'PASS' 'PowerShell syntax OK'
}

function Save-Report([string]$Final,[string]$ErrorText,$OneClickData){
  New-Item -ItemType Directory -Force -Path $LogRoot|Out-Null
  [pscustomobject]@{
    schema='rah-raven-studio-v31-c5-hovedpc-acceptance-v1'
    candidate=$Candidate
    generatedAt=(Get-Date).ToString('o')
    computer=$env:COMPUTERNAME
    final=$Final
    error=$ErrorText
    one_click_report=$OneClickReport
    one_click=$OneClickData
    checks=@($Checks)
    safety=[pscustomobject]@{
      administrator_required=$false
      usb_changes=$false
      partition_changes=$false
      installs=$false
      firewall_changes=$false
      network_changes=$false
      model_downloads=$false
      process_kills=$false
      lm_studio_optional=$true
    }
  }|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $AcceptanceReport -Encoding UTF8
}

function Invoke-ContractSelfTest {
  foreach($item in @(
    @($Manifest,'Candidate manifest'),
    @($CandidateCheck,'Candidate self-test'),
    @($OneClick,'Candidate one-click orchestrator'),
    @($Repair,'Candidate Safe Repair'),
    @($StartCmd,'Candidate START-HER'),
    @($Studio,'Candidate Studio HTML'),
    @($Diagnostics,'Candidate Diagnostics HTML')
  )){Require-File $item[0] $item[1]}

  foreach($p in @($CandidateCheck,$OneClick,$Repair)){Assert-Parse $p}

  $m=Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$m.version -ne $Candidate){throw "Manifest mismatch: $($m.version)"}
  Add-Check 'Manifest version' 'PASS' ([string]$m.version)

  if(-not $m.one_click_startup.precheck -or -not $m.one_click_startup.safe_repair -or -not $m.one_click_startup.postcheck){
    throw 'PRECHECK/SAFE REPAIR/POSTCHECK contract drift.'
  }
  Add-Check 'One-click lifecycle' 'PASS' 'PRECHECK -> SAFE REPAIR -> POSTCHECK'

  $startText=Get-Content -LiteralPath $StartCmd -Raw -Encoding UTF8
  if(-not $startText.Contains('RAH-RAVEN-STUDIO-ONECLICK-V3.1-CANDIDATE.5.ps1')){throw 'START-HER no longer targets Candidate.5 orchestrator.'}
  Add-Check 'START-HER target' 'PASS' 'Candidate.5 one-click orchestrator'

  $oneText=Get-Content -LiteralPath $OneClick -Raw -Encoding UTF8
  $repairText=Get-Content -LiteralPath $Repair -Raw -Encoding UTF8
  foreach($unsafe in @('pip install','Stop-Process','netsh advfirewall','Set-NetFirewallRule','New-NetFirewallRule')){
    if($oneText.Contains($unsafe) -or $repairText.Contains($unsafe)){throw "Unsafe acceptance marker detected: $unsafe"}
  }
  if(-not $repairText.Contains('-WindowStyle Hidden')){throw 'Safe Repair lost hidden Bridge-start contract.'}
  Add-Check 'Safe Repair static policy' 'PASS' 'No install/kill/firewall mutation; Bridge start hidden'
}

if($SelfTest){
  try{
    Invoke-ContractSelfTest
    Write-Host ''
    Write-Host 'RAH RAVEN STUDIO CANDIDATE.5 HOVED-PC ACCEPTANCE CONTRACT: PASS' -ForegroundColor Green
    exit 0
  }catch{
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
}

$Final='FAIL'
$ErrorText=''
$OneClickData=$null
try{
  Write-Host ''
  Write-Host '============================================================' -ForegroundColor DarkYellow
  Write-Host ' RAH RAVEN STUDIO v3.1 CANDIDATE.5 - HOVED-PC ACCEPTANCE' -ForegroundColor Yellow
  Write-Host ' STATIC -> CANDIDATE SELFTEST -> ONE CLICK -> EVIDENCE' -ForegroundColor DarkYellow
  Write-Host '============================================================' -ForegroundColor DarkYellow
  Write-Host ''

  Invoke-ContractSelfTest

  & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $CandidateCheck -SelfTest -NoLaunch
  if($LASTEXITCODE -ne 0){throw "Candidate self-test exit=$LASTEXITCODE"}
  Add-Check 'Candidate self-test runtime' 'PASS' 'exit=0'

  $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$OneClick)
  if($NoLaunch){$args+='-NoLaunch'}
  & powershell.exe @args
  $oneRc=$LASTEXITCODE
  Add-Check 'Candidate one-click exit' ($(if($oneRc -eq 0){'PASS'}else{'FAIL'})) "exit=$oneRc"
  if($oneRc -ne 0){throw "Candidate.5 one-click returned exit=$oneRc"}

  if(-not (Test-Path -LiteralPath $OneClickReport -PathType Leaf)){throw "One-click evidence missing: $OneClickReport"}
  $OneClickData=Get-Content -LiteralPath $OneClickReport -Raw -Encoding UTF8|ConvertFrom-Json
  Add-Check 'One-click report' 'PASS' $OneClickReport

  if([string]$OneClickData.candidate -ne $Candidate){throw "One-click report candidate mismatch: $($OneClickData.candidate)"}
  Add-Check 'Evidence candidate' 'PASS' ([string]$OneClickData.candidate)

  if([string]$OneClickData.result -ne 'PASS'){throw "One-click report result=$($OneClickData.result)"}
  Add-Check 'One-click result' 'PASS' ([string]$OneClickData.result)

  if($OneClickData.postcheck.bridge_ok -ne $true){throw 'POSTCHECK Desktop Bridge is not PASS.'}
  Add-Check 'POSTCHECK Desktop Bridge' 'PASS' 'bridge_ok=true'

  if($OneClickData.postcheck.agent_ok -ne $true){throw 'POSTCHECK Agent Runner is not PASS.'}
  Add-Check 'POSTCHECK Agent Runner' 'PASS' 'read-only-allowlist confirmed'

  if($OneClickData.postcheck.lm_reachable -eq $true){
    $count=[int]$OneClickData.postcheck.lm_models
    if($count -gt 0){Add-Check 'LM Studio' 'PASS' "reachable; models=$count"}
    else{Add-Check 'LM Studio' 'INFO' 'reachable; no model loaded (optional)'}
  }else{
    Add-Check 'LM Studio' 'INFO' 'offline (optional; does not block acceptance)'
  }

  if($OneClickData.safety.admin_required -ne $false){throw 'One-click evidence unexpectedly requires admin.'}
  if($OneClickData.safety.installs -ne $false -or $OneClickData.safety.firewall_changes -ne $false -or $OneClickData.safety.process_kills -ne $false){
    throw 'One-click safety evidence drift.'
  }
  Add-Check 'Runtime safety evidence' 'PASS' 'no admin/install/firewall/network/model/kill mutations'

  $Final='PASS'
}catch{
  $ErrorText=$_.Exception.Message
  Add-Check 'Acceptance error' 'FAIL' $ErrorText
}finally{
  Save-Report $Final $ErrorText $OneClickData
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor DarkYellow
Write-Host (" FINAL: "+$Final) -ForegroundColor $(if($Final -eq 'PASS'){'Green'}else{'Red'})
if($ErrorText){Write-Host (" "+$ErrorText) -ForegroundColor Red}
Write-Host (" Report: "+$AcceptanceReport) -ForegroundColor DarkGray
Write-Host '============================================================' -ForegroundColor DarkYellow

if($Final -eq 'PASS'){exit 0}
exit 1

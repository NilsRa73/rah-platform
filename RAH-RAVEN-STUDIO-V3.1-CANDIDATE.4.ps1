[CmdletBinding()]
param([switch]$SelfTest,[switch]$NoLaunch)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$Html=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.html'
$Diag=Join-Path $Root 'RAH-RAVEN-STUDIO-DIAGNOSTICS-V3.1-CANDIDATE.4.html'
$Manifest=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.json'
$Repair=Join-Path $Root 'SAFE-REPAIR-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.ps1'

function Require([bool]$Ok,[string]$Message){if(-not $Ok){throw $Message};Write-Host "[PASS] $Message"}

try{
  foreach($p in @($Html,$Diag,$Manifest,$Repair)){Require (Test-Path -LiteralPath $p -PathType Leaf) "Exists: $([IO.Path]::GetFileName($p))"}
  $m=Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8|ConvertFrom-Json
  Require ([string]$m.version -eq '3.1.0-candidate.4') 'Candidate.4 manifest version'
  Require ([int]$m.diagnostics_contract.bridge_timeout_ms -eq 2500) 'Diagnostics Bridge timeout 2500ms'
  Require ($m.safe_repair.install_dependencies -eq $false) 'Safe Repair installs disabled'
  Require ($m.safe_repair.firewall_changes -eq $false) 'Safe Repair firewall changes disabled'
  Require ($m.safe_repair.process_kills -eq $false) 'Safe Repair process kills disabled'
  $d=Get-Content -LiteralPath $Diag -Raw -Encoding UTF8
  foreach($needle in @('App Launch','Desktop Bridge','LM Studio','Agent Runner','Root cause','SAFE REPAIR','RETEST FAILED ONLY','SAVE JSON','AbortController')){
    Require ($d.Contains($needle)) "Diagnostics marker: $needle"
  }
  $r=Get-Content -LiteralPath $Repair -Raw -Encoding UTF8
  Require ($r.Contains('-WindowStyle Hidden')) 'Bridge background start is hidden'
  Require (-not $r.Contains('pip install')) 'Repair does not install dependencies'
  Require (-not $r.Contains('Stop-Process')) 'Repair does not kill processes'
  Write-Host 'RAH RAVEN STUDIO v3.1 CANDIDATE.4 SELF-TEST: PASS'
  if(-not $SelfTest -and -not $NoLaunch){Start-Process -FilePath $Html}
  exit 0
}catch{Write-Host "[FAIL] $($_.Exception.Message)";exit 1}

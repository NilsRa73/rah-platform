[CmdletBinding()]
param([switch]$SelfTest,[switch]$NoLaunch)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$Html=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.3.html'
$Manifest=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.3.json'

function Require([bool]$Ok,[string]$Message){
  if(-not $Ok){throw $Message}
  Write-Host "[PASS] $Message"
}

try{
  Require (Test-Path -LiteralPath $Html -PathType Leaf) 'Candidate HTML finnes'
  Require (Test-Path -LiteralPath $Manifest -PathType Leaf) 'Candidate manifest finnes'
  $m=Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
  Require ([string]$m.version -eq '3.1.0-candidate.3') 'Versjon 3.1.0-candidate.3'
  Require ([string]$m.stage -eq 'candidate') 'Stage candidate'
  Require ([int]$m.launch_lifecycle.bridge_preflight_timeout_ms -eq 2500) 'Bridge-timeout 2500 ms'
  $h=Get-Content -LiteralPath $Html -Raw -Encoding UTF8
  foreach($needle in @('STARTER','STARTET','FEILET','LAUNCH_STATE_KEY','AbortController','http://127.0.0.1:18765/health')){
    Require ($h.Contains($needle)) "HTML contract: $needle"
  }
  Require (-not $h.Contains('https://')) 'Ingen eksterne HTTPS runtime-lenker'
  Write-Host 'RAH RAVEN STUDIO v3.1 CANDIDATE.3 SELF-TEST: PASS'
  if(-not $SelfTest -and -not $NoLaunch){Start-Process -FilePath $Html}
  exit 0
}catch{
  Write-Host "[FAIL] $($_.Exception.Message)"
  exit 1
}

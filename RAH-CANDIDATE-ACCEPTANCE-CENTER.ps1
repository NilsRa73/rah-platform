[CmdletBinding()]
param([switch]$SelfTest)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=$PSScriptRoot

function Read-Manifest([string]$Relative){
  $path=Join-Path $Root ($Relative -replace '/', [IO.Path]::DirectorySeparatorChar)
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing lifecycle manifest: $Relative"}
  return Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
}

$Studio29=Read-Manifest 'RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json'
$Studio30=Read-Manifest 'RAH-RAVEN-STUDIO-V3.0.json'
$Daily=Read-Manifest 'RAH-RAVEN-DAILY-DRIVER-VERSION.json'
$Investigator=Read-Manifest 'apps/rah-ai-investigator/RAH-INVESTIGATOR-VERSION.json'

if([string]$Studio29.stage -ne 'retired' -or [string]$Studio29.superseded_by.version -ne '3.0.0'){
  throw 'Studio 2.9 retirement state drift.'
}
if([string]$Studio30.stage -ne 'stable' -or [string]$Studio30.release_gate.status -ne 'passed'){
  throw 'Studio 3.0 Stable state drift.'
}
if([string]$Daily.stage -ne 'stable' -or [string]$Daily.stable_gate.status -ne 'passed'){
  throw 'Daily Driver Stable state drift.'
}
if([string]$Investigator.stage -ne 'stable' -or $Investigator.validation.stable_release_gate -ne $true){
  throw 'AI Investigator Stable state drift.'
}

Write-Host '==============================================================' -ForegroundColor DarkYellow
Write-Host ' RAH CANDIDATE ACCEPTANCE CENTER - STATUS' -ForegroundColor Yellow
Write-Host '==============================================================' -ForegroundColor DarkYellow
Write-Host 'No current Candidate in this owned-machine acceptance queue.' -ForegroundColor Green
Write-Host ''
Write-Host ' Studio 2.9      : RETIRED -> Studio 3.0 Stable'
Write-Host ' Studio 3.0      : STABLE / release gate passed'
Write-Host ' Daily Driver 1.0: STABLE / gate passed'
Write-Host ' Investigator 1.0: STABLE / release gate passed'
Write-Host ''
Write-Host 'No Candidate launcher is exposed while the queue is empty.'

if($SelfTest){
  Write-Host 'PASS  Candidate Acceptance Center empty-queue lifecycle self-test.'
}
exit 0

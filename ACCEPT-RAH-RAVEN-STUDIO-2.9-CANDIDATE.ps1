[CmdletBinding()]
param(
    [switch]$NonInteractive,
    [switch]$NoLaunch,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$LegacyManifest=Join-Path $Root 'RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json'
$StableManifest=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.0.json'
$Finalizer=Join-Path $Root 'RAH-RAVEN-STUDIO-FINAL.ps1'
$Launcher=Join-Path $Root 'START-HER-RAH-RAVEN-STUDIO.cmd'

function Require-File([string]$Path,[string]$Label){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "$Label missing: $Path"}
}

Require-File $LegacyManifest 'Studio 2.9 retirement manifest'
Require-File $StableManifest 'Studio 3.0 Stable manifest'
Require-File $Finalizer 'Studio 3.0 Stable finalizer'
Require-File $Launcher 'Studio 3.0 one-click launcher'

$Legacy=Get-Content -LiteralPath $LegacyManifest -Raw -Encoding UTF8|ConvertFrom-Json
$Stable=Get-Content -LiteralPath $StableManifest -Raw -Encoding UTF8|ConvertFrom-Json

if([string]$Legacy.version -ne '2.9.0' -or [string]$Legacy.stage -ne 'retired'){
    throw "Studio 2.9 retirement contract drift: $($Legacy.version) / $($Legacy.stage)"
}
if([string]$Legacy.superseded_by.version -ne '3.0.0' -or $Legacy.promotion_policy.retired_no_promotion -ne $true){
    throw 'Studio 2.9 supersession/no-promotion contract drift.'
}
if([string]$Stable.version -ne '3.0.0' -or [string]$Stable.stage -ne 'stable' -or [string]$Stable.release_gate.status -ne 'passed'){
    throw "Studio 3.0 Stable contract drift: $($Stable.version) / $($Stable.stage)"
}

Write-Host '============================================================' -ForegroundColor DarkYellow
Write-Host 'RAH RAVEN STUDIO 2.9 - RETIRED COMPATIBILITY' -ForegroundColor Yellow
Write-Host '============================================================' -ForegroundColor DarkYellow
Write-Host 'Studio 2.9 is historical. No 2.9 promotion or owned-machine acceptance is performed.' -ForegroundColor Yellow
Write-Host 'Forwarding to canonical Raven Studio 3.0 Stable finalizer.'
Write-Host ''

$Args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$Finalizer)
if($SelfTest){
    $Args+='-SelfTest'
}elseif($NonInteractive -or $NoLaunch){
    $Args+='-NoLaunch'
}

& powershell.exe @Args
$Rc=$LASTEXITCODE
if($Rc -eq 0){
    Write-Host '[PASS] Studio 3.0 Stable finalizer completed through the legacy 2.9 entry point.' -ForegroundColor Green
}else{
    Write-Host "[FAIL] Studio 3.0 Stable finalizer returned exit code $Rc." -ForegroundColor Red
}
exit $Rc

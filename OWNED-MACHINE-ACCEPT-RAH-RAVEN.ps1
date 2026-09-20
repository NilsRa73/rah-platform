[CmdletBinding()]
param(
    [string]$FacebookArchive,
    [switch]$NonInteractive,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Manifest = Join-Path $Root 'RAH-RAVEN-DAILY-DRIVER-VERSION.json'
$Finalizer = Join-Path $Root 'RAH-RAVEN-DAILY-DRIVER-FINAL.ps1'
$StableLauncher = Join-Path $Root 'START-HER-RAH-RAVEN-DAILY-DRIVER.cmd'

function Require-File([string]$Path,[string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label missing: $Path"
    }
}

Require-File $Manifest 'Daily Driver Stable manifest'
Require-File $Finalizer 'Daily Driver Stable finalizer'
Require-File $StableLauncher 'Daily Driver Stable one-click launcher'

$State = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]$State.product -ne 'RAH Raven Daily Driver' -or [string]$State.version -ne '1.0.0') {
    throw 'Unexpected Daily Driver identity/version.'
}
if ([string]$State.stage -ne 'stable' -or [string]$State.stable_gate.status -ne 'passed') {
    throw "Legacy compatibility refuses non-Stable lifecycle state: $($State.stage) / $($State.stable_gate.status)"
}
if ([string]$State.authority_delta -ne 'none') {
    throw 'Daily Driver authority boundary drift.'
}

Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'RAH RAVEN DAILY DRIVER - LEGACY ACCEPTANCE COMPATIBILITY' -ForegroundColor Yellow
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'Daily Driver 1.0 is already Stable. Candidate acceptance is retired.' -ForegroundColor Yellow
Write-Host 'Forwarding to the canonical Stable self-diagnosing finalizer.'
Write-Host ''

if (-not [string]::IsNullOrWhiteSpace($FacebookArchive)) {
    Write-Host '[INFO] The old archive argument is no longer a release requirement.' -ForegroundColor Cyan
    Write-Host '[INFO] It is intentionally not opened, copied, hashed, or persisted by this compatibility wrapper.' -ForegroundColor Cyan
}

$Args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$Finalizer)
if ($SelfTest) {
    $Args += '-SelfTest'
} elseif ($NonInteractive) {
    $Args += '-NoLaunch'
}

& powershell.exe @Args
$Rc = $LASTEXITCODE

if ($Rc -eq 0) {
    Write-Host '[PASS] Canonical Stable finalizer completed through the legacy entry point.' -ForegroundColor Green
} else {
    Write-Host "[FAIL] Canonical Stable finalizer returned exit code $Rc." -ForegroundColor Red
}
exit $Rc

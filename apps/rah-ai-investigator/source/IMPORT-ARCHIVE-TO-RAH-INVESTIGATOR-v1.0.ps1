param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Helper = Join-Path $Root 'rah_investigator.py'
if (-not (Test-Path -LiteralPath $Helper -PathType Leaf)) { throw 'Bundled Investigator Python helper is missing' }
if (-not (Test-Path -LiteralPath $InputPath)) { throw 'Input path does not exist' }

$InputResolved = (Resolve-Path -LiteralPath $InputPath).Path
$OutputParent = Split-Path -Parent $OutputPath
if ([string]::IsNullOrWhiteSpace($OutputParent)) { $OutputParent = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $OutputParent -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputParent -Force | Out-Null
}
$OutputResolved = Join-Path (Resolve-Path -LiteralPath $OutputParent).Path (Split-Path -Leaf $OutputPath)

$Python = Get-Command python -ErrorAction SilentlyContinue
if ($Python) {
    & $Python.Source $Helper normalize $InputResolved --out $OutputResolved
} else {
    $Py = Get-Command py -ErrorAction SilentlyContinue
    if (-not $Py) { throw 'Python 3 was not found on PATH' }
    & $Py.Source -3 $Helper normalize $InputResolved --out $OutputResolved
}
if ($LASTEXITCODE -ne 0) { throw "Archive normalization failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $OutputResolved -PathType Leaf)) { throw 'Expected Case JSON was not created' }

Write-Host "Case JSON created: $OutputResolved"
Write-Host 'Source files were not modified or deleted.'

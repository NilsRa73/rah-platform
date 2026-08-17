$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Required = @(
    'RAH-AI-INVESTIGATOR.html',
    'rah_investigator.py',
    'RAH-INVESTIGATOR-VERSION.json',
    'CHECK-RAH-INVESTIGATOR-KALI.sh',
    'RUN-ME-FIRST-RAH-INVESTIGATOR.bat'
)

foreach ($Name in $Required) {
    $Path = Join-Path $Root $Name
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing required Investigator file: $Name"
    }
}

$ManifestPath = Join-Path $Root 'RAH-INVESTIGATOR-VERSION.json'
$Manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Manifest.product -ne 'RAH AI Investigator') { throw 'Unexpected product in version manifest' }
if ($Manifest.version -ne '1.0-RC2') { throw 'Unexpected Investigator version' }
if ($Manifest.stage -ne 'candidate') { throw 'Investigator must remain Candidate' }
if ($Manifest.scope -ne 'personal account recovery and authorized personal OSINT') { throw 'Unexpected Investigator scope' }
if ($Manifest.local_first -ne $true) { throw 'local_first must be true' }
if ($Manifest.paid_services_required -ne $false) { throw 'paid_services_required must be false' }
if ($Manifest.validation.stable_release_gate -ne $false) { throw 'Stable release gate must remain false in RC2' }

$Python = Get-Command python -ErrorAction SilentlyContinue
if ($Python) {
    & $Python.Source (Join-Path $Root 'rah_investigator.py') self-test
} else {
    $Py = Get-Command py -ErrorAction SilentlyContinue
    if (-not $Py) { throw 'Python 3 was not found on PATH' }
    & $Py.Source -3 (Join-Path $Root 'rah_investigator.py') self-test
}
if ($LASTEXITCODE -ne 0) { throw "Investigator Python self-test failed with exit code $LASTEXITCODE" }

Write-Host 'RAH AI Investigator v1.0 RC2 Windows local self-check PASS'

param(
 [Parameter(Mandatory=$true)][string]$NodeAddress,
 [ValidateRange(1024,65535)][int]$Port=18766,
 [ValidateSet('health','systemInfo','benchmark')][string]$Job='health'
)
$ErrorActionPreference='Stop'
$client=Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1'
if(-not (Test-Path -LiteralPath $client)){throw 'RAH-HOME-NODE-CLIENT.ps1 mangler i samme mappe.'}
Write-Host "RAH HOME NODE JOB -> $NodeAddress`:$Port / $Job" -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $NodeAddress -Port $Port -Action $Job
if($LASTEXITCODE -ne 0){throw "Node-jobben feilet med exit code $LASTEXITCODE"}

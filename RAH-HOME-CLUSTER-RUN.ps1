param(
 [Parameter(Mandatory=$true)][string]$NodeAddress,
 [ValidateRange(1024,65535)][int]$Port=18766,
 [ValidateSet('health','systemInfo','benchmark')][string]$Job='health'
)
$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'RAH-HOME-NODE-JOB.ps1'
if(-not(Test-Path -LiteralPath $runner)){throw 'RAH-HOME-NODE-JOB.ps1 mangler i samme mappe.'}
Write-Host ''
Write-Host 'RAH HOME CLUSTER JOB' -ForegroundColor Yellow
Write-Host "Node: $NodeAddress`:$Port"
Write-Host "Tillatt jobb: $Job"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -NodeAddress $NodeAddress -Port $Port -Job $Job
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}

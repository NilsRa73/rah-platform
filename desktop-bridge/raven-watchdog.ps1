[CmdletBinding()]
param([switch]$Startup)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Port = 18765
$RuntimeRoot = 'C:\RAH\Raven\rah-platform'
$BridgeDir = Join-Path $RuntimeRoot 'desktop-bridge'
$Python = Join-Path $BridgeDir '.venv\Scripts\python.exe'
$LogDir = 'C:\RAH\Logs\RavenBridge'
$StateDir = 'C:\RAH\State\RavenBridge'
New-Item -ItemType Directory -Path $LogDir,$StateDir -Force | Out-Null
$Log = Join-Path $LogDir 'watchdog.log'

function Write-Log([string]$Text) {
    Add-Content -LiteralPath $Log -Value ("$(Get-Date -Format o) $Text") -Encoding UTF8
}
function Get-Health {
    try { Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 } catch { $null }
}
function Test-Green($Health) {
    if ($null -eq $Health) { return $false }
    foreach ($name in @('ok','council_proxy','vision_monitor_capture','local_device_adapter')) {
        $p = $Health.PSObject.Properties[$name]
        if ($null -eq $p -or $p.Value -ne $true) { return $false }
    }
    return $true
}

if ($Startup) { Start-Sleep -Seconds 8 }
if (-not (Test-Path (Join-Path $BridgeDir 'raven_bridge.py'))) { Write-Log "Runtime missing: $BridgeDir"; exit 3 }
if (-not (Test-Path $Python)) { Write-Log "Python venv missing: $Python"; exit 4 }

$health = Get-Health
if (Test-Green $health) { Write-Log 'Health already GREEN.'; exit 0 }

$listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
if ($listeners.Count -gt 0) {
    Write-Log "Port $Port is occupied but health is not GREEN. No automatic termination performed."
    exit 5
}

$env:RAH_CHRONICLE_DIR = 'C:\RAH\Data\Chronicle'
$env:RAH_DOWNLOAD_MANAGER_STATE = 'C:\RAH\Data\DownloadManager\state.json'
$env:RAH_RAVEN_VAULT = 'C:\RAH\Data\Vault'
$env:RAH_DOWNLOADS_DIR = 'C:\RAH\Data\Incoming'
New-Item -ItemType Directory -Path $env:RAH_CHRONICLE_DIR,$env:RAH_RAVEN_VAULT,$env:RAH_DOWNLOADS_DIR,(Split-Path $env:RAH_DOWNLOAD_MANAGER_STATE -Parent) -Force | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outLog = Join-Path $LogDir "watchdog-bridge-$stamp.out.log"
$errLog = Join-Path $LogDir "watchdog-bridge-$stamp.err.log"
$bridge = Start-Process -FilePath $Python -ArgumentList 'raven_bridge.py' -WorkingDirectory $BridgeDir -WindowStyle Hidden -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
Write-Log "Started Raven Bridge PID $($bridge.Id)."

$health = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    if ($bridge.HasExited) { break }
    $candidate = Get-Health
    if (Test-Green $candidate) { $health = $candidate; break }
}
if (-not (Test-Green $health)) { Write-Log "Start failed. stderr=$errLog"; exit 6 }

[ordered]@{green=$true;timestamp=(Get-Date).ToString('o');pid=$bridge.Id;port=$Port;source='watchdog'} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $StateDir 'watchdog.json') -Encoding UTF8
Write-Log "GREEN on PID $($bridge.Id)."
exit 0

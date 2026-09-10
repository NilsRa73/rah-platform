[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$NoRestart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SourceBranch = 'agent/raven-vision-monitor-chatgpt-bridge'
$ExpectedRepo = 'NilsRa73/rah-platform'
$BridgePort = 18765
$BridgeDir = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path -Parent $BridgeDir
$CanonicalPaths = @(
    'desktop-bridge/raven_bridge.py',
    'desktop-bridge/server_v16.py',
    'desktop-bridge/server_v17.py',
    'desktop-bridge/chronicle_insights.py',
    'desktop-bridge/chronicle_ai.py',
    'desktop-bridge/agent_runner.py',
    'desktop-bridge/download_manager.py',
    'desktop-bridge/local_device_adapter.py',
    'desktop-bridge/doctor.py',
    'desktop-bridge/start-bridge.bat',
    'desktop-bridge/start-raven-vision.bat',
    'desktop-bridge/test_raven_bridge_security.py',
    'desktop-bridge/requirements.txt',
    'RAH-RAVEN-VISION-LOCAL.html',
    'RAH-RAVEN-CHATGPT.user.js',
    'RAH-HOME-CONTROL.html',
    'RAH-RAVEN-CHRONICLE-LIVE.html',
    'RAH-RAVEN-INSIGHTS.html',
    'RAH-RAVEN-DAILY-BRIEF.html',
    'RAH-RAVEN-DOWNLOADS.html'
)

function Write-Step([string]$Text) {
    Write-Host "[RAH] $Text" -ForegroundColor Cyan
}

function Assert-Repository {
    if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
        throw "Auto-repair stopped: $RepoRoot is not a Git working tree."
    }
    $origin = (& git -C $RepoRoot remote get-url origin 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $origin) {
        throw 'Auto-repair stopped: Git origin could not be read.'
    }
    if ($origin -notmatch '(?i)(github\.com[:/])NilsRa73/rah-platform(?:\.git)?$') {
        throw "Auto-repair stopped: unexpected Git origin '$origin'."
    }
}

function Get-Python {
    $venvPython = Join-Path $BridgeDir '.venv\Scripts\python.exe'
    if (Test-Path $venvPython) { return $venvPython }

    Write-Step 'Creating isolated Python environment...'
    if (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 -m venv (Join-Path $BridgeDir '.venv')
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        & python -m venv (Join-Path $BridgeDir '.venv')
    } else {
        throw 'Python was not found. Install Python 3.11 or newer.'
    }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $venvPython)) {
        throw 'Python virtual environment could not be created.'
    }
    return $venvPython
}

function Ensure-Dependencies([string]$Python) {
    & $Python -c 'import flask, flask_cors, mss, PIL, pypdf' 2>$null
    if ($LASTEXITCODE -eq 0) { return }
    Write-Step 'Installing pinned Raven Bridge dependencies...'
    & $Python -m pip install --disable-pip-version-check -r (Join-Path $BridgeDir 'requirements.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
}

function Invoke-SecurityTest([string]$Python) {
    Push-Location $BridgeDir
    try {
        & $Python 'test_raven_bridge_security.py'
        return ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
}

function Test-StaleLocalImport {
    $entry = Join-Path $BridgeDir 'raven_bridge.py'
    if (-not (Test-Path $entry)) { return $true }
    return [bool](Select-String -LiteralPath $entry -Pattern 'hovedpc_local_status' -SimpleMatch -Quiet)
}

function Get-BridgeHealth {
    try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:$BridgePort/health" -TimeoutSec 2
        return $health
    } catch {
        return $null
    }
}

function Test-ExpectedHealth($Health) {
    if ($null -eq $Health) { return $false }
    return ($Health.ok -eq $true -and
            $Health.council_proxy -eq $true -and
            $Health.vision_monitor_capture -eq $true -and
            $Health.local_device_adapter -eq $true)
}

function New-Backup {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $root = "C:\RAH\Backups\RavenBridge\$stamp"
    try {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    } catch {
        $root = Join-Path $RepoRoot ".rah-runtime\Backups\RavenBridge\$stamp"
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }

    foreach ($relative in $CanonicalPaths) {
        $source = Join-Path $RepoRoot ($relative -replace '/', '\')
        if (-not (Test-Path $source -PathType Leaf)) { continue }
        $target = Join-Path $root ($relative -replace '/', '\')
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    return $root
}

function Sync-CanonicalFiles {
    Write-Step "Fetching canonical Bridge source: $SourceBranch"
    & git -C $RepoRoot fetch --quiet origin $SourceBranch
    if ($LASTEXITCODE -ne 0) { throw 'Git fetch failed; no local files were replaced.' }

    $backup = New-Backup
    Write-Step "Backup saved to $backup"
    & git -C $RepoRoot checkout "origin/$SourceBranch" -- @CanonicalPaths
    if ($LASTEXITCODE -ne 0) { throw "Canonical file restore failed. Backup: $backup" }
    return $backup
}

function Stop-OwnedBridgeProcess {
    $listeners = @(Get-NetTCPConnection -LocalPort $BridgePort -State Listen -ErrorAction SilentlyContinue)
    foreach ($listener in $listeners) {
        $pidValue = [int]$listener.OwningProcess
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$pidValue" -ErrorAction SilentlyContinue
        $commandLine = [string]$proc.CommandLine
        if (-not $commandLine -or $commandLine -notmatch 'raven_bridge\.py' -or $commandLine -notlike "*$BridgeDir*") {
            throw "Port $BridgePort is owned by PID $pidValue, but it is not this Raven Bridge. Refusing to terminate it."
        }
        Write-Step "Stopping stale Raven Bridge PID $pidValue..."
        Stop-Process -Id $pidValue -Force -ErrorAction Stop
    }
}

function Start-Bridge([string]$Python) {
    $logRoot = 'C:\RAH\Logs\RavenBridge'
    try {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    } catch {
        $logRoot = Join-Path $RepoRoot '.rah-runtime\Logs\RavenBridge'
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $stdout = Join-Path $logRoot "bridge-$stamp.out.log"
    $stderr = Join-Path $logRoot "bridge-$stamp.err.log"

    Stop-OwnedBridgeProcess
    Write-Step 'Starting canonical Raven Bridge on 127.0.0.1:18765...'
    Start-Process -FilePath $Python -ArgumentList 'raven_bridge.py' -WorkingDirectory $BridgeDir -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr | Out-Null

    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 500
        $health = Get-BridgeHealth
        if (Test-ExpectedHealth $health) {
            return @{ Health = $health; Stdout = $stdout; Stderr = $stderr }
        }
    }
    throw "Bridge did not become healthy. Check $stderr"
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Yellow
Write-Host ' RAH RAVEN BRIDGE - GUARDED AUTO-REPAIR' -ForegroundColor Yellow
Write-Host '============================================================' -ForegroundColor Yellow

Assert-Repository
$python = Get-Python
Ensure-Dependencies $python

$staleImport = Test-StaleLocalImport
$securityOK = Invoke-SecurityTest $python
$healthBefore = Get-BridgeHealth
$runtimeOK = Test-ExpectedHealth $healthBefore

Write-Host "Source security test : $(if ($securityOK) {'PASS'} else {'FAIL'})"
Write-Host "Stale local import   : $(if ($staleImport) {'FOUND'} else {'NO'})"
Write-Host "Runtime health       : $(if ($runtimeOK) {'PASS'} else {'NOT READY'})"

if ($CheckOnly) {
    if ($securityOK -and -not $staleImport -and $runtimeOK) {
        Write-Host 'RESULT: GREEN - no repair needed.' -ForegroundColor Green
        exit 0
    }
    Write-Host 'RESULT: YELLOW - repair/restart is required.' -ForegroundColor Yellow
    exit 2
}

$backup = $null
if (-not $securityOK -or $staleImport) {
    $backup = Sync-CanonicalFiles
    Ensure-Dependencies $python
    if (-not (Invoke-SecurityTest $python)) {
        throw "Canonical security/self-test still fails. Original files are backed up at $backup"
    }
    if (Test-StaleLocalImport) {
        throw 'Canonical entrypoint still contains the retired hovedpc_local_status dependency.'
    }
    $runtimeOK = $false
}

if ($NoRestart) {
    Write-Host 'SOURCE RESULT: GREEN - canonical files and tests pass.' -ForegroundColor Green
    Write-Host 'RUNTIME RESULT: YELLOW - restart intentionally skipped.' -ForegroundColor Yellow
    exit 2
}

if (-not $runtimeOK) {
    $started = Start-Bridge $python
    $runtimeOK = Test-ExpectedHealth $started.Health
}

$finalSecurity = Invoke-SecurityTest $python
$finalHealth = Get-BridgeHealth
$finalRuntime = Test-ExpectedHealth $finalHealth

if ($finalSecurity -and $finalRuntime -and -not (Test-StaleLocalImport)) {
    Write-Host ''
    Write-Host 'RESULT: GREEN' -ForegroundColor Green
    Write-Host 'Raven Bridge source, security test and live health are all PASS.' -ForegroundColor Green
    Write-Host 'Endpoint: http://127.0.0.1:18765/health'
    if ($backup) { Write-Host "Backup: $backup" }
    exit 0
}

throw 'Final Raven Bridge verification did not reach GREEN.'

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Commit = '0634428389c475a6f595a8d8d3906f0bfcda1658'
$Port = 18765
$RuntimeParent = 'C:\RAH\Raven'
$RuntimeRoot = Join-Path $RuntimeParent 'rah-platform'
$BridgeDir = Join-Path $RuntimeRoot 'desktop-bridge'
$StateDir = 'C:\RAH\State\RavenBridge'
$LogDir = 'C:\RAH\Logs\RavenBridge'
$BackupParent = 'C:\RAH\Backups\RavenBridgeRuntime'

function Write-Step([string]$Text) {
    Write-Host "[RAH] $Text" -ForegroundColor Cyan
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Fail([string]$Message) {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host ' RAVEN BRIDGE - NOT GREEN' -ForegroundColor Red
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
    throw $Message
}

if (-not (Test-IsAdmin)) {
    if (-not $PSCommandPath) {
        Fail 'Administrator elevation is required, but this script has no file path for self-elevation.'
    }
    Write-Host '[RAH] Requesting Administrator access...' -ForegroundColor Yellow
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $PSCommandPath + '"'))
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $args | Out-Null
    exit 0
}

New-Item -ItemType Directory -Path $RuntimeParent,$StateDir,$LogDir,$BackupParent -Force | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runLog = Join-Path $LogDir "bootstrap-$stamp.log"
try { Start-Transcript -Path $runLog -Force | Out-Null } catch {}

try {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Yellow
    Write-Host ' RAH RAVEN BRIDGE - HOVED-PC TRUE GREEN BOOTSTRAP' -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor Yellow
    Write-Host ''

    Write-Step '1/8 Checking port 18765 and stopping only an existing Raven Bridge...'
    $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    foreach ($listener in $listeners) {
        $pidValue = [int]$listener.OwningProcess
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$pidValue" -ErrorAction SilentlyContinue
        $commandLine = [string]$proc.CommandLine
        if (-not $commandLine -or $commandLine -notmatch 'raven_bridge\.py') {
            Fail "Port $Port is owned by PID $pidValue, but it is not Raven Bridge. Refusing to terminate it."
        }
        Write-Step "Stopping existing Raven Bridge PID $pidValue..."
        Stop-Process -Id $pidValue -Force -ErrorAction Stop
    }
    Start-Sleep -Seconds 1

    Write-Step '2/8 Downloading the exact CI-tested Raven source commit...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $temp = Join-Path $env:TEMP ("rah-raven-green-" + [guid]::NewGuid().ToString('N'))
    $zip = Join-Path $temp 'rah-platform.zip'
    $extract = Join-Path $temp 'extract'
    New-Item -ItemType Directory -Path $temp,$extract -Force | Out-Null
    $url = "https://github.com/NilsRa73/rah-platform/archive/$Commit.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 1024) {
        Fail 'Downloaded Raven source archive is missing or unexpectedly small.'
    }
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $sourceRoot = Get-ChildItem -Path $extract -Directory | Select-Object -First 1
    if (-not $sourceRoot) { Fail 'Could not unpack the Raven source archive.' }
    $sourceBridge = Join-Path $sourceRoot.FullName 'desktop-bridge\raven_bridge.py'
    if (-not (Test-Path $sourceBridge)) { Fail 'Canonical raven_bridge.py is missing from the downloaded commit.' }
    $sourceText = Get-Content -LiteralPath $sourceBridge -Raw
    foreach ($requiredText in @('local_device_adapter','vision_monitor_capture','council_proxy')) {
        if ($sourceText -notmatch [regex]::Escape($requiredText)) {
            Fail "Downloaded Raven source failed canonical marker check: $requiredText"
        }
    }
    if ($sourceText -match 'hovedpc_local_status') {
        Fail 'Downloaded source unexpectedly contains the retired hovedpc_local_status dependency.'
    }

    Write-Step '3/8 Backing up the previous standardized runtime, if present...'
    if (Test-Path $RuntimeRoot) {
        $backup = Join-Path $BackupParent $stamp
        Move-Item -LiteralPath $RuntimeRoot -Destination $backup -Force
        Write-Step "Previous runtime moved to $backup"
    }

    Write-Step '4/8 Installing canonical runtime under C:\RAH\Raven\rah-platform...'
    New-Item -ItemType Directory -Path $RuntimeParent -Force | Out-Null
    Move-Item -LiteralPath $sourceRoot.FullName -Destination $RuntimeRoot -Force
    if (-not (Test-Path (Join-Path $BridgeDir 'raven_bridge.py'))) {
        Fail 'Raven runtime install did not produce desktop-bridge\raven_bridge.py.'
    }

    Write-Step '5/8 Creating Python environment and installing pinned dependencies...'
    $venv = Join-Path $BridgeDir '.venv'
    $python = Join-Path $venv 'Scripts\python.exe'
    if (-not (Test-Path $python)) {
        if (Get-Command py -ErrorAction SilentlyContinue) {
            & py -3 -m venv $venv
        } elseif (Get-Command python -ErrorAction SilentlyContinue) {
            & python -m venv $venv
        } else {
            Fail 'Python 3 was not found. Install Python 3.11 or newer and run this bootstrap again.'
        }
    }
    if (-not (Test-Path $python)) { Fail 'Python virtual environment could not be created.' }
    & $python -m pip install --disable-pip-version-check -r (Join-Path $BridgeDir 'requirements.txt')
    if ($LASTEXITCODE -ne 0) { Fail 'Raven dependency installation failed.' }

    Write-Step '6/8 Compiling core modules and running Raven security regression tests...'
    $compileTargets = @(
        'raven_bridge.py','doctor.py','server_v16.py','server_v17.py',
        'agent_runner.py','download_manager.py','local_device_adapter.py'
    ) | ForEach-Object { Join-Path $BridgeDir $_ }
    & $python -m py_compile @compileTargets
    if ($LASTEXITCODE -ne 0) { Fail 'Python compile verification failed.' }

    $dataRoot = 'C:\RAH\Data'
    $env:RAH_CHRONICLE_DIR = Join-Path $dataRoot 'Chronicle'
    $env:RAH_DOWNLOAD_MANAGER_STATE = Join-Path $dataRoot 'DownloadManager\state.json'
    $env:RAH_RAVEN_VAULT = Join-Path $dataRoot 'Vault'
    $env:RAH_DOWNLOADS_DIR = Join-Path $dataRoot 'Incoming'
    New-Item -ItemType Directory -Path $env:RAH_CHRONICLE_DIR,$env:RAH_RAVEN_VAULT,$env:RAH_DOWNLOADS_DIR,(Split-Path $env:RAH_DOWNLOAD_MANAGER_STATE -Parent) -Force | Out-Null

    Push-Location $BridgeDir
    try {
        & $python 'test_raven_bridge_security.py'
        if ($LASTEXITCODE -ne 0) { Fail 'Raven Bridge security regression test failed.' }
    } finally {
        Pop-Location
    }

    Write-Step '7/8 Starting canonical Raven Bridge...'
    $outLog = Join-Path $LogDir "bridge-$stamp.out.log"
    $errLog = Join-Path $LogDir "bridge-$stamp.err.log"
    $bridgeProc = Start-Process -FilePath $python -ArgumentList 'raven_bridge.py' -WorkingDirectory $BridgeDir -WindowStyle Hidden -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
    if (-not $bridgeProc) { Fail 'Raven Bridge process was not created.' }

    Write-Step '8/8 Running live health, Vision and Device API gates...'
    $health = $null
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 500
        if ($bridgeProc.HasExited) { break }
        try {
            $candidate = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2
            if ($candidate.ok -eq $true) {
                $health = $candidate
                break
            }
        } catch {}
    }
    if ($null -eq $health) {
        if (Test-Path $errLog) {
            Write-Host ''
            Write-Host '--- bridge stderr ---' -ForegroundColor Yellow
            Get-Content -LiteralPath $errLog -Tail 80
        }
        Fail 'Raven Bridge did not reach live /health.'
    }

    $requiredHealth = @('ok','council_proxy','vision_monitor_capture','local_device_adapter')
    $failed = @()
    foreach ($name in $requiredHealth) {
        $property = $health.PSObject.Properties[$name]
        if ($null -ne $property -and $property.Value -eq $true) {
            Write-Host ("[PASS] {0}" -f $name) -ForegroundColor Green
        } else {
            $failed += $name
            $value = if ($null -eq $property) { 'MISSING' } else { [string]$property.Value }
            Write-Host ("[FAIL] {0} = {1}" -f $name,$value) -ForegroundColor Red
        }
    }
    if ($failed.Count -gt 0) {
        $health | ConvertTo-Json -Depth 8 | Write-Host
        Fail ("Live health gate failed: " + ($failed -join ', '))
    }

    $monitors = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/capture/monitors" -TimeoutSec 5
    if ($monitors.ok -ne $true -or [int]$monitors.count -lt 1) {
        Fail 'Raven Vision monitor enumeration failed.'
    }

    $device = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/device/status" -TimeoutSec 5
    if ($device.ok -ne $true) {
        Fail 'Raven Local Device Adapter live status failed.'
    }

    $state = [ordered]@{
        green = $true
        timestamp = (Get-Date).ToString('o')
        commit = $Commit
        runtime = $RuntimeRoot
        bridge_pid = $bridgeProc.Id
        port = $Port
        monitors = [int]$monitors.count
        health = $health
    }
    $state | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $StateDir 'green.json') -Encoding UTF8

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host ' RAVEN BRIDGE + AUTO-REPAIR = TRUE GREEN' -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host "Bridge     : ONLINE (PID $($bridgeProc.Id))"
    Write-Host "Port       : $Port"
    Write-Host 'Council     : READY'
    Write-Host "Vision      : READY ($($monitors.count) monitor(s))"
    Write-Host 'Device API  : READY'
    Write-Host 'Security    : PASS'
    Write-Host "Runtime     : $RuntimeRoot"
    Write-Host "State       : $(Join-Path $StateDir 'green.json')"
    Write-Host "Log         : $runLog"
    Write-Host ''
    Write-Host 'MILESTONE   : PASS' -ForegroundColor Green
    Write-Host ''

    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host ' RAVEN BRIDGE - NOT GREEN' -ForegroundColor Red
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Log: $runLog" -ForegroundColor Yellow
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}

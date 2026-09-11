# RAH Chronicle v0.2 one-click install / upgrade
# Preserves existing database, reports and config. Replaces only Chronicle runtime/extension files.

$ErrorActionPreference = 'Stop'
$Root = 'C:\RAH\Chronicle'
$App = Join-Path $Root 'App'
$Ext = Join-Path $Root 'Extension'
$Logs = Join-Path $Root 'Logs'
$Agent = Join-Path $App 'rah_chronicle.py'
$Backup = Join-Path $Root ('Backup\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$Raw = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/apps/rah-chronicle'
$ExpectedSourceSha256 = '5c01217b3f4f4bc10d3ae436f0d91ebcf24d53f5285940b6ad48944b9dd2b652'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    $self = $MyInvocation.MyCommand.Path
    if (-not $self) { throw 'Save/run this as a .ps1 file so it can elevate safely.' }
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $self + '"'))
    exit
}

Write-Host '=== RAH CHRONICLE v0.2 INSTALL / UPGRADE ===' -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $Root,$App,$Ext,$Logs,$Backup | Out-Null

$py = Get-Command py.exe -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python.exe -ErrorAction SilentlyContinue }
if (-not $py) {
    Write-Host 'Python not found. Installing Python 3.12 with winget...' -ForegroundColor Yellow
    $winget = Get-Command winget.exe -ErrorAction Stop
    & $winget.Source install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python.exe -ErrorAction Stop }
}

try { Stop-ScheduledTask -TaskName 'RAH Chronicle' -ErrorAction SilentlyContinue } catch {}
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -like '*C:\RAH\Chronicle\App\rah_chronicle.py*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 700

if (Test-Path $Agent) { Copy-Item $Agent (Join-Path $Backup 'rah_chronicle.py') -Force }
if (Test-Path (Join-Path $Root 'config.json')) { Copy-Item (Join-Path $Root 'config.json') (Join-Path $Backup 'config.json') -Force }

$payloadPath = Join-Path $env:TEMP 'rah_chronicle_v02.py.gz.b64'
Invoke-WebRequest -UseBasicParsing -Uri "$Raw/agent/rah_chronicle_v02.py.gz.b64" -OutFile $payloadPath
$encoded = (Get-Content $payloadPath -Raw).Trim()
$compressed = [Convert]::FromBase64String($encoded)
$in = New-Object IO.MemoryStream(,$compressed)
$gzip = New-Object IO.Compression.GzipStream($in,[IO.Compression.CompressionMode]::Decompress)
$out = New-Object IO.FileStream($Agent,[IO.FileMode]::Create,[IO.FileAccess]::Write)
try { $gzip.CopyTo($out) } finally { $out.Dispose(); $gzip.Dispose(); $in.Dispose() }

$actualHash = (Get-FileHash -Algorithm SHA256 -Path $Agent).Hash.ToLowerInvariant()
if ($actualHash -ne $ExpectedSourceSha256) {
    throw "Chronicle source hash mismatch. Expected $ExpectedSourceSha256, got $actualHash"
}
Write-Host 'Runtime SHA-256: PASS' -ForegroundColor Green

$extensionFiles = @('background.js','manifest.json','options.html','options.js')
foreach ($name in $extensionFiles) {
    Invoke-WebRequest -UseBasicParsing -Uri "$Raw/extension/$name" -OutFile (Join-Path $Ext $name)
}

$pythonExe = if (Get-Command py.exe -ErrorAction SilentlyContinue) { (Get-Command py.exe).Source } else { (Get-Command python.exe -ErrorAction Stop).Source }
if ([IO.Path]::GetFileName($pythonExe) -ieq 'py.exe') {
    & $pythonExe -3 -m py_compile $Agent
    if ($LASTEXITCODE -ne 0) { throw 'Python validation failed.' }
    $arg = '-3 "' + $Agent + '"'
} else {
    & $pythonExe -m py_compile $Agent
    if ($LASTEXITCODE -ne 0) { throw 'Python validation failed.' }
    $arg = '"' + $Agent + '"'
}
Write-Host 'Python syntax: PASS' -ForegroundColor Green

$action = New-ScheduledTaskAction -Execute $pythonExe -Argument $arg
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'RAH Chronicle' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Start-Process -FilePath $pythonExe -ArgumentList $arg -WindowStyle Hidden

$health = $null
for ($i=0; $i -lt 12; $i++) {
    Start-Sleep -Milliseconds 700
    try {
        $health = Invoke-RestMethod 'http://127.0.0.1:18766/health' -TimeoutSec 3
        if ($health.ok -and $health.version -eq '0.2.0') { break }
    } catch {}
}
if (-not $health -or -not $health.ok -or $health.version -ne '0.2.0') {
    throw 'RAH Chronicle v0.2 failed health check. See C:\RAH\Chronicle\Logs\chronicle.log'
}

$today = Invoke-RestMethod 'http://127.0.0.1:18766/api/today' -TimeoutSec 5
$week = Invoke-RestMethod 'http://127.0.0.1:18766/api/week' -TimeoutSec 5
$gh = Invoke-RestMethod 'http://127.0.0.1:18766/api/github' -TimeoutSec 20

$desktop = [Environment]::GetFolderPath('Desktop')
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut((Join-Path $desktop 'RAH Chronicle.lnk'))
$shortcut.TargetPath = 'http://127.0.0.1:18766/'
$shortcut.Save()

Write-Host ''
Write-Host '=============================================' -ForegroundColor Green
Write-Host '      RAH CHRONICLE v0.2 READY' -ForegroundColor Green
Write-Host '=============================================' -ForegroundColor Green
Write-Host "Health           : $($health.ok) / $($health.version)" -ForegroundColor Cyan
Write-Host "Tracked today    : $($today.total_seconds) sec" -ForegroundColor Cyan
Write-Host "Week work        : $($week.work_seconds) sec" -ForegroundColor Cyan
Write-Host "GitHub commits   : $($gh.commits.Count)" -ForegroundColor Cyan
Write-Host "GitHub PR signals: $($gh.pulls.Count)" -ForegroundColor Cyan
Write-Host 'Dashboard        : http://127.0.0.1:18766/' -ForegroundColor Cyan
Write-Host 'Daily report     : http://127.0.0.1:18766/report/today' -ForegroundColor Cyan
Write-Host 'Weekly report    : http://127.0.0.1:18766/report/week' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Edge: if RAH Chronicle is already loaded, press Reload once on edge://extensions.' -ForegroundColor Yellow
Write-Host 'If this is a fresh install: Developer mode -> Load unpacked -> C:\RAH\Chronicle\Extension' -ForegroundColor Yellow

Start-Process 'http://127.0.0.1:18766/'
try { Start-Process 'msedge.exe' 'edge://extensions/' } catch {}

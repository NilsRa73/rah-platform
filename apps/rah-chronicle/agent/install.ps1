# RAH Chronicle v0.1 one-click installer
# Run in PowerShell. It self-elevates, installs under C:\RAH\Chronicle,
# creates an at-logon task, and opens the browser extension page.

$ErrorActionPreference = 'Stop'
$RepoRaw = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/apps/rah-chronicle'
$Root = 'C:\RAH\Chronicle'
$App = Join-Path $Root 'App'
$Ext = Join-Path $Root 'Extension'
$Logs = Join-Path $Root 'Logs'

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Is-Admin)) {
    $self = $MyInvocation.MyCommand.Path
    if ($self) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $self + '"'))
    } else {
        throw 'Save this installer as a .ps1 file first, then run it. Elevation is required to create C:\RAH and the scheduled task.'
    }
    exit
}

Write-Host '=== RAH CHRONICLE INSTALLER ===' -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $Root,$App,$Ext,$Logs | Out-Null

$py = Get-Command py.exe -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python.exe -ErrorAction SilentlyContinue }
if (-not $py) {
    Write-Host 'Python not found. Installing Python 3.12 with winget...' -ForegroundColor Yellow
    $winget = Get-Command winget.exe -ErrorAction Stop
    & $winget.Source install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python.exe -ErrorAction Stop }
}

$files = @{
    'agent/rah_chronicle.py' = (Join-Path $App 'rah_chronicle.py')
    'extension/manifest.json' = (Join-Path $Ext 'manifest.json')
    'extension/background.js' = (Join-Path $Ext 'background.js')
    'extension/options.html' = (Join-Path $Ext 'options.html')
    'extension/options.js' = (Join-Path $Ext 'options.js')
}
foreach ($kv in $files.GetEnumerator()) {
    $url = "$RepoRaw/$($kv.Key)"
    Write-Host "Downloading $url"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $kv.Value
}

$pythonExe = if ((Get-Command py.exe -ErrorAction SilentlyContinue)) { (Get-Command py.exe).Source } else { (Get-Command python.exe).Source }
$arg = if ([IO.Path]::GetFileName($pythonExe) -ieq 'py.exe') { '-3 "' + (Join-Path $App 'rah_chronicle.py') + '"' } else { '"' + (Join-Path $App 'rah_chronicle.py') + '"' }

$action = New-ScheduledTaskAction -Execute $pythonExe -Argument $arg
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'RAH Chronicle' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Start-Process -FilePath $pythonExe -ArgumentList $arg -WindowStyle Hidden
Start-Sleep -Seconds 2
try {
    $health = Invoke-RestMethod -Uri 'http://127.0.0.1:18766/health' -TimeoutSec 4
    Write-Host "Collector: $($health.service) $($health.version) ONLINE" -ForegroundColor Green
} catch {
    Write-Warning 'Collector did not answer yet. Check C:\RAH\Chronicle\Logs\chronicle.log'
}

$desktop = [Environment]::GetFolderPath('Desktop')
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut((Join-Path $desktop 'RAH Chronicle.lnk'))
$shortcut.TargetPath = 'http://127.0.0.1:18766/'
$shortcut.Save()

Write-Host ''
Write-Host 'ONE MANUAL BROWSER STEP REMAINS:' -ForegroundColor Yellow
Write-Host '1. Open edge://extensions (or chrome://extensions)'
Write-Host '2. Enable Developer mode'
Write-Host '3. Load unpacked -> C:\RAH\Chronicle\Extension'
Write-Host 'Browsers intentionally block silent side-loading of normal unpacked extensions.'
Write-Host ''
Write-Host 'Dashboard: http://127.0.0.1:18766/' -ForegroundColor Cyan
Write-Host 'Daily reports: C:\RAH\Chronicle\Reports' -ForegroundColor Cyan

Start-Process 'http://127.0.0.1:18766/'
try { Start-Process 'msedge.exe' 'edge://extensions/' } catch {}

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RuntimeRoot = 'C:\RAH\Raven\rah-platform'
$BridgeDir = Join-Path $RuntimeRoot 'desktop-bridge'
$ToolsDir = 'C:\RAH\Raven\Tools'
$WatchdogSource = Join-Path $BridgeDir 'raven-watchdog.ps1'
$Watchdog = Join-Path $ToolsDir 'raven-watchdog.ps1'
$Port = 18765

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-Health {
    try { Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 3 } catch { $null }
}
function Test-Green($h) {
    if ($null -eq $h) { return $false }
    foreach ($name in @('ok','council_proxy','vision_monitor_capture','local_device_adapter')) {
        $p = $h.PSObject.Properties[$name]
        if ($null -eq $p -or $p.Value -ne $true) { return $false }
    }
    $true
}

if (-not (Test-IsAdmin)) { throw 'Run this installer from PowerShell as Administrator.' }
if (-not (Test-Path (Join-Path $BridgeDir 'raven_bridge.py'))) { throw "Raven runtime missing: $RuntimeRoot" }
if (-not (Test-Path $WatchdogSource)) { throw 'raven-watchdog.ps1 is missing from the runtime.' }

New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
Copy-Item -LiteralPath $WatchdogSource -Destination $Watchdog -Force

$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($Watchdog,[ref]$tokens,[ref]$errors)
if ($errors.Count -gt 0) { throw ('Watchdog parser errors: ' + (($errors | ForEach-Object Message) -join '; ')) }

$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

$startupAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $Watchdog + '" -Startup')
$startupTrigger = New-ScheduledTaskTrigger -AtLogOn -User $user
Register-ScheduledTask -TaskName 'RAH Raven Bridge Startup' -Action $startupAction -Trigger $startupTrigger -Principal $principal -Settings $settings -Force | Out-Null

$watchAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $Watchdog + '"')
$watchTrigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(1)) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
Register-ScheduledTask -TaskName 'RAH Raven Bridge Watchdog' -Action $watchAction -Trigger $watchTrigger -Principal $principal -Settings $settings -Force | Out-Null

$desktop = [Environment]::GetFolderPath('Desktop')
$shell = New-Object -ComObject WScript.Shell
$vision = $shell.CreateShortcut((Join-Path $desktop 'RAH Raven Vision.lnk'))
$vision.TargetPath = "$env:WINDIR\explorer.exe"
$vision.Arguments = "http://127.0.0.1:$Port/vision/ui"
$vision.Description = 'Open RAH Raven Vision'
$vision.Save()

$status = $shell.CreateShortcut((Join-Path $desktop 'RAH Raven Status.lnk'))
$status.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$status.Arguments = '-NoExit -NoProfile -ExecutionPolicy Bypass -Command "$h=Invoke-RestMethod http://127.0.0.1:18765/health -TimeoutSec 3; $h | ConvertTo-Json -Depth 6"'
$status.Description = 'Show RAH Raven Bridge health'
$status.Save()

powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Watchdog
if ($LASTEXITCODE -ne 0) { throw "Watchdog first run failed with exit code $LASTEXITCODE." }

$health = Get-Health
if (-not (Test-Green $health)) { throw 'Autostart installed, but live Raven health is not GREEN.' }

$startupTask = Get-ScheduledTask -TaskName 'RAH Raven Bridge Startup' -ErrorAction Stop
$watchTask = Get-ScheduledTask -TaskName 'RAH Raven Bridge Watchdog' -ErrorAction Stop

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' RAVEN VISION + AUTOSTART = TRUE GREEN' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host "Startup task : $($startupTask.State)"
Write-Host "Watchdog     : $($watchTask.State) / every 5 minutes"
Write-Host 'Bridge       : ONLINE'
Write-Host "Port         : $Port"
Write-Host 'Vision       : READY'
Write-Host 'Device API   : READY'
Write-Host 'Desktop      : RAH Raven Vision + RAH Raven Status shortcuts'
Write-Host 'MILESTONE    : PASS' -ForegroundColor Green

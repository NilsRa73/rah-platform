$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Desktop = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "RAH Raven Daily Driver.lnk"
$Target = Join-Path $AppDir "START-RAH-RAVEN.bat"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $Target
$Shortcut.WorkingDirectory = $AppDir
$Shortcut.Description = "RAH Raven Daily Driver v1.0 Stable"
$Shortcut.Save()

Write-Host "Desktop shortcut created: $ShortcutPath" -ForegroundColor Green

$RuntimeRoot = 'C:\RAH\DailyDriver\runtime'
New-Item -ItemType Directory -Force -Path $RuntimeRoot | Out-Null
Write-Host "RAH runtime data: $RuntimeRoot" -ForegroundColor DarkYellow

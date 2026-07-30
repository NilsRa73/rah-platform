$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'START-RAH-RAVEN.bat'

if (-not (Test-Path $launcher)) {
    throw "Fant ikke START-RAH-RAVEN.bat i $repoRoot"
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'RAH Raven One.lnk'

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcher
$shortcut.WorkingDirectory = $repoRoot
$shortcut.Description = 'Start RAH Raven One, Desktop Bridge og Command Center'
$shortcut.WindowStyle = 7
$shortcut.Save()

Write-Host "Ferdig: $shortcutPath" -ForegroundColor Green
Write-Host 'Du kan naa starte RAH Raven One fra skrivebordet.'

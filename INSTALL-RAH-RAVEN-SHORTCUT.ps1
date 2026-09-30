$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $repoRoot 'START-HER.cmd'

if (-not (Test-Path $launcher)) {
    throw "Fant ikke START-HER.cmd i $repoRoot"
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'RAH START HER.lnk'

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcher
$shortcut.WorkingDirectory = $repoRoot
$shortcut.Description = 'Canonical RAH entry point: Raven Core, Desktop Bridge and Command Wheel'
$shortcut.WindowStyle = 7
$shortcut.Save()

Write-Host "Ferdig: $shortcutPath" -ForegroundColor Green
Write-Host 'Bruk RAH START HER som hovedinngang til RAH.'

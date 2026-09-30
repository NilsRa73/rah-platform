$ErrorActionPreference='Stop'
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Canonical = Join-Path $RepoRoot 'INSTALL-RAH-START-MENU.ps1'

if (-not (Test-Path $Canonical)) {
    throw "Fant ikke canonical installer: $Canonical"
}

Write-Host 'INSTALL-RAH-DESKTOP.ps1 routes to RAH Start Menu v1.0.' -ForegroundColor Yellow
& $Canonical

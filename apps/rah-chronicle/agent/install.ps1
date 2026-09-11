# RAH Chronicle v0.2 one-click installer / upgrader
# This stable entrypoint downloads the current v0.2 installer and lets it self-elevate.

$ErrorActionPreference = 'Stop'
$Url = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/apps/rah-chronicle/agent/upgrade_v02.ps1'
$File = Join-Path $env:TEMP 'RAH-CHRONICLE-v02-INSTALL.ps1'

Write-Host '=== RAH CHRONICLE v0.2 BOOTSTRAP ===' -ForegroundColor Yellow
Write-Host 'Downloading verified installer...' -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $File
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File $File

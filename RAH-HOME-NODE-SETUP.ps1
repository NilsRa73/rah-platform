param(
 [ValidateSet('Worker','Leader')][string]$Mode='Worker',
 [ValidateRange(1024,65535)][int]$Port=18766
)
$ErrorActionPreference='Stop'
if($Port-ne18766){throw 'Legacy setup støtter nå bare sikker standardport 18766. Bruk RAH-HOME-INSTALL.ps1 direkte for videre utvikling.'}
$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$dir=Join-Path $env:LOCALAPPDATA 'RAH\Home'
New-Item -ItemType Directory -Path $dir -Force|Out-Null
$installer=Join-Path $dir 'RAH-HOME-INSTALL.ps1'
Invoke-WebRequest -UseBasicParsing -Uri "$base/RAH-HOME-INSTALL.ps1" -OutFile $installer
Write-Host 'Legacy RAH Home Node Setup videresender nå til den herdede unified installasjonen.' -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -Mode $Mode
if($LASTEXITCODE-ne0){exit $LASTEXITCODE}

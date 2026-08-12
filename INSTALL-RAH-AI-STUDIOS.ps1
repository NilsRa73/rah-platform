$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$desktop = [Environment]::GetFolderPath('Desktop')
$root = Join-Path $desktop 'RAH AI Studios'
$raw = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main'

Write-Host ''
Write-Host ' RAH AI STUDIOS - ENKEL INSTALLASJON' -ForegroundColor Yellow
Write-Host ' ====================================' -ForegroundColor Yellow
Write-Host ''

New-Item -ItemType Directory -Path $root -Force | Out-Null
Write-Host "Mappe: $root" -ForegroundColor Cyan

$updater = Join-Path $root 'UPDATE-RAH-RAVEN.ps1'
$starter = Join-Path $root 'DOBBELTKLIKK-HER-START-RAH-RAVEN.bat'

Write-Host 'Henter updater og startfil...'
Invoke-WebRequest -UseBasicParsing -Uri "$raw/UPDATE-RAH-RAVEN.ps1" -OutFile $updater
Invoke-WebRequest -UseBasicParsing -Uri "$raw/DOBBELTKLIKK-HER-START-RAH-RAVEN.bat" -OutFile $starter

$overview = @'
RAH AI STUDIOS
==============

FØRSTE INSTALLASJON
- Installeren henter siste godkjente Raven-pakke og starter RAH Raven automatisk.

NESTE GANG
1. Dobbeltklikk snarveien "RAH AI Studios" på skrivebordet.
2. Raven henter siste godkjente versjon fra GitHub.
3. Desktop Bridge testes og startes.
4. RAH Raven Startside åpnes.

VIKTIGSTE MODULER
- RAH Raven Startside / AI Studios kontrollsenter
- RAH Home Control
- Raven Chronicle / Daily Brief
- Raven Care / Case Center
- Mission Control
- Local AI via LM Studio

VED FEIL
Kopier teksten fra ERROR og nedover og lim den inn i ChatGPT.
Se også rah-raven-update.log i denne mappen.

DATA
RAH bruker lokale filer og lokal lagring for disse modulene.
Ikke legg passord eller sensitive journaldata i den offentlige GitHub-mappen.
'@
Set-Content -LiteralPath (Join-Path $root '00-START-HER.txt') -Value $overview -Encoding UTF8

$shell = New-Object -ComObject WScript.Shell
$shortcutPath = Join-Path $desktop 'RAH AI Studios.lnk'
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $starter
$shortcut.WorkingDirectory = $root
$shortcut.Description = 'Start og oppdater RAH AI Studios'
$shortcut.WindowStyle = 1
$shortcut.Save()

Write-Host 'Henter, installerer og starter siste RAH Raven-pakke...' -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $updater
if ($LASTEXITCODE -ne 0) {
    throw 'Første RAH-oppdatering eller oppstart feilet.'
}

Write-Host ''
Write-Host 'RAH AI Studios er installert og oppstart er sendt til Raven.' -ForegroundColor Green
Write-Host "Mappe: $root" -ForegroundColor Green
Write-Host "Snarvei: $shortcutPath" -ForegroundColor Green
Write-Host ''
Write-Host 'Åpner RAH AI Studios-mappen...' -ForegroundColor Cyan
Start-Process explorer.exe -ArgumentList $root

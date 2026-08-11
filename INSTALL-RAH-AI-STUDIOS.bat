@echo off
setlocal EnableExtensions
title RAH AI Studios - First-time installer

echo.
echo  RAH AI STUDIOS - ENKEL INSTALLASJON
echo  ====================================
echo.
echo Denne installasjonen lager en egen RAH AI Studios-mappe pa skrivebordet,
echo henter siste godkjente filer fra GitHub og lager en enkel startsnarvei.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$desktop=[Environment]::GetFolderPath('Desktop');" ^
  "$root=Join-Path $desktop 'RAH AI Studios';" ^
  "$raw='https://raw.githubusercontent.com/NilsRa73/rah-platform/main';" ^
  "New-Item -ItemType Directory -Path $root -Force | Out-Null;" ^
  "Write-Host ('Mappe: '+$root) -ForegroundColor Cyan;" ^
  "$updater=Join-Path $root 'UPDATE-RAH-RAVEN.ps1';" ^
  "$starter=Join-Path $root 'DOBBELTKLIKK-HER-START-RAH-RAVEN.bat';" ^
  "Invoke-WebRequest -UseBasicParsing -Uri ($raw+'/UPDATE-RAH-RAVEN.ps1') -OutFile $updater;" ^
  "Invoke-WebRequest -UseBasicParsing -Uri ($raw+'/DOBBELTKLIKK-HER-START-RAH-RAVEN.bat') -OutFile $starter;" ^
  "$overview=@'" ^
  "RAH AI STUDIOS" ^
  "==============" ^
  "" ^
  "START HER:" ^
  "1. Dobbeltklikk DOBBELTKLIKK-HER-START-RAH-RAVEN.bat" ^
  "2. Raven henter siste godkjente versjon fra GitHub." ^
  "3. Desktop Bridge testes og startes." ^
  "4. RAH Raven Startside apnes." ^
  "" ^
  "VIKTIGSTE MODULER:" ^
  "- RAH Raven Startside / AI Studios kontrollsenter" ^
  "- RAH Home Control" ^
  "- Raven Chronicle / Daily Brief" ^
  "- Raven Care / Case Center" ^
  "- Mission Control" ^
  "- Local AI via LM Studio" ^
  "" ^
  "VED FEIL:" ^
  "Kopier teksten fra ERROR og nedover og lim den inn i ChatGPT." ^
  "Se ogsa rah-raven-update.log i denne mappen." ^
  "" ^
  "DATA:" ^
  "RAH bruker lokale filer og lokal lagring for disse modulene. Ikke legg passord eller sensitive journaldata i den offentlige GitHub-mappen." ^
  "'@;" ^
  "Set-Content -LiteralPath (Join-Path $root '00-START-HER.txt') -Value $overview -Encoding UTF8;" ^
  "$shell=New-Object -ComObject WScript.Shell;" ^
  "$shortcut=$shell.CreateShortcut((Join-Path $desktop 'RAH AI Studios.lnk'));" ^
  "$shortcut.TargetPath=$starter;" ^
  "$shortcut.WorkingDirectory=$root;" ^
  "$shortcut.Description='Start og oppdater RAH AI Studios';" ^
  "$shortcut.WindowStyle=1;" ^
  "$shortcut.Save();" ^
  "Write-Host 'Henter og installerer siste RAH Raven-pakke...' -ForegroundColor Yellow;" ^
  "& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $updater -NoStart;" ^
  "if($LASTEXITCODE -ne 0){throw 'Første RAH-oppdatering feilet.'};" ^
  "Write-Host '';" ^
  "Write-Host 'RAH AI Studios er installert.' -ForegroundColor Green;" ^
  "Write-Host 'Du har na bade en RAH AI Studios-mappe og en RAH AI Studios-snarvei pa skrivebordet.' -ForegroundColor Green;" ^
  "Start-Process explorer.exe -ArgumentList $root;"

if errorlevel 1 goto :error

echo.
echo  FERDIG.
echo  Dobbeltklikk "RAH AI Studios" pa skrivebordet for a starte.
echo.
pause
exit /b 0

:error
echo.
echo  FEIL: RAH AI Studios kunne ikke installeres ferdig.
echo  Ingen eksisterende RAH-mappe slettes av denne installasjonen.
echo.
pause
exit /b 1

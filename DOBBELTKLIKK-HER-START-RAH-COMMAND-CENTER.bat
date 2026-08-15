@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Command Center

set "CC_UPDATER=%~dp0UPDATE-RAH-COMMAND-CENTER.ps1"
set "CC_UPDATER_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/UPDATE-RAH-COMMAND-CENTER.ps1"

echo.
echo  RAH RAVEN COMMAND CENTER
echo  ========================
echo.
echo Henter siste godkjente Command Center-pakke...

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%CC_UPDATER_URL%' -OutFile '%CC_UPDATER%.download'; if((Get-Item '%CC_UPDATER%.download').Length -lt 1){throw 'Command Center updater download was empty'}; Move-Item -Force '%CC_UPDATER%.download' '%CC_UPDATER%'"
if errorlevel 1 goto :error

powershell -NoProfile -ExecutionPolicy Bypass -File "%CC_UPDATER%"
if errorlevel 1 goto :error
exit /b 0

:error
echo.
echo FEIL: RAH Command Center kunne ikke oppdateres eller startes.
echo Eksisterende lokale filer er ikke slettet.
echo Se rah-command-center-update.log i denne mappen.
echo.
pause
exit /b 1

@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven - Update and Start

set "UPDATER=%~dp0UPDATE-RAH-RAVEN.ps1"
set "UPDATER_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/UPDATE-RAH-RAVEN.ps1"

echo.
echo  RAH RAVEN - UPDATE AND START
echo  =============================
echo.
echo Henter siste godkjente Raven-filer fra NilsRa73/rah-platform...

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%UPDATER_URL%' -OutFile '%UPDATER%.download'; if((Get-Item '%UPDATER%.download').Length -lt 1){throw 'Updater download was empty'}; Move-Item -Force '%UPDATER%.download' '%UPDATER%'"
if errorlevel 1 goto :error

powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER%"
if errorlevel 1 goto :error
exit /b 0

:error
echo.
echo FEIL: Raven kunne ikke oppdateres eller startes.
echo Eksisterende filer er ikke med vilje slettet.
echo Se rah-raven-update.log i denne mappen.
echo.
pause
exit /b 1

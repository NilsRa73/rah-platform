@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Update and Start RAH Raven

set "UPDATER=%~dp0UPDATE-RAH-RAVEN.ps1"
set "UPDATER_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/UPDATE-RAH-RAVEN.ps1"

echo.
echo  RAH RAVEN - UPDATE AND START
echo  =============================
echo.
echo [1/2] Downloading the project updater from NilsRa73/rah-platform...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%UPDATER_URL%' -OutFile '%UPDATER%.download'; if((Get-Item '%UPDATER%.download').Length -lt 1){throw 'Updater download was empty'}; Move-Item -Force '%UPDATER%.download' '%UPDATER%'"
if errorlevel 1 goto :error

echo [2/2] Updating known Raven files, creating a backup, and starting v1.7...
powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER%"
if errorlevel 1 goto :error

exit /b 0

:error
echo.
echo ERROR: RAH Raven could not update or start.
echo Existing files were not intentionally deleted.
echo Read rah-raven-update.log in this folder and paste the last lines into ChatGPT.
echo.
pause
exit /b 1

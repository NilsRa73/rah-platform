@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Command Center

set "CC_UPDATER=%~dp0UPDATE-RAH-COMMAND-CENTER.ps1"

echo.
echo  RAH RAVEN COMMAND CENTER
echo  ========================
echo.
echo Starter lokal, verifiserende Command Center-updater...

if not exist "%CC_UPDATER%" goto :missing
powershell -NoProfile -ExecutionPolicy Bypass -File "%CC_UPDATER%"
if errorlevel 1 goto :error
exit /b 0

:missing
echo.
echo FEIL: UPDATE-RAH-COMMAND-CENTER.ps1 mangler i RAH-mappen.
echo Av sikkerhetsgrunner lastes ikke kjørbar PowerShell automatisk fra nettet.
echo.
pause
exit /b 1

:error
echo.
echo FEIL: RAH Command Center kunne ikke oppdateres eller startes.
echo Eksisterende lokale filer er ikke slettet.
echo Se rah-command-center-update.log i denne mappen.
echo.
pause
exit /b 1

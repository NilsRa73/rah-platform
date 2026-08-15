@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Command Center
set "CC_PAGE=%~dp0RAH-COMMAND-CENTER-V1.2.html"
if not exist "%CC_PAGE%" goto :missing
echo.
echo  RAH RAVEN COMMAND CENTER v1.2.0
echo  =================================
echo  Lokal start. Ingen nedlasting eller automatisk oppdatering ved oppstart.
echo  For manuell oppdatering: start UPDATE-RAH-COMMAND-CENTER.ps1 selv.
echo.
start "" "%CC_PAGE%"
exit /b 0
:missing
echo.
echo FEIL: RAH-COMMAND-CENTER-V1.2.html ble ikke funnet i denne mappen.
echo Ingen filer er endret eller lastet ned.
echo.
pause
exit /b 1

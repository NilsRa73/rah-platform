@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Command Center

set "CC_PAGE=%~dp0RAH-COMMAND-CENTER-V0.3.html"

if not exist "%CC_PAGE%" goto :missing

echo.
echo  RAH RAVEN COMMAND CENTER v0.3.1
echo  =================================
echo  Lokal offline-first start. Ingen filer lastes ned eller oppdateres automatisk.
echo.
start "" "%CC_PAGE%"
exit /b 0

:missing
echo.
echo FEIL: RAH-COMMAND-CENTER-V0.3.html ble ikke funnet i denne mappen.
echo Ingen filer er endret eller lastet ned.
echo.
pause
exit /b 1

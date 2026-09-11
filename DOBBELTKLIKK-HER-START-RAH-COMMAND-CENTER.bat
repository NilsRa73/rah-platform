@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Command Center
set "CC_PAGE=%~dp0RAH-COMMAND-CENTER-V2.4.html"
if not exist "%CC_PAGE%" goto :missing
echo.
echo  RAH RAVEN COMMAND CENTER v2.4.0 STABLE
echo  =======================================
echo  Lokal start. Ingen nedlasting eller automatisk oppdatering ved oppstart.
echo  Raven Commander: fast read-only systemstatus via Stable Node Agent 1.4.
echo  Node-token sendes ikke over LAN; token-proof HMAC brukes per request.
echo  Ingen arbitrary shell, filer, generiske argumenter eller background polling.
echo  For manuell oppdatering: start UPDATE-RAH-COMMAND-CENTER.ps1 selv.
echo.
start "" "%CC_PAGE%"
exit /b 0
:missing
echo.
echo FEIL: RAH-COMMAND-CENTER-V2.4.html ble ikke funnet i denne mappen.
echo Kjoer UPDATE-RAH-COMMAND-CENTER.ps1 manuelt for aa hente canonical generation 9.
echo Ingen filer er endret eller lastet ned av launcheren.
echo.
pause
exit /b 1

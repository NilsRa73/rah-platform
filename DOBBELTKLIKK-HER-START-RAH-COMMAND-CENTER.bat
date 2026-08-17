@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Command Center
set "CC_PAGE=%~dp0RAH-COMMAND-CENTER-V2.2.html"
if not exist "%CC_PAGE%" goto :missing
echo.
echo  RAH RAVEN COMMAND CENTER v2.2.0 STABLE
echo  =======================================
echo  Lokal start. Ingen nedlasting eller automatisk oppdatering ved oppstart.
echo  Node-token sendes ikke over LAN; token-proof HMAC brukes per request.
echo  Fleet Snapshot er eksplisitt og memory-only; mislykket refresh invaliderer gammel valgt rad.
echo  For manuell oppdatering: start UPDATE-RAH-COMMAND-CENTER.ps1 selv.
echo.
start "" "%CC_PAGE%"
exit /b 0
:missing
echo.
echo FEIL: RAH-COMMAND-CENTER-V2.2.html ble ikke funnet i denne mappen.
echo Kjoer UPDATE-RAH-RAVEN.ps1 en gang dersom denne installasjonen kommer fra en eldre pakke.
echo Ingen filer er endret eller lastet ned av launcheren.
echo.
pause
exit /b 1

@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven - LATEST GREEN MAIN SYNC
echo.
echo ============================================================
echo  RAH RAVEN - LATEST GREEN MAIN SYNC
echo ============================================================
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0UPDATE-RAH-LATEST.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" echo PASS - HOVED-PC er synkronisert mot verifisert main.
if "%RC%"=="2" echo PARTIAL - sync er installert, men Self-Check har en ikke-kritisk rest.
if not "%RC%"=="0" if not "%RC%"=="2" echo FAIL - ingen usikker fortsettelse ble gjort. Se C:\RAH\Status\RAVEN-BASELINE-LATEST.txt
echo.
pause
exit /b %RC%

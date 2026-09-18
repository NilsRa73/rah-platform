@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Lenovo Raven Worker FINAL
set "FINAL=%~dp0RAH-LENOVO-WORKER-FINAL.ps1"
if not exist "%FINAL%" (
  echo [FAIL] Mangler RAH-LENOVO-WORKER-FINAL.ps1
  pause
  exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FINAL%" %*
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo PASS - Lenovo Raven Worker er installert og startet.
  echo Rapport: C:\RAH\Logs\LENOVO-WORKER-FINAL-LATEST.json
) else (
  echo FAIL - se rapporten i C:\RAH\Logs.
)
echo.
pause
exit /b %RC%

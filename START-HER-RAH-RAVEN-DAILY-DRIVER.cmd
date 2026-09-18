@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Daily Driver v1.0 FINAL / STABLE

set "FINAL=%~dp0RAH-RAVEN-DAILY-DRIVER-FINAL.ps1"
if not exist "%FINAL%" (
  echo [FAIL] Mangler RAH-RAVEN-DAILY-DRIVER-FINAL.ps1
  pause
  exit /b 2
)

echo.
echo ====================================================================
echo  RAH RAVEN DAILY DRIVER v1.0 - ONE CLICK
echo  CONTRACTS ^> INSTALL/REPAIR ^> TESTS ^> RUNTIME GATE ^> START
echo ====================================================================
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FINAL%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo ====================================================================
  echo  PASS - RAH Raven Daily Driver v1.0 FINAL/STABLE
  echo  Rapport: C:\RAH\Logs\RAVEN-DAILY-DRIVER-FINAL-LATEST.json
  echo ====================================================================
) else (
  echo ====================================================================
  echo  FAIL - se C:\RAH\Logs\RAVEN-DAILY-DRIVER-FINAL-LATEST.json
  echo ====================================================================
)
echo.
pause
exit /b %RC%

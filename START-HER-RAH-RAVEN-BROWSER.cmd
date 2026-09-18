@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Browser v1.3 FINAL / STABLE

set "FINAL=%~dp0RAH-RAVEN-BROWSER-FINAL.ps1"
if not exist "%FINAL%" (
  echo [FAIL] Mangler RAH-RAVEN-BROWSER-FINAL.ps1
  pause
  exit /b 2
)

echo.
echo ====================================================================
echo  RAH RAVEN BROWSER v1.3 - ONE CLICK
echo  PRECHECK ^> REPAIR ^> INSTALL ^> SAFETY ^> START
echo ====================================================================
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FINAL%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo ====================================================================
  echo  PASS - RAH Raven Browser v1.3 FINAL/STABLE
  echo  Rapport: C:\RAH\Logs\RAVEN-BROWSER-FINAL-LATEST.json
  echo ====================================================================
) else (
  echo ====================================================================
  echo  FAIL - se C:\RAH\Logs\RAVEN-BROWSER-FINAL-LATEST.json
  echo ====================================================================
)
echo.
pause
exit /b %RC%

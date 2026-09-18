@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio 3.0 FINAL / STABLE

set "FINAL=%~dp0RAH-RAVEN-STUDIO-FINAL.ps1"
if not exist "%FINAL%" (
  echo [FAIL] Mangler RAH-RAVEN-STUDIO-FINAL.ps1
  pause
  exit /b 2
)

echo.
echo ====================================================================
echo  RAH RAVEN STUDIO 3.0 - ONE CLICK
echo  CONTRACTS ^> INFRA REPAIR ^> SHORTCUT ^> START
echo ====================================================================
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FINAL%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo ====================================================================
  echo  PASS - RAH Raven Studio 3.0 FINAL/STABLE
  echo  Rapport: C:\RAH\Logs\RAVEN-STUDIO-FINAL-LATEST.json
  echo ====================================================================
) else (
  echo ====================================================================
  echo  FAIL - se C:\RAH\Logs\RAVEN-STUDIO-FINAL-LATEST.json
  echo ====================================================================
)
echo.
pause
exit /b %RC%

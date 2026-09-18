@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH AI Investigator 1.0 FINAL / STABLE

set "FINAL=%~dp0RAH-AI-INVESTIGATOR-FINAL.ps1"
if not exist "%FINAL%" (
  echo [FAIL] Mangler RAH-AI-INVESTIGATOR-FINAL.ps1
  pause
  exit /b 2
)

echo.
echo ====================================================================
echo  RAH AI INVESTIGATOR 1.0 - ONE CLICK
echo  CONTRACT ^> INSTALL ^> SELFTEST ^> NORMALIZE ^> SHORTCUT ^> START
echo ====================================================================
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FINAL%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo ====================================================================
  echo  PASS - RAH AI Investigator 1.0 FINAL/STABLE
  echo  Rapport: C:\RAH\Logs\RAH-AI-INVESTIGATOR-FINAL-LATEST.json
  echo ====================================================================
) else (
  echo ====================================================================
  echo  FAIL - se C:\RAH\Logs\RAH-AI-INVESTIGATOR-FINAL-LATEST.json
  echo ====================================================================
)
echo.
pause
exit /b %RC%

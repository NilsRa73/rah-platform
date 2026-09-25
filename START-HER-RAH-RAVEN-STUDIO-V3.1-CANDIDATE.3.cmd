@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio v3.1 Candidate.3

set "CHECK=%~dp0RAH-RAVEN-STUDIO-V3.1-CANDIDATE.3.ps1"
if not exist "%CHECK%" (
  echo [FAIL] Mangler RAH-RAVEN-STUDIO-V3.1-CANDIDATE.3.ps1
  pause
  exit /b 2
)

echo ============================================================
echo  RAH RAVEN STUDIO v3.1 CANDIDATE.3
echo  SELF-TEST ^> LAUNCH
echo ============================================================
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CHECK%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo [FAIL] Candidate.3 self-test/launch feilet.
  pause
)
exit /b %RC%

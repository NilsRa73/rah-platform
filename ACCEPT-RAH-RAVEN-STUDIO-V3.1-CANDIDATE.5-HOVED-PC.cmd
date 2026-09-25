@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio Candidate.5 - HOVED-PC Acceptance

set "ACCEPT=%~dp0ACCEPT-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5-HOVED-PC.ps1"
if not exist "%ACCEPT%" (
  echo [FAIL] Mangler HOVED-PC acceptance script.
  pause
  exit /b 2
)

echo.
echo ============================================================
echo  RAH RAVEN STUDIO CANDIDATE.5 - HOVED-PC ACCEPTANCE
echo  STATIC ^> SELFTEST ^> ONE CLICK ^> EVIDENCE ^> FINAL
echo ============================================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ACCEPT%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo ============================================================
  echo  FINAL: PASS
  echo  Candidate.5 bestod HOVED-PC acceptance.
  echo ============================================================
) else (
  echo ============================================================
  echo  FINAL: FAIL
  echo  Se C:\RAH\Logs\RAVEN-STUDIO-HOVED-PC-ACCEPTANCE-LATEST.json
  echo ============================================================
)
echo.
pause
exit /b %RC%

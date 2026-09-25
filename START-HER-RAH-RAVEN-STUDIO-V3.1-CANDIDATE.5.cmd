@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio v3.1 Candidate.5 - One Click

set "RUN=%~dp0RAH-RAVEN-STUDIO-ONECLICK-V3.1-CANDIDATE.5.ps1"
if not exist "%RUN%" (
  echo [FAIL] Mangler Candidate.5 one-click orchestrator.
  pause
  exit /b 2
)

echo.
echo ============================================================
echo  RAH RAVEN STUDIO v3.1 CANDIDATE.5
echo  PRECHECK ^> SAFE REPAIR ^> POSTCHECK ^> STUDIO
echo ============================================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RUN%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo ============================================================
  echo  STARTUP PASS
  echo  Rapport: C:\RAH\Logs\RAVEN-STUDIO-ONECLICK-LATEST.json
  echo ============================================================
  timeout /t 2 /nobreak >nul
) else (
  echo ============================================================
  echo  STARTUP FAIL
  echo  Rapport: C:\RAH\Logs\RAVEN-STUDIO-ONECLICK-LATEST.json
  echo ============================================================
  echo.
  echo Studio er apnet med feilmeldingen og lenke til Diagnostics.
  pause
)
exit /b %RC%

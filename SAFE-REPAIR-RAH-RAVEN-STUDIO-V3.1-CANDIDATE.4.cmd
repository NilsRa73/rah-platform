@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio Candidate.4 - Safe Repair
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0SAFE-REPAIR-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo Safe Repair did not reach READY/DEGRADED successfully.
  pause
)
exit /b %RC%

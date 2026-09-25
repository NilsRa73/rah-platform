@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio v3.1 Candidate.4
set "CHECK=%~dp0RAH-RAVEN-STUDIO-V3.1-CANDIDATE.4.ps1"
if not exist "%CHECK%" (
  echo [FAIL] Mangler Candidate.4 acceptance script.
  pause
  exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CHECK%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" pause
exit /b %RC%

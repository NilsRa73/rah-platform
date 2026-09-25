@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio 3.1 Candidate
set "STUDIO=%~dp0RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
if not exist "%STUDIO%" (
  echo [FAIL] Mangler RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html
  pause
  exit /b 2
)
start "" "%STUDIO%"
exit /b 0

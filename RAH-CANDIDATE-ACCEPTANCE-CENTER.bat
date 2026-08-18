@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Candidate Acceptance Center

set "SCRIPT=%~dp0RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: Candidate Acceptance Center script was not found:
  echo %SCRIPT%
  exit /b 1
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: Windows PowerShell was not found.
  exit /b 1
)

echo ================================================================
echo RAH CANDIDATE ACCEPTANCE CENTER
echo ================================================================
echo Stable promotion is ALWAYS blocked by this launcher.
echo It only starts existing owned-machine acceptance kits.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %ERRORLEVEL%

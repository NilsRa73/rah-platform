@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Candidate Acceptance Suite - Studio 2.9

set "CENTER_PS1=%~dp0RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1"

if not exist "%CENTER_PS1%" (
  echo ERROR: Candidate Acceptance Center script is missing:
  echo %CENTER_PS1%
  exit /b 1
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: Windows PowerShell was not found.
  exit /b 1
)

if /I "%~1"=="--self-test" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CENTER_PS1%" -SelfTest
  exit /b %ERRORLEVEL%
)

echo ================================================================
echo RAH CANDIDATE ACCEPTANCE SUITE
echo ================================================================
echo Current Candidate: RAH Raven Studio 2.9
echo Daily Driver 1.0 and AI Investigator 1.0 are Stable.
echo Stable promotion remains BLOCKED from this suite.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CENTER_PS1%" -Target studio
set "RC=%ERRORLEVEL%"
echo.
echo Studio Candidate acceptance exited with code %RC%.
echo Stable promotion remains BLOCKED.
exit /b %RC%

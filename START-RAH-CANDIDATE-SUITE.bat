@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Candidate Acceptance Suite - No Current Candidates

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
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CENTER_PS1%" -SelfTest
) else (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CENTER_PS1%"
)
exit /b %ERRORLEVEL%

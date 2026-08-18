@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Candidate Acceptance Suite

set "CENTER=%~dp0RAH-CANDIDATE-ACCEPTANCE-CENTER.bat"
set "CENTER_PS1=%~dp0RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1"

if not exist "%CENTER%" (
  echo ERROR: Candidate Acceptance Center is missing:
  echo %CENTER%
  exit /b 1
)
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

echo.
echo ================================================================
echo RAH CANDIDATE ACCEPTANCE SUITE
echo ================================================================
echo Opening the fixed fail-closed Candidate Acceptance Center.
echo Target-specific setup runs only after you choose a Candidate.
echo Stable promotion remains BLOCKED.
echo.
call "%CENTER%"
exit /b %ERRORLEVEL%

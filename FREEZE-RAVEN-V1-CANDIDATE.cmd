@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven v1 - Freeze Candidate

set "PS=%~dp0raven\windows\FREEZE-RAVEN-V1-CANDIDATE.ps1"
if /I "%~1"=="--self-test" (
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PS%" -SelfTest
  exit /b %ERRORLEVEL%
)

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PS%" -SourceRoot "%~dp0"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo [PASS] Raven v1 Candidate er frosset med SHA-256 manifest.
) else (
  echo [FAIL] Freeze ble blokkert. Final acceptance maa vaere PASS.
)
pause
exit /b %RC%

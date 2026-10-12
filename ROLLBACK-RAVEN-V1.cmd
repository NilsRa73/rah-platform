@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven v1 - Safe Rollback

set "PS=%~dp0raven\windows\ROLLBACK-RAVEN-V1.ps1"
if /I "%~1"=="--self-test" (
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PS%" -SelfTest
  exit /b %ERRORLEVEL%
)

echo.
echo RAH RAVEN V1 - SAFE OVERLAY ROLLBACK
echo Verifies SHA-256, backs up current files, then restores known-good files.
echo No files are deleted.
echo.
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PS%" -TargetRoot "%~dp0"
set "RC=%ERRORLEVEL%"
pause
exit /b %RC%

@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Browser - Legacy Redirect

echo.
echo ============================================================
echo  Denne gamle starteren er erstattet av Raven Browser v1.3.
echo  Sender videre til canonical one-click launcher.
echo ============================================================
echo.

if not exist "%~dp0START-HER-RAH-RAVEN-BROWSER.cmd" (
  echo [FAIL] Mangler START-HER-RAH-RAVEN-BROWSER.cmd
  echo Hent siste main fra rah-platform og prov igjen.
  pause
  exit /b 2
)

call "%~dp0START-HER-RAH-RAVEN-BROWSER.cmd"
exit /b %ERRORLEVEL%

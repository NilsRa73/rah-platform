@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven - START HER

set "CORE=%~dp0RavenCore7\RAVEN-CORE-7.ps1"
if not exist "%CORE%" set "CORE=%~dp0RAVEN-CORE-7.ps1"
set "WHEEL=%~dp0RAH-RAVEN-COMMAND-WHEEL.html"

if not exist "%CORE%" (
  echo.
  echo ============================================================
  echo RAH RAVEN CORE 7.0: CORE FILE MISSING
  echo ============================================================
  if exist "%~dp0INSTALL-RAVEN-CORE-7.cmd" (
    echo Running the fixed Core 7 installer...
    call "%~dp0INSTALL-RAVEN-CORE-7.cmd"
    exit /b %ERRORLEVEL%
  )
  echo INSTALL-RAVEN-CORE-7.cmd was not found.
  echo Re-download the Raven Core 7 package.
  pause
  exit /b 2
)

echo.
echo ============================================================
echo               RAH RAVEN - START HER
echo ============================================================
echo  PRECHECK ^> SAFE REPAIR ^> POSTCHECK ^> START ^> LAUNCHER
echo  Node Agent remains explicit. No arbitrary shell.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CORE%" -Mode Start
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo Raven Core 7 returned code %EC%.
  echo Run DIAGNOSTICS.cmd for the detailed status report.
  pause
  exit /b %EC%
)

if exist "%WHEEL%" (
  start "" "%WHEEL%"
) else (
  start "" "https://nilsra73.github.io/rah-platform/RAH-RAVEN-COMMAND-WHEEL.html"
)

exit /b 0

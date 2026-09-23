@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Core 7.0 - START HER

set "CORE=%~dp0RavenCore7\RAVEN-CORE-7.ps1"
if not exist "%CORE%" set "CORE=%~dp0RAVEN-CORE-7.ps1"

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
echo              RAH RAVEN CORE 7.0
echo ============================================================
echo  PRECHECK ^> SAFE REPAIR IF NEEDED ^> POSTCHECK ^> START
echo  Node Agent remains explicit. No arbitrary shell.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CORE%" -Mode Start
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo Raven Core 7 returned code %EC%.
  echo Run DIAGNOSTICS.cmd for the detailed status report.
  pause
)
exit /b %EC%

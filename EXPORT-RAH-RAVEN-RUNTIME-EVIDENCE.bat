@echo off
setlocal
cd /d "%~dp0"
title RAH Raven Runtime Evidence Export

set "APP=%~dp0apps\rah-raven-daily-driver"
set "SCRIPT=%APP%\evidence_bundle.py"
set "PY=%APP%\.venv\Scripts\python.exe"

if not exist "%SCRIPT%" (
  echo ERROR: Runtime Evidence exporter was not found:
  echo %SCRIPT%
  exit /b 1
)

if not exist "%PY%" (
  where python >nul 2>nul
  if errorlevel 1 (
    echo ERROR: Python was not found. Run INSTALL-RAH-RAVEN.bat first.
    exit /b 1
  )
  set "PY=python"
)

echo Creating privacy-safe Runtime Evidence bundle...
"%PY%" "%SCRIPT%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo ERROR: Runtime Evidence export failed with code %RC%.
  exit /b %RC%
)

echo.
echo Evidence bundle created under:
echo %APP%\runtime\exports
exit /b 0

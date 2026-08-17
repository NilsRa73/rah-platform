@echo off
setlocal
cd /d "%~dp0"
title RAH Raven Daily Driver Runtime Gate

set "GATE=%~dp0apps\rah-raven-daily-driver\RUNTIME-GATE-RAH-RAVEN.bat"
set "EVIDENCE=%~dp0EXPORT-RAH-RAVEN-RUNTIME-EVIDENCE.bat"

if not exist "%GATE%" (
  echo ERROR: Runtime Gate was not found:
  echo %GATE%
  exit /b 1
)

if "%~1"=="" (
  call "%GATE%"
) else (
  call "%GATE%" "%~1"
)
set "GATE_RC=%ERRORLEVEL%"

echo.
if exist "%EVIDENCE%" (
  call "%EVIDENCE%"
  if errorlevel 1 echo WARNING: Evidence export failed; Runtime Gate result is still preserved.
) else (
  echo WARNING: Evidence exporter was not found: %EVIDENCE%
)

exit /b %GATE_RC%

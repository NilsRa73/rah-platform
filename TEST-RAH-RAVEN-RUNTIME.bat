@echo off
setlocal
cd /d "%~dp0"
title RAH Raven Daily Driver Runtime Gate

set "GATE=%~dp0apps\rah-raven-daily-driver\RUNTIME-GATE-RAH-RAVEN.bat"
if not exist "%GATE%" (
  echo ERROR: Runtime Gate was not found:
  echo %GATE%
  pause
  exit /b 1
)

if "%~1"=="" (
  call "%GATE%"
) else (
  call "%GATE%" "%~1"
)

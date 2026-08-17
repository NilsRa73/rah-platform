@echo off
setlocal
cd /d "%~dp0apps\rah-raven-daily-driver"
title RAH Raven - Promote to Runtime Test

set "PY=.venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"

"%PY%" promote_runtime_test.py
if errorlevel 1 (
  echo.
  echo Promotion was blocked. Complete the required Runtime Gate checks first.
)
pause

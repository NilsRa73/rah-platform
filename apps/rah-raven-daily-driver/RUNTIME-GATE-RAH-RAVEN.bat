@echo off
setlocal
cd /d "%~dp0"
title RAH Raven Daily Driver Runtime Gate

set "PY=.venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"

echo ============================================================
echo   RAH RAVEN DAILY DRIVER - WINDOWS RUNTIME GATE
echo ============================================================
echo.

if "%~1"=="" (
  "%PY%" runtime_check.py
) else (
  "%PY%" runtime_check.py --facebook "%~1"
)
set "RC=%ERRORLEVEL%"

echo.
echo Result is stored in:
echo runtime\state\runtime-gate.json
echo.
if not "%RAH_RAVEN_NONINTERACTIVE%"=="1" pause
exit /b %RC%

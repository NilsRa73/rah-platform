@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven Daily Driver 1.0 - Owned Tool Review

echo.
echo ============================================================
echo   RAH RAVEN DAILY DRIVER 1.0 - OWNED-TOOL EXPORT REVIEW
echo ============================================================
echo   No external OSINT tool is launched by this gate.
echo   It only reviews export files that you explicitly select.
echo   Stable promotion remains BLOCKED.
echo.

set "PY="
if exist "%~dp0.venv\Scripts\python.exe" set "PY=%~dp0.venv\Scripts\python.exe"
if not defined PY where py.exe >nul 2>nul && set "PY=py.exe"
if not defined PY where python.exe >nul 2>nul && set "PY=python.exe"

if not defined PY (
  for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python*") do if exist "%%D\python.exe" set "PY=%%D\python.exe"
)
if not defined PY (
  for /d %%D in ("%LOCALAPPDATA%\Python\pythoncore-*") do if exist "%%D\python.exe" set "PY=%%D\python.exe"
)

if not defined PY (
  echo ERROR: Python 3 was not found.
  pause
  exit /b 1
)

echo [1/2] Deterministic local self-test...
if /I "%PY%"=="py.exe" (
  py.exe -3 "%~dp0FINAL-OWNED-TOOL-REVIEW.py" --self-test
) else (
  "%PY%" "%~dp0FINAL-OWNED-TOOL-REVIEW.py" --self-test
)
if errorlevel 1 (
  echo.
  echo [STOP] Self-test failed. No real export review was started.
  pause
  exit /b 1
)

echo.
echo [2/2] Review your three owned/authorized export files...
if /I "%PY%"=="py.exe" (
  py.exe -3 "%~dp0FINAL-OWNED-TOOL-REVIEW.py"
) else (
  "%PY%" "%~dp0FINAL-OWNED-TOOL-REVIEW.py"
)
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo [PASS] All three owned-tool export reviews passed.
  echo        This alone does NOT promote or declare Stable.
  echo        The canonical ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat combines all evidence.
) else if "%RC%"=="2" (
  echo [PARTIAL] One or more owned-tool export reviews are incomplete.
) else (
  echo [STOP] Review gate stopped with exit code %RC%.
)
echo.
pause
exit /b %RC%

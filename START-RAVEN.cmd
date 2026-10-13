@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven - One Click

echo.
echo  RAH RAVEN - ONE CLICK
echo  =====================
echo  Project registry ^> precheck ^> Raven local chain
echo.

set "PY="
where py >nul 2>nul && set "PY=py"
if not defined PY (
  where python >nul 2>nul && set "PY=python"
)

if not defined PY (
  echo [FAIL] Python is not on PATH.
  echo        Install Python 3.10 or newer and run this file again.
  exit /b 1
)

echo [PRECHECK 1/4] Validating Raven project registry...
%PY% raven\raven_registry.py
if errorlevel 1 (
  echo.
  echo [FAIL] Project registry validation failed.
  exit /b 1
)

echo [PRECHECK 2/4] Checking required Raven files...
if not exist "desktop-bridge\start-raven-vision.bat" (
  echo [FAIL] desktop-bridge\start-raven-vision.bat was not found.
  exit /b 1
)
if not exist "mission-engine.js" (
  echo [FAIL] mission-engine.js was not found.
  exit /b 1
)
if not exist "project-registry.js" (
  echo [FAIL] project-registry.js was not found.
  exit /b 1
)

echo [PRECHECK 3/4] Running Raven registry tests...
%PY% -m unittest discover -s raven\tests -v
if errorlevel 1 (
  echo.
  echo [FAIL] Raven registry tests failed.
  exit /b 1
)

echo.
echo [PRECHECK 4/4] Checking Raven Bridge Python environment...
call "raven\windows\PREPARE-RAVEN-BRIDGE.cmd" --check
if errorlevel 1 (
  echo.
  echo [FAIL] Raven Bridge Python environment is not healthy.
  exit /b 1
)

if /I "%~1"=="--check" (
  echo.
  echo RESULT: PASS - Raven Candidate Windows precheck is ready.
  exit /b 0
)

echo.
echo [REPAIR] Preparing Raven Bridge environment...
call "raven\windows\PREPARE-RAVEN-BRIDGE.cmd"
if errorlevel 1 (
  echo.
  echo [FAIL] Raven Bridge environment repair failed.
  exit /b 1
)

echo.
echo [START] Launching the existing Raven Vision local chain...
call "desktop-bridge\start-raven-vision.bat"
set "RAVEN_EXIT=%errorlevel%"

echo.
if "%RAVEN_EXIT%"=="0" (
  echo RESULT: PASS - Raven launcher completed without a reported error.
) else (
  echo RESULT: FAIL - Raven launcher returned exit code %RAVEN_EXIT%.
)
exit /b %RAVEN_EXIT%

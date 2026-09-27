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

if defined PY (
  echo [PRECHECK] Validating Raven project registry...
  %PY% raven\raven_registry.py
  if errorlevel 1 (
    echo.
    echo [WARN] Project registry reported a validation problem.
    echo        Raven Vision startup can still be attempted.
    echo.
  )
) else (
  echo [WARN] Python is not on PATH. The Raven Vision launcher will handle setup guidance.
)

if not exist "desktop-bridge\start-raven-vision.bat" (
  echo.
  echo [FAIL] desktop-bridge\start-raven-vision.bat was not found.
  echo        Run this launcher from the rah-platform repository root.
  pause
  exit /b 1
)

call "desktop-bridge\start-raven-vision.bat"
exit /b %errorlevel%

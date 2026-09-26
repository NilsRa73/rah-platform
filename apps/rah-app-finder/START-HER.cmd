@echo off
setlocal
cd /d "%~dp0"
title RAH APP FINDER v1 - INSTALL + SCAN
echo ============================================================
echo   RAH APP FINDER v1 - INSTALL / RESCAN / SHORTCUT REPAIR
echo ============================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-APP-FINDER.ps1" -Install
if errorlevel 1 (
  echo.
  echo [FAIL] RAH App Finder could not complete.
  pause
  exit /b 1
)
echo.
echo [PASS] RAH TEST HUB and Desktop shortcuts are ready.
timeout /t 2 /nobreak >nul
exit /b 0

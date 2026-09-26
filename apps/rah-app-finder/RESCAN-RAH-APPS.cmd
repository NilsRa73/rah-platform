@echo off
setlocal
cd /d "%~dp0"
title RAH APP FINDER v1 - RESCAN + REPAIR
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-APP-FINDER.ps1"
if errorlevel 1 (
  echo.
  echo [FAIL] Scan or shortcut repair failed.
  pause
  exit /b 1
)
echo.
echo [PASS] Menu and shortcuts refreshed.
timeout /t 2 /nobreak >nul
exit /b 0

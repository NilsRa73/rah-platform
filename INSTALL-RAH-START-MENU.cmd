@echo off
setlocal
cd /d "%~dp0"
title RAH Start Menu v1.0 Installer
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL-RAH-START-MENU.ps1"
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo RAH Start Menu installer failed with code %EC%.
  pause
)
exit /b %EC%

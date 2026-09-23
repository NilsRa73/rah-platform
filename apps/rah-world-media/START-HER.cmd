@echo off
setlocal
cd /d "%~dp0"
title RAH World Media v9.9.1 SMART PREVIEW
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_BOOTSTRAP.ps1"
exit /b %errorlevel%

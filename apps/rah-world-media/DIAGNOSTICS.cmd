@echo off
setlocal
cd /d "%~dp0"
title RAH World Media v12.0 - DIAGNOSTICS
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_BOOTSTRAP.ps1" -Diagnostics
exit /b %errorlevel%

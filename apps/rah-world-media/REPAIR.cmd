@echo off
setlocal
cd /d "%~dp0"
title RAH World Media v12.0 RAVEN SYNC DECK - REPAIR
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_BOOTSTRAP.ps1" -Repair
exit /b %errorlevel%

@echo off
setlocal
cd /d "%~dp0"
title RAH World Media 14.0 RAVEN WORLD GRID - REPAIR
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_BOOTSTRAP.ps1" -Repair
exit /b %errorlevel%

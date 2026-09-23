@echo off
setlocal
cd /d "%~dp0"
title RAH World Media v11.0 RAVEN BROADCAST DECK - REPAIR
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_BOOTSTRAP.ps1" -Repair
exit /b %errorlevel%

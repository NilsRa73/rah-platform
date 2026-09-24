@echo off
setlocal
cd /d "%~dp0"
title RAH World Media 14.0 - SAFE SELF-IMPROVE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_BOOTSTRAP.ps1" -SelfImprove
exit /b %errorlevel%

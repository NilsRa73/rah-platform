@echo off
setlocal
cd /d "%~dp0"
title RAH World Media v14.0 RAVEN SMART CLUSTER
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0RAH_BOOTSTRAP.ps1"
exit /b %errorlevel%

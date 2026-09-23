@echo off
setlocal
cd /d "%~dp0"
title RAH World Media 12.0 RAVEN SYNC DECK - INSTALL
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_INSTALL.ps1"
exit /b %errorlevel%

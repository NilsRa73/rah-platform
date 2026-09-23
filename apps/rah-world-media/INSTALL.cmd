@echo off
setlocal
cd /d "%~dp0"
title RAH World Media 9.9 SUPER MODE - INSTALL
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_INSTALL.ps1"
exit /b %errorlevel%

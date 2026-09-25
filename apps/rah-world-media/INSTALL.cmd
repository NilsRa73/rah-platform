@echo off
setlocal
cd /d "%~dp0"
title RAH World Media 14.0 RAVEN WORLD GRID - INSTALL
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_INSTALL.ps1"
exit /b %errorlevel%

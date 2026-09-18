@echo off
setlocal EnableExtensions
title RAH Raven - Configure Project Memory
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CONFIGURE-RAH-PROJECT-MEMORY.ps1"
exit /b %ERRORLEVEL%

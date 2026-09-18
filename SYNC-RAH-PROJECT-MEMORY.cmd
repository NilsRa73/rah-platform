@echo off
setlocal EnableExtensions
title RAH Raven - Sync Project Memory
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SYNC-RAH-PROJECT-MEMORY.ps1"
exit /b %ERRORLEVEL%

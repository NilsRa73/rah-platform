@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven AI Fabric - One Click
echo.
echo ============================================================
echo              RAH RAVEN AI FABRIC - ONE CLICK
echo ============================================================
echo Raven + Job Executor + Node Agent + LM Studio + AnythingLLM
echo self-test, autostart, watchdog and final acceptance.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL-RAH-AI-FABRIC.ps1" -Mode Install

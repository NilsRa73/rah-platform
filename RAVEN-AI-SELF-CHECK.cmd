@echo off
setlocal EnableExtensions
title RAH Raven AI Self-Check
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAVEN-AI-SELF-CHECK.ps1" -Interactive
exit /b %ERRORLEVEL%

@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio Candidate.5 - Safe Repair
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0SAFE-REPAIR-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.ps1"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" pause
exit /b %RC%

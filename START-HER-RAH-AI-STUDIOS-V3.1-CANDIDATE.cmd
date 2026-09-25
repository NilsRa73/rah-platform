@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH AI Studios v3.1 Candidate.4

set "HELPER=%~dp0RAH-STUDIO-ONE-CLICK.vbs"
set "STUDIO=%~dp0RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"

if not exist "%HELPER%" goto :missing
if not exist "%STUDIO%" goto :missing

rem User-facing entrypoint: no PowerShell and no background console window.
start "" wscript.exe //B //Nologo "%HELPER%"
exit /b 0

:missing
echo.
echo [FAIL] RAH AI Studios Candidate-pakken er ufullstendig.
echo Forventet:
echo   %HELPER%
echo   %STUDIO%
echo.
pause
exit /b 2

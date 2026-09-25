@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Quiet Popups Fix

fltmc >nul 2>&1
if errorlevel 1 (
  echo RAH Quiet Popups trenger Administrator en gang.
  echo Godkjenn Windows UAC-vinduet som kommer na.
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/d','/c','""%~f0"" --elevated' -Verb RunAs"
  exit /b
)

set "RESULT=%TEMP%\RAH-QUIET-POPUPS-%RANDOM%%RANDOM%.txt"
set "FIXER=%~dp0tools\RAH-QUIET-POPUPS.ps1"
if not exist "%FIXER%" (
  echo FAIL: tools\RAH-QUIET-POPUPS.ps1 mangler.
  pause
  exit /b 2
)

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%FIXER%" -ResultPath "%RESULT%"
set "EC=%ERRORLEVEL%"

cls
echo ============================================================
echo               RAH QUIET POPUPS - RESULTAT
echo ============================================================
if exist "%RESULT%" type "%RESULT%"
echo.
if "%EC%"=="0" (
  echo Du kan lukke dette vinduet. RAH-bakgrunnsjobber skal ikke stjele fokus.
) else (
  echo Reparasjonen fant noe som krever ny kontroll. Se resultatet over.
)
if exist "%RESULT%" del /q "%RESULT%" >nul 2>&1
timeout /t 8 /nobreak >nul
exit /b %EC%

@echo off
setlocal
cd /d "%~dp0"
title RAH Raven - Facebook Archive Runtime Gate

echo ============================================================
echo   RAH RAVEN - FACEBOOK / META ARCHIVE GATE
echo ============================================================
echo.
echo Velg Facebook/Meta ZIP-filen i vinduet som aapnes.
echo Ingen filer endres i arkivet.
echo.

set "PICKER=%~dp0pick_facebook_archive.ps1"
set "ARCHIVE="

for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%PICKER%"`) do (
  set "ARCHIVE=%%F"
)

if not defined ARCHIVE (
  echo.
  echo Ingen arkivfil valgt. Testen ble ikke kjort.
  pause
  exit /b 2
)

echo Valgt arkiv:
echo %ARCHIVE%
echo.

set "PY=.venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"

"%PY%" runtime_check.py --facebook "%ARCHIVE%"

echo.
echo Resultat:
echo runtime\state\runtime-gate.json
echo.
pause

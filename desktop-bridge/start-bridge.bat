@echo off
setlocal
cd /d "%~dp0"
title RAH Raven Desktop Bridge

echo.
echo  RAH Raven Desktop Bridge v1.3
echo  ==============================
echo.

where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py"
) else (
  set "PY=python"
)

if not exist ".venv\Scripts\python.exe" (
  echo Creating local Python environment...
  %PY% -m venv .venv
  if errorlevel 1 goto :error
)

echo Installing or checking dependencies...
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -r requirements.txt
if errorlevel 1 goto :error

echo.
echo Starting bridge at http://127.0.0.1:8765
start "" "https://nilsra73.github.io/rah-platform/vision.html"
".venv\Scripts\python.exe" server.py
goto :end

:error
echo.
echo Bridge could not start. Install Python 3.11 or newer, then run this file again.
pause

:end
endlocal

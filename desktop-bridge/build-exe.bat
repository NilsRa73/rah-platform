@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title Build RAH Raven Vision EXE

set "CI_MODE=0"
if /I "%~1"=="--ci" set "CI_MODE=1"

echo.
echo  BUILD RAH RAVEN VISION
ECHO  ======================
echo.

where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py"
) else (
  where python >nul 2>nul
  if errorlevel 1 goto :error
  set "PY=python"
)

if not exist ".venv\Scripts\python.exe" (
  %PY% -m venv .venv
  if errorlevel 1 goto :error
)

".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -r requirements.txt pyinstaller==6.15.0
if errorlevel 1 goto :error

if exist build rmdir /s /q build
if exist dist rmdir /s /q dist

".venv\Scripts\pyinstaller.exe" ^
  --noconfirm ^
  --clean ^
  --onefile ^
  --windowed ^
  --name "RAH-Raven-Vision" ^
  --collect-all pystray ^
  --hidden-import flask_cors ^
  --hidden-import PIL.Image ^
  --add-data "doctor.py;." ^
  --add-data "..\RAH-RAVEN-CHRONICLE-LIVE.html;." ^
  --add-data "..\RAH-RAVEN-INSIGHTS.html;." ^
  --add-data "..\RAH-RAVEN-DAILY-BRIEF.html;." ^
  tray_app.py
if errorlevel 1 goto :error

echo.
echo Build completed:
echo %CD%\dist\RAH-Raven-Vision.exe
echo.
if "%CI_MODE%"=="1" exit /b 0
start "" "%CD%\dist"
pause
exit /b 0

:error
echo.
echo Build failed. Review the error above.
if "%CI_MODE%"=="1" exit /b 1
pause
exit /b 1

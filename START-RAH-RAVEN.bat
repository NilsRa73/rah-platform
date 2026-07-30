@echo off
setlocal
title RAH Raven One Launcher
cd /d "%~dp0"

echo ==========================================
echo        RAH RAVEN ONE - STARTER
echo ==========================================
echo.

if exist "desktop-bridge\start-raven-vision.bat" (
  echo [1/2] Starter Desktop Bridge...
  start "RAH Desktop Bridge" /min cmd /c "cd /d "%~dp0desktop-bridge" && call start-raven-vision.bat"
) else (
  echo [ADVARSEL] Fant ikke desktop-bridge\start-raven-vision.bat
)

timeout /t 2 /nobreak >nul

echo [2/2] Aapner RAH Raven Command Center...
start "" "https://nilsra73.github.io/rah-platform/"

echo.
echo RAH Raven er startet.
timeout /t 3 /nobreak >nul
exit /b 0

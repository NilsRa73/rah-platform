@echo off
setlocal
cd /d "%~dp0"

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo [RAH] Fant ikke Windows PowerShell.
  pause
  exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-HOME-DISCOVERY-RUN.ps1" %*
set "RAH_EXIT=%ERRORLEVEL%"

if not "%RAH_EXIT%"=="0" (
  echo.
  echo [RAH] Discovery Runner feilet med kode %RAH_EXIT%.
  pause
)

exit /b %RAH_EXIT%

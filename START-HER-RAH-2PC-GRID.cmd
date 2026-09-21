@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven OS - 2-PC Grid
if not exist "C:\RAH\2PCProof" mkdir "C:\RAH\2PCProof" >nul 2>&1

echo.
echo ============================================================
echo              RAH RAVEN OS - 2-PC GRID
echo ============================================================
echo  HOVED-PC ^<^> LENOVO
echo  Fixed read-only system.inventory proof
echo  Raven black/gold GUI
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0RAH-RAVEN-2PC-GUI.ps1"
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo FAIL: GUI exited with code %EC%.
  pause
)
exit /b %EC%

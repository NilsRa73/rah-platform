@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven 2-PC Grid v1.2.1 - Final Acceptance

echo.
echo ============================================================
echo        RAH RAVEN 2-PC GRID - REAL HARDWARE ACCEPTANCE
echo ============================================================
echo Runtime: Windows PowerShell/.NET - Python NOT required
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-2PC-ACCEPTANCE.ps1" ^
  -InputPath "C:\RAH\2PCProof\results\last-inventory.json" ^
  -OutputPath "C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json"

if errorlevel 1 (
  echo.
  echo ============================================================
  echo RAH RAVEN 2-PC GRID REAL-HARDWARE ACCEPTANCE: FAIL
  echo ============================================================
  pause
  exit /b 1
)

echo.
echo ============================================================
echo RAH RAVEN 2-PC GRID REAL-HARDWARE ACCEPTANCE: PASS
echo ============================================================
echo Evidence:
echo C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json
echo Hardware registry:
echo C:\RAH\HardwareRegistry\registry.json
echo.
pause
exit /b 0

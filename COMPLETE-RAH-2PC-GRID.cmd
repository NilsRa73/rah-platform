@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven 2-PC Grid - Final Acceptance

echo.
echo ============================================================
echo        RAH RAVEN 2-PC GRID - REAL HARDWARE ACCEPTANCE
echo ============================================================
echo.

set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY (
  where python >nul 2>nul && set "PY=python"
)
if not defined PY (
  echo FAIL: Python 3 not found.
  pause
  exit /b 2
)

%PY% "%~dp0rah_2pc_acceptance.py" ^
  --input "C:\RAH\2PCProof\results\last-inventory.json" ^
  --output "C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json"

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
echo.
pause
exit /b 0

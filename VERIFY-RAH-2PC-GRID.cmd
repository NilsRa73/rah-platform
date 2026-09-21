@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven 2-PC Grid - Verify

echo ============================================================
echo           RAH RAVEN 2-PC GRID - SELF TEST
echo ============================================================

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$e=$null;$t=$null;[System.Management.Automation.Language.Parser]::ParseFile('%~dp0RAH-RAVEN-2PC-GUI.ps1',[ref]$t,[ref]$e)|Out-Null;if($e.Count){$e|%%{Write-Host $_.Message -ForegroundColor Red};exit 2}else{Write-Host 'PASS: PowerShell GUI parse' -ForegroundColor Green}"
if errorlevel 1 goto :fail

where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0rah_2pc_inventory_client.py" --self-test
  if errorlevel 1 goto :fail
  goto :pass
)

where python >nul 2>nul
if not errorlevel 1 (
  python "%~dp0rah_2pc_inventory_client.py" --self-test
  if errorlevel 1 goto :fail
  goto :pass
)

echo FAIL: Python 3 not found.
goto :fail

:pass
echo.
echo ============================================================
echo RAH RAVEN 2-PC GRID: PASS
echo ============================================================
pause
exit /b 0

:fail
echo.
echo ============================================================
echo RAH RAVEN 2-PC GRID: FAIL
echo ============================================================
pause
exit /b 1

@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven 2-PC Grid v1.2.1 - Verify

echo ============================================================
echo        RAH RAVEN 2-PC GRID v1.2.1 - SELF TEST
echo ============================================================
echo Runtime: Windows PowerShell/.NET - Python NOT required
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$files=@('RAH-RAVEN-2PC-GUI.ps1','RAH-2PC-CLIENT.ps1','RAH-2PC-ACCEPTANCE.ps1','RAH-HARDWARE-INVENTORY.ps1','RAH-HARDWARE-REGISTRY.ps1');foreach($f in $files){$e=$null;$t=$null;[System.Management.Automation.Language.Parser]::ParseFile((Join-Path '%~dp0' $f),[ref]$t,[ref]$e)|Out-Null;if($e.Count){$e|ForEach-Object{Write-Host ($f+': '+$_.Message) -ForegroundColor Red};exit 2}};Write-Host 'PASS: PowerShell syntax parse' -ForegroundColor Green"
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-2PC-CLIENT.ps1" -SelfTest
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-2PC-ACCEPTANCE.ps1" -SelfTest
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-HARDWARE-INVENTORY.ps1" -SelfTest
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-HARDWARE-REGISTRY.ps1" -SelfTest
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-RAVEN-2PC-GUI.ps1" -SelfTest
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo RAH RAVEN 2-PC GRID v1.2.1: PASS
echo Python dependency: NONE
echo Hardware Registry : READY
echo ============================================================
pause
exit /b 0

:fail
echo.
echo ============================================================
echo RAH RAVEN 2-PC GRID v1.2.1: FAIL
echo ============================================================
pause
exit /b 1

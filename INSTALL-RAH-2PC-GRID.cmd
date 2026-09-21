@echo off
setlocal EnableExtensions
title RAH Raven OS - 2-PC Grid Installer

set "ROOT=C:\RAH\2PCProof"
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1

echo.
echo ============================================================
echo          RAH RAVEN OS - 2-PC GRID INSTALLER
echo ============================================================
echo  Destination: %ROOT%
echo  Source     : NilsRa73/rah-platform main
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$root='C:\RAH\2PCProof';" ^
  "$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/main';" ^
  "$files=@('START-HER-RAH-2PC-GRID.cmd','VERIFY-RAH-2PC-GRID.cmd','RAH-RAVEN-2PC-GUI.ps1','rah_2pc_inventory_client.py','RAH-2PC-GRID.md');" ^
  "New-Item -ItemType Directory -Force -Path $root,(Join-Path $root 'results'),(Join-Path $root 'logs')|Out-Null;" ^
  "foreach($f in $files){$dst=Join-Path $root $f;$tmp=$dst+'.download';Write-Host ('GET  '+$f) -ForegroundColor DarkYellow;Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$f) -OutFile $tmp;if((Get-Item -LiteralPath $tmp).Length -lt 10){throw ('Invalid download: '+$f)};Move-Item -LiteralPath $tmp -Destination $dst -Force};" ^
  "Write-Host 'PASS: RAH 2-PC Grid package installed.' -ForegroundColor Green"
if errorlevel 1 goto :fail

cd /d "%ROOT%"
call VERIFY-RAH-2PC-GRID.cmd
if errorlevel 1 goto :fail

start "" "%ROOT%\START-HER-RAH-2PC-GRID.cmd"
exit /b 0

:fail
echo.
echo FAIL: RAH Raven 2-PC Grid installation or self-test failed.
pause
exit /b 1

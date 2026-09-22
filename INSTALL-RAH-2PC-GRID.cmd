@echo off
setlocal EnableExtensions
title RAH Raven OS - 2-PC Grid v1.3.0 Installer

set "ROOT=C:\RAH\2PCProof"
set "REF=main"
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1

echo.
echo ============================================================
echo       RAH RAVEN OS - 2-PC GRID v1.3.0 INSTALLER
echo ============================================================
echo  Destination: %ROOT%
echo  Source ref : %REF%
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$root='C:\RAH\2PCProof';" ^
  "$ref='%REF%';" ^
  "$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/'+$ref;" ^
  "$files=@('START-HER-RAH-2PC-GRID.cmd','VERIFY-RAH-2PC-GRID.cmd','COMPLETE-RAH-2PC-GRID.cmd','RAH-RAVEN-2PC-GUI.ps1','RAH-2PC-CLIENT.ps1','RAH-2PC-ACCEPTANCE.ps1','RAH-HARDWARE-INVENTORY.ps1','RAH-HARDWARE-REGISTRY.ps1','RAH-2PC-GRID.md');" ^
  "New-Item -ItemType Directory -Force -Path $root,(Join-Path $root 'results'),(Join-Path $root 'logs')|Out-Null;" ^
  "[IO.File]::WriteAllText((Join-Path $root 'RAH-2PC-SOURCE-REF.txt'),$ref,[Text.UTF8Encoding]::new($false));" ^
  "foreach($f in $files){$dst=Join-Path $root $f;$tmp=$dst+'.download';Write-Host ('GET  '+$f) -ForegroundColor DarkYellow;Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$f) -OutFile $tmp;if((Get-Item -LiteralPath $tmp).Length -lt 10){throw ('Invalid download: '+$f)};Move-Item -LiteralPath $tmp -Destination $dst -Force};" ^
  "Write-Host 'PASS: RAH 2-PC Grid v1.3.0 package installed from one pinned source ref - operator runtime needs no Python.' -ForegroundColor Green"
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

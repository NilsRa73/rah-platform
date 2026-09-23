@echo off
setlocal EnableExtensions
title RAH Raven Core 7.0 - Installer
set "RAHROOT=C:\RAH"
set "COREROOT=C:\RAH\RavenCore7"
set "REF=main"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent(); if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 42}"
if "%ERRORLEVEL%"=="42" (
  echo Requesting Administrator permission for C:\RAH installation...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo.
echo ============================================================
echo             RAH RAVEN CORE 7.0 INSTALLER
echo ============================================================
echo  Destination: C:\RAH
echo  Source ref : %REF%
echo  Fixed allowlist only.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$rah='C:\RAH';$core='C:\RAH\RavenCore7';$ref='%REF%';" ^
  "$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/'+$ref;" ^
  "$rootFiles=@('START-HER.cmd','DIAGNOSTICS.cmd','REPAIR.cmd','WORKER-PROOF.cmd','ACCEPT-RAVEN-CORE-7.cmd','INSTALL-RAVEN-CORE-7.cmd');" ^
  "$coreFiles=@('RAVEN-CORE-7.ps1','RAVEN-CORE-7-WORKER-PROOF.ps1','RAVEN-CORE-7-ACCEPTANCE.ps1','RAVEN-CORE-7-CONFIG.json','RAVEN-CORE-7.md');" ^
  "New-Item -ItemType Directory -Force -Path $rah,$core,(Join-Path $core 'state'),(Join-Path $core 'logs')|Out-Null;" ^
  "foreach($f in $rootFiles){$dst=Join-Path $rah $f;$tmp=$dst+'.download';Write-Host ('GET  '+$f) -ForegroundColor DarkYellow;Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$f) -OutFile $tmp;if((Get-Item -LiteralPath $tmp).Length -lt 20){throw ('Invalid download: '+$f)};Move-Item -LiteralPath $tmp -Destination $dst -Force};" ^
  "foreach($f in $coreFiles){$dst=Join-Path $core $f;$tmp=$dst+'.download';Write-Host ('GET  '+$f) -ForegroundColor DarkYellow;Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$f) -OutFile $tmp;if((Get-Item -LiteralPath $tmp).Length -lt 20){throw ('Invalid download: '+$f)};Move-Item -LiteralPath $tmp -Destination $dst -Force};" ^
  "[IO.File]::WriteAllText((Join-Path $core 'SOURCE-REF.txt'),$ref,[Text.UTF8Encoding]::new($false));" ^
  "$ws=New-Object -ComObject WScript.Shell;" ^
  "$desktop=[Environment]::GetFolderPath('Desktop');$start=[Environment]::GetFolderPath('StartMenu');" ^
  "$s=$ws.CreateShortcut((Join-Path $desktop 'RAH Raven Core 7.lnk'));$s.TargetPath='C:\RAH\START-HER.cmd';$s.WorkingDirectory='C:\RAH';$s.Save();" ^
  "$menu=Join-Path $start 'Programs\RAH Raven';New-Item -ItemType Directory -Force -Path $menu|Out-Null;" ^
  "$s=$ws.CreateShortcut((Join-Path $menu 'RAH Raven Core 7.lnk'));$s.TargetPath='C:\RAH\START-HER.cmd';$s.WorkingDirectory='C:\RAH';$s.Save();" ^
  "Write-Host 'PASS: Raven Core 7 foundation installed.' -ForegroundColor Green"
if errorlevel 1 goto :fail

if not exist "C:\RAH\RavenOS\START-HER-RAH-OS.cmd" (
  echo Front Door is not installed under C:\RAH\RavenOS.
  echo Core 7 will report this as a repairable dependency.
)

call "C:\RAH\START-HER.cmd"
exit /b %ERRORLEVEL%

:fail
echo.
echo ============================================================
echo RAH RAVEN CORE 7 INSTALL: FAIL
echo ============================================================
pause
exit /b 1

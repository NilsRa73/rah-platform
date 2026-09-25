@echo off
setlocal EnableExtensions
set "ROOT=C:\RAH\RavenOS"
if defined RAH_OS_SOURCE_REF (set "REF=%RAH_OS_SOURCE_REF%") else (set "REF=f9624bee3f63c7a9e2b09f8b6f9eb195a1515b3f")
title RAH OS v0.8 - Installer

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent();if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 42}"
if "%ERRORLEVEL%"=="42" (
  echo Requesting Administrator permission...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo.
echo ============================================================
echo                 RAH OS v0.8 INSTALLER
echo ============================================================
echo  Destination : %ROOT%
echo  Source ref  : %REF%
echo  Mode        : backup - install - verify
echo.

if exist "%ROOT%" (
  for /f "tokens=1-4 delims=/-. " %%a in ("%date%") do set "DS=%%d%%c%%b"
  for /f "tokens=1-3 delims=:,. " %%a in ("%time%") do set "TS=%%a%%b%%c"
  set "BACKUP=C:\RAH\_BACKUP\RavenOS-v0.8-%DS%-%TS%"
  mkdir "%BACKUP%" >nul 2>&1
  robocopy "%ROOT%" "%BACKUP%" /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
  echo BACKUP    %BACKUP%
)

if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1
if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1
if not exist "%ROOT%\state" mkdir "%ROOT%\state" >nul 2>&1

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';" ^
 "$root='%ROOT%';$ref='%REF%';$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/'+$ref;" ^
 "$files=@('START-HER-RAH-OS-v0.8.cmd','RAH-OS-v0.8-FINALIZE.ps1','INSTALL-RAH-OS-v0.8.cmd','REPAIR-RAH-OS-v0.8.cmd','RAH-OS-v0.8-CONTROL.ps1','RAH-OS-v0.8-SELFTEST.ps1','RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.cmd','RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1','RAVEN-CORE-7.ps1','RAVEN-AI-SELF-CHECK.ps1','TEST-ANYTHINGLLM-APPROVAL.ps1','RAVEN-CORE-7-WORKER-PROOF.ps1','INSTALL-RAH-AI-FABRIC.ps1','CONFIGURE-RAH-PROJECT-MEMORY.ps1','CONFIGURE-RAH-PROJECT-MEMORY.cmd','SYNC-RAH-PROJECT-MEMORY.ps1','SYNC-RAH-PROJECT-MEMORY.cmd','RAH-RAVEN-2PC-GUI.ps1','RAH-2PC-CLIENT.ps1','RAH-2PC-ACCEPTANCE.ps1','RAH-HARDWARE-INVENTORY.ps1','RAH-HARDWARE-REGISTRY.ps1','START-RAH-AI-FABRIC.cmd','WORKER-PROOF.cmd','DIAGNOSTICS.cmd','RAH-OS-v0.8-PLAN.md');" ^
 "foreach($f in $files){$dst=Join-Path $root $f;$tmp=$dst+'.download';Write-Host ('GET       '+$f) -ForegroundColor DarkYellow;Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$f) -OutFile $tmp;if((Get-Item -LiteralPath $tmp).Length -lt 20){throw ('Invalid download: '+$f)};Move-Item -LiteralPath $tmp -Destination $dst -Force};" ^
 "$aliases=@{'START-HER-RAH-OS-v0.8.cmd'='START-HER-RAH-OS.cmd';'INSTALL-RAH-OS-v0.8.cmd'='INSTALL-RAH-OS.cmd';'REPAIR-RAH-OS-v0.8.cmd'='REPAIR-RAH-OS.cmd';'RAH-OS-v0.8-CONTROL.ps1'='RAH-OS-CONTROL.ps1';'RAH-OS-v0.8-SELFTEST.ps1'='RAH-OS-SELFTEST.ps1'};" ^
 "foreach($src in $aliases.Keys){Copy-Item -LiteralPath (Join-Path $root $src) -Destination (Join-Path $root $aliases[$src]) -Force};Copy-Item -LiteralPath (Join-Path $root 'START-HER-RAH-OS-v0.8.cmd') -Destination (Join-Path $root 'START-HER.cmd') -Force;Copy-Item -LiteralPath (Join-Path $root 'START-HER-RAH-OS-v0.8.cmd') -Destination 'C:\RAH\START-HER.cmd' -Force;" ^
 "[IO.File]::WriteAllText((Join-Path $root 'RAH-OS-SOURCE-REF.txt'),$ref,[Text.UTF8Encoding]::new($false))"
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\RAH-OS-v0.8-SELFTEST.ps1"
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';$ws=New-Object -ComObject WScript.Shell;$target='%ROOT%\START-HER-RAH-OS-v0.8.cmd';" ^
 "$links=@((Join-Path ([Environment]::GetFolderPath('Desktop')) 'RAH OS v0.8.lnk'),(Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\RAH OS v0.8.lnk'));" ^
 "foreach($link in $links){New-Item -ItemType Directory -Force -Path (Split-Path -Parent $link)|Out-Null;$s=$ws.CreateShortcut($link);$s.TargetPath=$target;$s.WorkingDirectory='%ROOT%';$s.Description='RAH OS v0.8 Front Door';$s.Save()}"
if errorlevel 1 goto :fail

if /I "%RAH_OS_RUN_ACCEPTANCE%"=="1" (
  call "%ROOT%\RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.cmd"
  exit /b %ERRORLEVEL%
)

if /I "%RAH_OS_NO_LAUNCH%"=="1" exit /b 0
call "%ROOT%\START-HER-RAH-OS-v0.8.cmd"
exit /b %ERRORLEVEL%

:fail
echo.
echo ============================================================
echo RAH OS v0.8 INSTALL: FAIL
echo ============================================================
echo Existing installation was backed up before replacement when present.
pause
exit /b 1

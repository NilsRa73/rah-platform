@echo off
setlocal EnableExtensions
title RAH HOME - FINALIZE

if not defined RAH_URL set "RAH_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-FINALIZE.ps1"
if not defined RAH_MARKER set "RAH_MARKER=RahHomeFinalizeVersion = '1.0.0'"
set "RAH_MODE=Auto"
set "RAH_SELFTEST=0"

if /I "%~1"=="--self-test" set "RAH_SELFTEST=1"
if /I "%~1"=="--leader" set "RAH_MODE=Leader"
if /I "%~1"=="--worker" set "RAH_MODE=Worker"
if /I "%~1"=="__ADMIN__" (
  if not "%~2"=="" set "RAH_MODE=%~2"
  goto BOOT
)

if "%RAH_SELFTEST%"=="1" goto BOOT
net session >nul 2>&1
if "%ERRORLEVEL%"=="0" goto BOOT

echo [RAH] Sluttbatchen trenger Administrator for installasjon, firewall og autostart.
echo [RAH] Windows viser UAC. Velg Ja.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -Verb RunAs -ArgumentList '/c','""%~f0"" __ADMIN__ %RAH_MODE%'"
exit /b 0

:BOOT
if "%RAH_SELFTEST%"=="1" (
  set "RAH_BOOT=%TEMP%\RAH-Home-Finalize-SelfTest"
) else (
  set "RAH_BOOT=C:\RAH\Bootstrap"
)
set "RAH_SCRIPT=%RAH_BOOT%\RAH-HOME-FINALIZE.ps1"
if not exist "%RAH_BOOT%" mkdir "%RAH_BOOT%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT

echo.
echo [RAH] Henter og validerer RAH Home Finalize v1 ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_SCRIPT;Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_URL -OutFile $p;$i=Get-Item -LiteralPath $p;if($i.Length -le 0 -or $i.Length -gt 4194304){throw 'Ugyldig finalize-fil.'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not $s.Contains($env:RAH_MARKER)){throw 'Manglende Finalize v1-markor.'}"
if errorlevel 1 goto FAIL_DOWNLOAD

if "%RAH_SELFTEST%"=="1" (
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -SelfTest
  if errorlevel 1 goto FAIL_SELFTEST
  echo [RAH] START-HER bootstrap + Finalize self-test PASS.
  exit /b 0
)

echo [RAH] Starter stor PRECHECK - REPAIR - TEST - REPORT batch ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -Mode %RAH_MODE% -InstallRoot "C:\RAH\Home"
set "RAH_EXIT=%ERRORLEVEL%"
echo.
if "%RAH_EXIT%"=="0" (
  echo =============================================================
  echo RAH HOME FINALIZE: PASS
  echo Rapport: C:\RAH\Home\RAH-HOME-FINAL-REPORT.txt
  echo =============================================================
) else (
  echo =============================================================
  echo RAH HOME FINALIZE: FAIL - kode %RAH_EXIT%
  echo Rapport: C:\RAH\Home\RAH-HOME-FINAL-REPORT.txt
  echo =============================================================
)
pause
exit /b %RAH_EXIT%

:FAIL_BOOT
echo [RAH] FAIL: kunne ikke opprette bootstrap-mappen.
if not "%RAH_SELFTEST%"=="1" pause
exit /b 20

:FAIL_DOWNLOAD
echo [RAH] FAIL: finalize-script kunne ikke lastes ned eller valideres.
if not "%RAH_SELFTEST%"=="1" pause
exit /b 21

:FAIL_SELFTEST
echo [RAH] FAIL: Finalize self-test feilet.
exit /b 22

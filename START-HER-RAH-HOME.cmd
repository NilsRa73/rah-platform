@echo off
setlocal EnableExtensions
title RAH HOME - FINALIZE

if not defined RAH_URL set "RAH_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-FINALIZE.ps1"
if not defined RAH_MARKER set "RAH_MARKER=RahHomeFinalizeVersion = '1.0.0'"
set "RAH_MODE=Auto"
set "RAH_SELFTEST=0"
set "RAH_SELF_PATH=%~f0"

if /I "%~1"=="--self-test" set "RAH_SELFTEST=1"
if /I "%~1"=="--leader" set "RAH_MODE=Leader"
if /I "%~1"=="--worker" set "RAH_MODE=Worker"
if /I "%~1"=="__RAH_ADMIN__" (
  if not "%~2"=="" set "RAH_MODE=%~2"
  goto VERIFY_ADMIN
)

if "%RAH_SELFTEST%"=="1" goto BOOT

fltmc >nul 2>&1
if "%ERRORLEVEL%"=="0" goto VERIFY_ADMIN

echo [RAH] Administrator kreves. Starter samme fil med UAC automatisk ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Start-Process -FilePath $env:RAH_SELF_PATH -Verb RunAs -ArgumentList @('__RAH_ADMIN__',$env:RAH_MODE)"
if errorlevel 1 goto FAIL_UAC
exit /b 0

:VERIFY_ADMIN
fltmc >nul 2>&1
if errorlevel 1 goto FAIL_NOT_ADMIN
echo [RAH] Administrator: OK
goto BOOT

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

:FAIL_UAC
echo [RAH] FAIL: UAC-elevasjon kunne ikke startes eller ble avbrutt.
pause
exit /b 18

:FAIL_NOT_ADMIN
echo [RAH] FAIL: prosessen er fortsatt ikke Administrator etter UAC.
echo [RAH] Ingen installasjon, firewall eller autostart ble startet.
pause
exit /b 19

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

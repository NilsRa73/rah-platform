@echo off
setlocal EnableExtensions
title RAH HOME - HOVED-PC ACCEPTANCE

set "RAH_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-ACCEPTANCE.ps1"
set "RAH_MARKER=RahHomeAcceptanceVersion = '1.0.0'"

if /I "%~1"=="--self-test" goto SELFTEST
if /I "%~1"=="__ADMIN__" goto ADMIN

net session >nul 2>&1
if "%ERRORLEVEL%"=="0" goto ADMIN

echo RAH Home Acceptance trenger Administrator for a bruke C:\RAH\Home.
echo Windows viser na UAC. Velg Ja.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -Verb RunAs -ArgumentList '/c','""%~f0"" __ADMIN__'"
exit /b 0

:ADMIN
set "RAH_BOOT=C:\RAH\Bootstrap"
set "RAH_SCRIPT=%RAH_BOOT%\RAH-HOME-ACCEPTANCE.ps1"
if not exist "%RAH_BOOT%" mkdir "%RAH_BOOT%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT
goto DOWNLOAD

:SELFTEST
set "RAH_BOOT=%TEMP%\RAH-Home-Acceptance-SelfTest"
set "RAH_SCRIPT=%RAH_BOOT%\RAH-HOME-ACCEPTANCE.ps1"
if not exist "%RAH_BOOT%" mkdir "%RAH_BOOT%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT

:DOWNLOAD
echo.
echo [RAH] Henter RAH-HOME-ACCEPTANCE.ps1 fra GitHub main ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_SCRIPT;Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_URL -OutFile $p;$i=Get-Item -LiteralPath $p;if($i.Length -le 0 -or $i.Length -gt 4194304){throw 'Ugyldig acceptance-fil.'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not $s.Contains($env:RAH_MARKER)){throw 'Manglende acceptance v1-markor.'}"
if errorlevel 1 goto FAIL_DOWNLOAD

echo [RAH] Self-test ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -SelfTest
if errorlevel 1 goto FAIL_SELFTEST

if /I "%~1"=="--self-test" (
  echo [RAH] CMD bootstrap self-test PASS.
  exit /b 0
)

echo.
echo [RAH] Starter full HOVED-PC acceptance til C:\RAH\Home ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -InstallRoot "C:\RAH\Home"
set "RAH_EXIT=%ERRORLEVEL%"
echo.
if "%RAH_EXIT%"=="0" (
  echo =============================================================
  echo RAH HOME: PASS
  echo Rapport: C:\RAH\Home\RAH-HOME-ACCEPTANCE.txt
  echo =============================================================
) else (
  echo =============================================================
  echo RAH HOME: FAIL - kode %RAH_EXIT%
  echo Se rapport i C:\RAH\Home\RAH-HOME-ACCEPTANCE.txt
  echo =============================================================
)
pause
exit /b %RAH_EXIT%

:FAIL_BOOT
echo [RAH] FAIL: kunne ikke opprette bootstrap-mappen.
if /I not "%~1"=="--self-test" pause
exit /b 20

:FAIL_DOWNLOAD
echo [RAH] FAIL: nedlasting eller validering av acceptance-script feilet.
if /I not "%~1"=="--self-test" pause
exit /b 21

:FAIL_SELFTEST
echo [RAH] FAIL: acceptance self-test feilet. Ingen installasjon ble startet.
if /I not "%~1"=="--self-test" pause
exit /b 22

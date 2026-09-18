@echo off
setlocal EnableExtensions
title RAH MEMORY & STARTUP DOCTOR v1

if not defined RAH_MEMORY_DOCTOR_URL set "RAH_MEMORY_DOCTOR_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-MEMORY-STARTUP-DOCTOR.ps1"
set "RAH_MARKER=RahMemoryDoctorVersion = '1.0.0'"
set "RAH_SELF_PATH=%~f0"
set "RAH_MODE=Interactive"

if /I "%~1"=="--audit" set "RAH_MODE=Audit"
if /I "%~1"=="--self-test" set "RAH_MODE=SelfTest"
if /I "%~1"=="--restore" set "RAH_MODE=RestoreLatest"
if /I "%~1"=="__RAH_ADMIN__" (
  if not "%~2"=="" set "RAH_MODE=%~2"
  goto VERIFY_ADMIN
)

if /I "%RAH_MODE%"=="Audit" goto BOOT
if /I "%RAH_MODE%"=="SelfTest" goto BOOT

fltmc >nul 2>&1
if "%ERRORLEVEL%"=="0" goto VERIFY_ADMIN
echo [RAH] Administrator kreves for interaktiv cleanup/restore. Starter UAC automatisk ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Start-Process -FilePath $env:RAH_SELF_PATH -Verb RunAs -ArgumentList @('__RAH_ADMIN__',$env:RAH_MODE)"
if errorlevel 1 goto FAIL_UAC
exit /b 0

:VERIFY_ADMIN
fltmc >nul 2>&1
if errorlevel 1 goto FAIL_NOT_ADMIN
echo [RAH] Administrator: OK

:BOOT
set "RAH_BOOT=%TEMP%\RAH-Memory-Doctor-Bootstrap"
if not exist "%RAH_BOOT%" mkdir "%RAH_BOOT%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT
set "RAH_SCRIPT=%RAH_BOOT%\RAH-MEMORY-STARTUP-DOCTOR.ps1"

echo [RAH] Henter og validerer Memory Doctor ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_SCRIPT;Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_MEMORY_DOCTOR_URL -OutFile $p;$i=Get-Item -LiteralPath $p;if($i.Length -le 0 -or $i.Length -gt 4194304){throw 'Ugyldig Memory Doctor-fil.'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not $s.Contains($env:RAH_MARKER)){throw 'Manglende Memory Doctor v1-markor.'}"
if errorlevel 1 goto FAIL_DOWNLOAD

if /I "%RAH_MODE%"=="SelfTest" (
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -Mode SelfTest -Root "%TEMP%\RAH-MemoryDoctor-SelfTest"
  if errorlevel 1 goto FAIL_SELFTEST
  echo [RAH] Memory Doctor CMD bootstrap self-test PASS.
  exit /b 0
)

if /I "%RAH_MODE%"=="Audit" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -Mode Audit -Root "C:\RAH\MemoryDoctor"
) else if /I "%RAH_MODE%"=="RestoreLatest" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -Mode RestoreLatest -Root "C:\RAH\MemoryDoctor"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -Mode Interactive -Root "C:\RAH\MemoryDoctor"
)
set "RAH_EXIT=%ERRORLEVEL%"
if "%RAH_EXIT%"=="0" (
  echo.
  echo RAH MEMORY DOCTOR: PASS
  echo Rapporter: C:\RAH\MemoryDoctor\reports
) else (
  echo.
  echo RAH MEMORY DOCTOR: FAIL - kode %RAH_EXIT%
)
if /I not "%RAH_MODE%"=="Audit" pause
exit /b %RAH_EXIT%

:FAIL_UAC
echo [RAH] FAIL: UAC ble avbrutt eller kunne ikke startes.
pause
exit /b 18

:FAIL_NOT_ADMIN
echo [RAH] FAIL: prosessen er ikke Administrator etter UAC.
pause
exit /b 19

:FAIL_BOOT
echo [RAH] FAIL: kunne ikke opprette bootstrap-mappen.
pause
exit /b 20

:FAIL_DOWNLOAD
echo [RAH] FAIL: Memory Doctor kunne ikke lastes ned eller valideres.
pause
exit /b 21

:FAIL_SELFTEST
echo [RAH] FAIL: Memory Doctor self-test feilet.
exit /b 22

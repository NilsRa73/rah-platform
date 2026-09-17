@echo off
setlocal EnableExtensions
title RAH HOME - FINALIZE

set "PYTHON_BASIC_REPL=1"
if not defined RAH_URL set "RAH_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-FINALIZE.ps1"
if not defined RAH_MARKER set "RAH_MARKER=RahHomeFinalizeVersion = '1.0.0'"
if not defined RAH_GUARD_URL set "RAH_GUARD_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-WINDOWS-PYTHON-CONSOLE-GUARD.ps1"
if not defined RAH_DIAG_URL set "RAH_DIAG_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-DIAGNOSTICS.ps1"
set "RAH_GUARD_MARKER=RahPythonConsoleGuardVersion = '1.0.0'"
set "RAH_DIAG_MARKER=RahHomeDiagnosticsVersion = '1.0.0'"
set "RAH_MODE=Auto"
set "RAH_SELFTEST=0"
set "RAH_SELF_PATH=%~f0"
set "RAH_FAIL_REASON=unknown"

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
set "RAH_GUARD=%RAH_BOOT%\RAH-WINDOWS-PYTHON-CONSOLE-GUARD.ps1"
set "RAH_DIAG=%RAH_BOOT%\RAH-HOME-DIAGNOSTICS.ps1"
if not exist "%RAH_BOOT%" mkdir "%RAH_BOOT%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT

echo.
echo [RAH] Black Box diagnostics preflight ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_DIAG;Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_DIAG_URL -OutFile $p;$i=Get-Item -LiteralPath $p;if($i.Length -le 0 -or $i.Length -gt 2097152){throw 'Ugyldig diagnostics-fil.'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not $s.Contains($env:RAH_DIAG_MARKER)){throw 'Manglende Diagnostics v1-markor.'}"
if errorlevel 1 goto FAIL_DIAG_BOOTSTRAP
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_DIAG%" -SelfTest
if errorlevel 1 goto FAIL_DIAG_BOOTSTRAP

echo.
echo [RAH] Python/terminal preflight ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_GUARD;Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_GUARD_URL -OutFile $p;$i=Get-Item -LiteralPath $p;if($i.Length -le 0 -or $i.Length -gt 1048576){throw 'Ugyldig Python guard-fil.'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not $s.Contains($env:RAH_GUARD_MARKER)){throw 'Manglende Python guard v1-markor.'}"
if errorlevel 1 goto FAIL_GUARD
if "%RAH_SELFTEST%"=="1" (
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_GUARD%" -SelfTest
) else (
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_GUARD%" -InstallRoot "C:\RAH\Home" -PersistUserSetting
)
if errorlevel 1 goto FAIL_GUARD

echo.
echo [RAH] Henter og validerer RAH Home Finalize v1 ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_SCRIPT;Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_URL -OutFile $p;$i=Get-Item -LiteralPath $p;if($i.Length -le 0 -or $i.Length -gt 4194304){throw 'Ugyldig finalize-fil.'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not $s.Contains($env:RAH_MARKER)){throw 'Manglende Finalize v1-markor.'}"
if errorlevel 1 goto FAIL_DOWNLOAD

if "%RAH_SELFTEST%"=="1" (
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -SelfTest
  if errorlevel 1 goto FAIL_SELFTEST
  echo [RAH] START-HER bootstrap + Black Box + Python guard + Finalize self-test PASS.
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
  echo Python: C:\RAH\Home\RAH-PYTHON-CONSOLE-GUARD.txt
  echo =============================================================
) else (
  set "RAH_FAIL_REASON=finalize-exit-%RAH_EXIT%"
  call :COLLECT_DIAG
  echo =============================================================
  echo RAH HOME FINALIZE: FAIL - kode %RAH_EXIT%
  echo Rapport: C:\RAH\Home\RAH-HOME-FINAL-REPORT.txt
  echo Python: C:\RAH\Home\RAH-PYTHON-CONSOLE-GUARD.txt
  echo Black Box: C:\RAH\Home\support\rah-home-support-latest.json
  echo =============================================================
)
pause
exit /b %RAH_EXIT%

:COLLECT_DIAG
if "%RAH_SELFTEST%"=="1" exit /b 0
if not exist "%RAH_DIAG%" exit /b 0
echo.
echo [RAH] Samler Black Box failure bundle ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_DIAG%" -InstallRoot "C:\RAH\Home" -Reason "%RAH_FAIL_REASON%"
exit /b 0

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

:FAIL_DIAG_BOOTSTRAP
echo [RAH] FAIL: Black Box diagnostics kunne ikke lastes, valideres eller self-testes.
if not "%RAH_SELFTEST%"=="1" pause
exit /b 24

:FAIL_GUARD
set "RAH_FAIL_REASON=python-guard-failure"
call :COLLECT_DIAG
echo [RAH] FAIL: Python/terminal guard kunne ikke lastes, valideres eller self-testes.
if not "%RAH_SELFTEST%"=="1" pause
exit /b 23

:FAIL_DOWNLOAD
set "RAH_FAIL_REASON=finalize-download-validation-failure"
call :COLLECT_DIAG
echo [RAH] FAIL: finalize-script kunne ikke lastes ned eller valideres.
if not "%RAH_SELFTEST%"=="1" pause
exit /b 21

:FAIL_SELFTEST
set "RAH_FAIL_REASON=finalize-selftest-failure"
call :COLLECT_DIAG
echo [RAH] FAIL: Finalize self-test feilet.
exit /b 22

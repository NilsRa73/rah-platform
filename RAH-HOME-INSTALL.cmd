@echo off
setlocal EnableExtensions
title RAH Home Unified Installer v1

set "PYTHON_BASIC_REPL=1"
if not defined RAH_DIAG_URL set "RAH_DIAG_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-DIAGNOSTICS.ps1"
set "RAH_DIAG_MARKER=RahHomeDiagnosticsVersion = '1.0.0'"
set "RAH_SELF_PATH=%~f0"
set "RAH_FAIL_REASON=installer-failure"
if /I "%~1"=="__RAH_ADMIN__" goto VERIFY_ADMIN
set "RAH_FORWARD_ARGS=%*"
if /I "%~1"=="-SelfTest" goto RUN

fltmc >nul 2>&1
if "%ERRORLEVEL%"=="0" goto VERIFY_ADMIN

echo [RAH] Administrator kreves. Starter samme fil med UAC automatisk ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Start-Process -FilePath $env:RAH_SELF_PATH -Verb RunAs -ArgumentList '__RAH_ADMIN__'"
if errorlevel 1 goto FAIL_UAC
exit /b 0

:VERIFY_ADMIN
fltmc >nul 2>&1
if errorlevel 1 goto FAIL_NOT_ADMIN
echo [RAH] Administrator: OK

:RUN
set "RAH_BOOT=%TEMP%\RAH-HOME-INSTALL.ps1"
set "RAH_DIAG=%TEMP%\RAH-HOME-DIAGNOSTICS.ps1"
if exist "%RAH_BOOT%" del /q "%RAH_BOOT%" >nul 2>&1

if /I "%~1"=="-SelfTest" goto DOWNLOAD_MAIN
echo [RAH] Black Box diagnostics preflight ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_DIAG;Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_DIAG_URL -OutFile $p;$i=Get-Item -LiteralPath $p;if($i.Length -le 0 -or $i.Length -gt 2097152){throw 'Ugyldig diagnostics-fil.'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not $s.Contains($env:RAH_DIAG_MARKER)){throw 'Manglende Diagnostics v1-markor.'}"
if errorlevel 1 goto FAIL_DIAG
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_DIAG%" -SelfTest
if errorlevel 1 goto FAIL_DIAG

:DOWNLOAD_MAIN
echo [RAH] Henter stable Unified Installer v1...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $u='https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-INSTALL.ps1'; $p=$env:TEMP+'\RAH-HOME-INSTALL.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p; $i=Get-Item -LiteralPath $p; if($i.Length -le 0 -or $i.Length -gt 4194304){throw 'Ugyldig installer-fil.'}; $tok=$null;$err=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$tok,[ref]$err)|Out-Null;if(@($err).Count){throw $err[0].Message}; $t=[IO.File]::ReadAllText($p); if(-not $t.Contains('$script:RahHomeInstallerVersion = ''1.0.0''') -or -not $t.Contains('Invoke-RahInstallerSelfTest')){ throw 'Nedlastet installer besto ikke RAH v1-kontrakten.' }"
if errorlevel 1 goto FAIL_DOWNLOAD

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_BOOT%" %RAH_FORWARD_ARGS%
set "RAH_EXIT=%ERRORLEVEL%"
if not "%RAH_EXIT%"=="0" (
  set "RAH_FAIL_REASON=installer-exit-%RAH_EXIT%"
  call :COLLECT_DIAG
  echo.
  echo [RAH] Installasjonen stoppet med feil %RAH_EXIT%.
  echo [RAH] Black Box: C:\RAH\Home\support\rah-home-support-latest.json
  pause
)
exit /b %RAH_EXIT%

:COLLECT_DIAG
if /I "%~1"=="-SelfTest" exit /b 0
if not exist "%RAH_DIAG%" exit /b 0
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_DIAG%" -InstallRoot "C:\RAH\Home" -Reason "%RAH_FAIL_REASON%"
exit /b 0

:FAIL_UAC
echo [RAH] FAIL: UAC-elevasjon kunne ikke startes eller ble avbrutt.
pause
exit /b 18

:FAIL_NOT_ADMIN
echo [RAH] FAIL: prosessen er fortsatt ikke Administrator etter UAC.
echo [RAH] Ingen installasjon ble startet.
pause
exit /b 19

:FAIL_DIAG
echo.
echo [RAH] FEIL: Black Box diagnostics kunne ikke hentes eller valideres.
pause
exit /b 24

:FAIL_DOWNLOAD
set "RAH_FAIL_REASON=installer-download-validation-failure"
call :COLLECT_DIAG
echo.
echo [RAH] FEIL: Installer kunne ikke hentes eller valideres.
pause
exit /b 21

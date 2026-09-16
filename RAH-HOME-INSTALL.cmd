@echo off
setlocal EnableExtensions
title RAH Home Unified Installer v1

set "PYTHON_BASIC_REPL=1"
set "RAH_SELF_PATH=%~f0"
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
if exist "%RAH_BOOT%" del /q "%RAH_BOOT%" >nul 2>&1

echo [RAH] Henter stable Unified Installer v1...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $u='https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-INSTALL.ps1'; $p=$env:TEMP+'\RAH-HOME-INSTALL.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p; $i=Get-Item -LiteralPath $p; if($i.Length -le 0 -or $i.Length -gt 4194304){throw 'Ugyldig installer-fil.'}; $tok=$null;$err=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$tok,[ref]$err)|Out-Null;if(@($err).Count){throw $err[0].Message}; $t=[IO.File]::ReadAllText($p); if(-not $t.Contains('$script:RahHomeInstallerVersion = ''1.0.0''') -or -not $t.Contains('Invoke-RahInstallerSelfTest')){ throw 'Nedlastet installer besto ikke RAH v1-kontrakten.' }"
if errorlevel 1 goto FAIL_DOWNLOAD

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_BOOT%" %RAH_FORWARD_ARGS%
set "RAH_EXIT=%ERRORLEVEL%"
if not "%RAH_EXIT%"=="0" (
  echo.
  echo [RAH] Installasjonen stoppet med feil %RAH_EXIT%.
  pause
)
exit /b %RAH_EXIT%

:FAIL_UAC
echo [RAH] FAIL: UAC-elevasjon kunne ikke startes eller ble avbrutt.
pause
exit /b 18

:FAIL_NOT_ADMIN
echo [RAH] FAIL: prosessen er fortsatt ikke Administrator etter UAC.
echo [RAH] Ingen installasjon ble startet.
pause
exit /b 19

:FAIL_DOWNLOAD
echo.
echo [RAH] FEIL: Installer kunne ikke hentes eller valideres.
pause
exit /b 21

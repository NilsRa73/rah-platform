@echo off
setlocal EnableExtensions
title RAH LM STUDIO RECOVERY - AUTO

set "RAH_SELF_PATH=%~f0"
set "RAH_SCRIPT_NAME=RAH-LM-STUDIO-RECOVERY.ps1"
set "RAH_RECOVERY_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-LM-STUDIO-RECOVERY.ps1"
set "RAH_MARKER=RahLmStudioRecoveryVersion = '1.0.0'"

if /I "%~1"=="--self-test" goto SELFTEST
if /I "%~1"=="__RAH_ADMIN__" goto BOOT

fltmc >nul 2>&1
if "%ERRORLEVEL%"=="0" goto BOOT
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';Start-Process -FilePath $env:RAH_SELF_PATH -Verb RunAs -ArgumentList '__RAH_ADMIN__'"
if errorlevel 1 goto FAIL_UAC
exit /b 0

:SELFTEST
set "RAH_SCRIPT=%~dp0%RAH_SCRIPT_NAME%"
if not exist "%RAH_SCRIPT%" goto FAIL_SELFTEST
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_SCRIPT;$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not$s.Contains($env:RAH_MARKER)){throw 'Recovery version marker missing'}"
if errorlevel 1 goto FAIL_SELFTEST
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -SelfTest
if errorlevel 1 goto FAIL_SELFTEST
exit /b 0

:BOOT
set "RAH_BOOT=%TEMP%\RAH-LM-Studio-Recovery"
if not exist "%RAH_BOOT%" mkdir "%RAH_BOOT%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT
set "RAH_SCRIPT=%RAH_BOOT%\%RAH_SCRIPT_NAME%"

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_RECOVERY_URL -OutFile $env:RAH_SCRIPT -TimeoutSec 60;$i=Get-Item -LiteralPath $env:RAH_SCRIPT;if($i.Length -le 0 -or $i.Length -gt 2097152){throw 'Invalid recovery size'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($env:RAH_SCRIPT,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($env:RAH_SCRIPT);if(-not$s.Contains($env:RAH_MARKER)){throw 'Recovery version marker missing'}"
if errorlevel 1 goto FAIL_DOWNLOAD

cls
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_SCRIPT%"
set "RAH_RC=%ERRORLEVEL%"
echo.
pause
exit /b %RAH_RC%

:FAIL_UAC
cls
echo ===============================================
echo  RAH LM STUDIO: UAC FAIL
echo ===============================================
pause
exit /b 18

:FAIL_BOOT
cls
echo ===============================================
echo  RAH LM STUDIO: BOOTSTRAP FAIL
echo ===============================================
pause
exit /b 20

:FAIL_DOWNLOAD
cls
echo ===============================================
echo  RAH LM STUDIO: RECOVERY DOWNLOAD FAIL
echo ===============================================
pause
exit /b 21

:FAIL_SELFTEST
echo RAH LM STUDIO RECOVERY SELFTEST: FAIL
exit /b 22

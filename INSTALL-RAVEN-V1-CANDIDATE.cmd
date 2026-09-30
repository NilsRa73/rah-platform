@echo off
setlocal EnableExtensions
title RAH RAVEN V1 - ONE CLICK INSTALL + ACCEPT

set "RAH_INSTALL_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/raven-agent-effect-pack-v1-20260927/INSTALL-RAVEN-V1-CANDIDATE.ps1"
set "RAH_MARKER=RahRavenV1InstallerVersion='1.0.0'"
set "RAH_TMP=%TEMP%\RAH-RAVEN-V1-INSTALLER.ps1"

if /I "%~1"=="--self-test" goto SELFTEST

echo.
echo ==============================================================
echo RAH RAVEN V1 - ONE CLICK
echo Candidate install ^> backup ^> final acceptance ^> freeze
echo ==============================================================
echo.

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_INSTALL_URL -OutFile $env:RAH_TMP -TimeoutSec 60;$s=[IO.File]::ReadAllText($env:RAH_TMP);if(-not$s.Contains($env:RAH_MARKER)){throw 'Installer marker missing'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($env:RAH_TMP,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message}"
if errorlevel 1 goto FAIL

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RAH_TMP%" -TargetRoot "C:\RAH"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo ==============================================================
  echo RAH RAVEN V1: FULL PASS + FROZEN CANDIDATE
  echo ==============================================================
) else (
  echo ==============================================================
  echo RAH RAVEN V1: FAIL - se C:\RAH\Logs\RAVEN-V1-ACCEPTANCE-LATEST.txt
  echo ==============================================================
)
pause
exit /b %RC%

:SELFTEST
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_INSTALL_URL -OutFile $env:RAH_TMP -TimeoutSec 60;$s=[IO.File]::ReadAllText($env:RAH_TMP);if(-not$s.Contains($env:RAH_MARKER)){throw 'Installer marker missing'}"
if errorlevel 1 exit /b 41
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_TMP%" -SelfTest
exit /b %ERRORLEVEL%

:FAIL
echo [FAIL] Candidate-installer kunne ikke hentes eller valideres.
pause
exit /b 40

@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH RAVEN V1 - PINNED HOVED-PC CANDIDATE

set "RAH_PAYLOAD_SHA=15797a8a9bb7af76c47ce672da7e7a2f496ad7a2"
set "RAH_BASE=https://raw.githubusercontent.com/NilsRa73/rah-platform/%RAH_PAYLOAD_SHA%"
set "RAH_PS_URL=%RAH_BASE%/INSTALL-RAVEN-V1-CANDIDATE.ps1"
set "RAH_TMP=%TEMP%\RAH-RAVEN-V1-PINNED-INSTALLER.ps1"
set "RAH_LOCAL=%~dp0INSTALL-RAVEN-V1-CANDIDATE.ps1"
set "RAH_MARKER=RahRavenV1InstallerVersion='1.0.0'"

if /I "%~1"=="--self-test" goto SELFTEST

echo.
echo ==============================================================
echo  RAH RAVEN V1 - HOVED-PC PINNED CANDIDATE
echo  Payload: %RAH_PAYLOAD_SHA%
echo  Install ^> backup ^> acceptance ^> freeze
echo ==============================================================
echo.

set "RAH_SOURCE="
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "try{Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_PS_URL -OutFile $env:RAH_TMP -TimeoutSec 45;" ^
  "$s=[IO.File]::ReadAllText($env:RAH_TMP);if(-not $s.Contains($env:RAH_MARKER)){throw 'marker'};exit 0}catch{exit 9}"
if "%ERRORLEVEL%"=="0" (
  set "RAH_SOURCE=%RAH_TMP%"
) else (
  echo [WARN] GitHub kunne ikke naas. Proever lokal pinned installer...
  if exist "%RAH_LOCAL%" (
    powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ^
      "$s=[IO.File]::ReadAllText($env:RAH_LOCAL);if(-not $s.Contains($env:RAH_MARKER)){exit 8};exit 0"
    if "%ERRORLEVEL%"=="0" set "RAH_SOURCE=%RAH_LOCAL%"
  )
)

if not defined RAH_SOURCE goto FAIL_FETCH

echo [RAH] Bruker installer: %RAH_SOURCE%
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RAH_SOURCE%" ^
  -TargetRoot "C:\RAH" ^
  -SourceBase "%RAH_BASE%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo ==============================================================
  echo  RAH RAVEN V1: FULL PASS + FROZEN CANDIDATE
  echo ==============================================================
) else (
  echo ==============================================================
  echo  RAH RAVEN V1: FAIL
  echo  Rapport: C:\RAH\Logs\RAVEN-V1-ACCEPTANCE-LATEST.txt
  echo ==============================================================
)
pause
exit /b %RC%

:SELFTEST
echo [RAH] PINNED SELFTEST %RAH_PAYLOAD_SHA%
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "if($env:RAH_PAYLOAD_SHA -notmatch '^[0-9a-f]{40}$'){throw 'bad sha'};" ^
  "Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_PS_URL -OutFile $env:RAH_TMP -TimeoutSec 45;" ^
  "$s=[IO.File]::ReadAllText($env:RAH_TMP);if(-not $s.Contains($env:RAH_MARKER)){throw 'marker missing'};" ^
  "$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($env:RAH_TMP,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message}"
if errorlevel 1 exit /b 41
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_TMP%" -SelfTest
exit /b %ERRORLEVEL%

:FAIL_FETCH
echo.
echo [FAIL] Klarte ikke hente pinned installer fra GitHub, og fant ingen lokal installer ved siden av denne filen.
echo [FIX] Koble til nett/VPN eller legg INSTALL-RAVEN-V1-CANDIDATE.ps1 i samme mappe og kjoer igjen.
pause
exit /b 40

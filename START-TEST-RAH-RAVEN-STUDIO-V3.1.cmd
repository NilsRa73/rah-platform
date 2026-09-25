@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio v3.1 Candidate.2 - Windows Acceptance

set "FINAL=%~dp0RAH-RAVEN-STUDIO-FINAL.ps1"
set "HTML=%~dp0RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
set "MANIFEST=%~dp0RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json"
set "APP_LAUNCHER=%~dp0desktop-bridge\app_launcher.py"

echo.
echo ====================================================================
echo  RAH RAVEN STUDIO v3.1 CANDIDATE.2
echo  STABLE INFRA CHECK ^> CANDIDATE CONTRACT ^> OPEN TEST UI
echo ====================================================================
echo.

if not exist "%FINAL%" goto :missing
if not exist "%HTML%" goto :missing
if not exist "%MANIFEST%" goto :missing
if not exist "%APP_LAUNCHER%" goto :missing

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$m=Get-Content -LiteralPath '%MANIFEST%' -Raw | ConvertFrom-Json;" ^
  "if([string]$m.version -ne '3.1.0-candidate.2'){throw 'Candidate version mismatch.'};" ^
  "if([string]$m.app_launcher.version -ne '0.2.0'){throw 'App launcher version mismatch.'};" ^
  "if($m.features.arbitrary_shell -ne $false -or $m.features.arbitrary_paths -ne $false -or $m.features.arbitrary_arguments -ne $false){throw 'Candidate safety contract mismatch.'};" ^
  "Write-Host '[PASS] Candidate manifest contract' -ForegroundColor Green"
if errorlevel 1 goto :fail

echo [1/2] Validating canonical Studio 3.0 infrastructure without opening Stable UI...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FINAL%" -NoLaunch
if errorlevel 1 goto :fail

echo [2/2] Opening Raven Studio v3.1 Candidate.2...
start "" "%HTML%"
if errorlevel 1 goto :fail

echo.
echo ====================================================================
echo  PASS - CANDIDATE.2 OPENED
echo  Test App Hub: World Media / Browser / RAH OS / RAH Home
echo  Stable Studio 3.0 remains unchanged.
echo ====================================================================
echo.
pause
exit /b 0

:missing
echo [FAIL] Candidate package is incomplete.
echo Required:
echo   RAH-RAVEN-STUDIO-FINAL.ps1
echo   RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html
echo   RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json
echo   desktop-bridge\app_launcher.py
pause
exit /b 2

:fail
echo.
echo ====================================================================
echo  FAIL - Raven Studio v3.1 Candidate.2 acceptance launcher
echo ====================================================================
echo.
pause
exit /b 1

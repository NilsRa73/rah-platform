@echo off
setlocal EnableExtensions
title RAH Raven OS v0.7 Gold Shell - Safe Preview

set "PREVIEW=%TEMP%\RAH-OS-v0.7-GOLD"
set "TARGET=%PREVIEW%\RAH-OS-CONTROL-v0.7-GOLD.ps1"
set "URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/f770fa3c7a5c23b74aa6096ef2fa7e1bd791671a/RAH-OS-CONTROL-v0.7-GOLD.ps1"

if not exist "%PREVIEW%" mkdir "%PREVIEW%" >nul 2>&1

echo.
echo ============================================================
echo         RAH RAVEN OS v0.7 - GOLD SHELL PREVIEW
echo ============================================================
echo.
echo This preview does NOT replace your stable v0.6 files.
echo It downloads one pinned Gold Shell file to:
echo   %TARGET%
echo.
echo Existing local RAH launchers under C:\RAH are used when you
echo press buttons inside the shell.
echo.

where curl.exe >nul 2>&1
if errorlevel 1 goto :fallback

curl.exe -L --fail --silent --show-error "%URL%" -o "%TARGET%"
if errorlevel 1 goto :downloadfail
goto :launch

:fallback
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%TARGET%'"
if errorlevel 1 goto :downloadfail

:launch
if not exist "%TARGET%" goto :downloadfail
for %%I in ("%TARGET%") do if %%~zI LSS 10000 goto :downloadfail

echo PASS: Gold Shell preview downloaded.
echo Launching...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%TARGET%"
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo Gold Shell exited with code %EC%.
  pause
)
exit /b %EC%

:downloadfail
echo.
echo FAIL: Could not download the pinned Gold Shell preview.
echo Your stable C:\RAH\RavenOS installation was not changed.
pause
exit /b 1

@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH AnythingLLM

set "ROOT=C:\RAH\AnythingLLM"
set "LOGS=C:\RAH\Logs\AnythingLLM"
set "STATE=C:\RAH\State\AnythingLLM"
set "URL=https://anythingllm.com/download"
set "WINGET_ID=MintplexLabs.AnythingLLM"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if /I "%~1"=="help" goto :help
if /I "%~1"=="status" goto :status
if /I "%~1"=="install" goto :install
if /I "%~1"=="open" goto :open
if not "%~1"=="" goto :help

:menu
cls
echo.
echo ================================================================
echo                 RAH ANYTHINGLLM CONTROL
echo ================================================================
echo.
echo   1  STATUS
echo   2  INSTALL / UPDATE with WinGet
echo   3  OPEN AnythingLLM
echo   4  OPEN official download page
echo   0  EXIT
echo.
choice /C 12340 /N /M "Choose: "
if errorlevel 5 goto :exit
if errorlevel 4 start "" "%URL%" & goto :menu
if errorlevel 3 call :open & pause & goto :menu
if errorlevel 2 call :install & pause & goto :menu
if errorlevel 1 call :status & pause & goto :menu
goto :menu

:status
where winget.exe >nul 2>nul
if errorlevel 1 (
  echo WinGet      : NOT FOUND
) else (
  echo WinGet      : READY
)

set "FOUND="
for %%P in (
  "%LOCALAPPDATA%\Programs\AnythingLLM\AnythingLLM.exe"
  "%LOCALAPPDATA%\Programs\AnythingLLMDesktop\AnythingLLM.exe"
  "%ProgramFiles%\AnythingLLM\AnythingLLM.exe"
) do if exist "%%~P" set "FOUND=%%~P"

if defined FOUND (
  echo AnythingLLM : INSTALLED
  echo Path        : %FOUND%
) else (
  echo AnythingLLM : NOT DETECTED
)

if exist "%STATE%\API-TOKEN.txt" (
  echo Raven API   : TOKEN FILE PRESENT
) else (
  echo Raven API   : NOT CONNECTED
  echo.
  echo To connect Raven later:
  echo   AnythingLLM ^> Settings ^> Developer API ^> Generate New API Key
  echo   Store it in: %STATE%\API-TOKEN.txt
)
exit /b 0

:install
where winget.exe >nul 2>nul
if errorlevel 1 (
  echo [WARN] WinGet is not available. Opening official download page.
  start "" "%URL%"
  exit /b 2
)

if not exist "%STATE%" mkdir "%STATE%" >nul 2>nul
if not exist "%LOGS%" mkdir "%LOGS%" >nul 2>nul

echo Installing/updating AnythingLLM via WinGet...
winget install --id "%WINGET_ID%" -e --source winget --accept-package-agreements --accept-source-agreements
set "RC=%ERRORLEVEL%"
if "%RC%"=="0" (
  echo [OK] AnythingLLM install/update completed.
) else (
  echo [WARN] WinGet returned %RC%.
  echo Opening official download page instead.
  start "" "%URL%"
)
exit /b %RC%

:open
set "FOUND="
for %%P in (
  "%LOCALAPPDATA%\Programs\AnythingLLM\AnythingLLM.exe"
  "%LOCALAPPDATA%\Programs\AnythingLLMDesktop\AnythingLLM.exe"
  "%ProgramFiles%\AnythingLLM\AnythingLLM.exe"
) do if exist "%%~P" set "FOUND=%%~P"
if defined FOUND (
  start "" "%FOUND%"
  echo [OK] AnythingLLM started.
  exit /b 0
)
echo [WARN] AnythingLLM executable was not detected.
start "" "%URL%"
exit /b 2

:help
echo RAH AnythingLLM Control
echo.
echo Usage:
echo   RAH-ANYTHINGLLM.cmd status
echo   RAH-ANYTHINGLLM.cmd install
echo   RAH-ANYTHINGLLM.cmd open
exit /b 0

:exit
endlocal
exit /b 0

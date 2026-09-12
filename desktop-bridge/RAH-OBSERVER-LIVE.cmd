@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0B
title RAH Observer - Live Wall

set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "SERVER=%BRIDGE%\observer_live_server.py"
set "UI=%RUNTIME%\RAH-OBSERVER-LIVE-WALL.html"
set "URL=http://127.0.0.1:18767/live"
set "HEALTH=http://127.0.0.1:18767/health"
set "PYEXE="
set "PYARGS="

if exist "%RUNTIME%\.venv\Scripts\python.exe" set "PYEXE=%RUNTIME%\.venv\Scripts\python.exe"
if not defined PYEXE if exist "%BRIDGE%\.venv\Scripts\python.exe" set "PYEXE=%BRIDGE%\.venv\Scripts\python.exe"
if not defined PYEXE for /f "delims=" %%P in ('where py.exe 2^>nul') do if not defined PYEXE (set "PYEXE=%%P"&set "PYARGS=-3")
if not defined PYEXE for /f "delims=" %%P in ('where python.exe 2^>nul') do if not defined PYEXE set "PYEXE=%%P"

if /I "%~1"=="help" goto :help
if /I "%~1"=="status" goto :status
if /I "%~1"=="selftest" goto :selftest
if /I "%~1"=="start" goto :start
if not "%~1"=="" goto :help
goto :start

:require
if not exist "%SERVER%" (echo [ERROR] Live Wall server missing: %SERVER%&exit /b 2)
if not exist "%UI%" (echo [ERROR] Live Wall UI missing: %UI%&exit /b 3)
if not defined PYEXE (echo [ERROR] Python 3 was not found.&exit /b 4)
exit /b 0

:status
curl.exe -fsS --connect-timeout 2 "%HEALTH%" 2>nul
if errorlevel 1 (echo.&echo Live Wall: OFFLINE&exit /b 1)
echo.
echo Live Wall: ONLINE / READ-ONLY
exit /b 0

:selftest
call :require || exit /b %ERRORLEVEL%
pushd "%BRIDGE%"
"%PYEXE%" %PYARGS% -m py_compile observer_surface_apps.py observer_preview.py observer_live_server.py
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" (echo [FAIL] Live Wall Python compile test failed.&exit /b %RC%)
findstr /C:"RAH OBSERVER · LIVE WALL" "%UI%" >nul || (echo [FAIL] Live Wall marker missing.&exit /b 8)
findstr /C:"Read-only previews" "%UI%" >nul || (echo [FAIL] Read-only marker missing.&exit /b 9)
echo [PASS] Live Wall compile/UI self-test.
exit /b 0

:start
call :require || goto :fail
call :selftest || goto :fail
curl.exe -fsS --connect-timeout 2 "%HEALTH%" >nul 2>nul
if not errorlevel 1 goto :open
echo Starting RAH Observer Live Wall...
pushd "%BRIDGE%"
start "RAH Observer Live Wall" /min "%PYEXE%" %PYARGS% "%SERVER%"
popd
for /l %%N in (1,1,12) do (
  timeout /t 1 /nobreak >nul
  curl.exe -fsS --connect-timeout 2 "%HEALTH%" >nul 2>nul
  if not errorlevel 1 goto :open
)
echo [ERROR] Live Wall did not become ready on 127.0.0.1:18767.
pause
exit /b 10

:open
echo Live Wall: ONLINE / READ-ONLY
start "" "%URL%"
exit /b 0

:fail
echo.
echo Live Wall could not start.
pause
exit /b 20

:help
echo RAH Observer Live Wall v1.0
echo.
echo   RAH-OBSERVER-LIVE.cmd          Start read-only Live Wall
echo   RAH-OBSERVER-LIVE.cmd status   Check local Live Wall server
echo   RAH-OBSERVER-LIVE.cmd selftest Compile/UI test
echo.
echo Local UI: %URL%
echo Stable Observer remains on 127.0.0.1:18766
exit /b 0

@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0B
title RAH Observer - The Wall

set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "SERVER=%BRIDGE%\observer_wall_server.py"
set "URL=http://127.0.0.1:18766/observer/ui"
set "HEALTH=http://127.0.0.1:18766/health"
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
if not exist "%SERVER%" (
  echo [ERROR] Observer server missing: %SERVER%
  exit /b 2
)
if not exist "%RUNTIME%\RAH-OBSERVER-WALL.html" (
  echo [ERROR] The Wall UI missing: %RUNTIME%\RAH-OBSERVER-WALL.html
  exit /b 3
)
if not defined PYEXE (
  echo [ERROR] Python 3 was not found. Raven runtime is incomplete.
  exit /b 4
)
exit /b 0

:status
curl.exe -fsS --connect-timeout 2 "%HEALTH%" 2>nul
if errorlevel 1 (
  echo.
  echo Observer Wall: OFFLINE
  exit /b 1
)
echo.
echo Observer Wall: ONLINE
exit /b 0

:selftest
call :require || exit /b %ERRORLEVEL%
pushd "%BRIDGE%"
"%PYEXE%" %PYARGS% -m py_compile observer_wall.py observer_wall_server.py
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" (
  echo [FAIL] Observer Python compile test failed.
  exit /b %RC%
)
echo [PASS] Observer Wall Python compile test.
exit /b 0

:start
call :require || goto :fail
call :selftest || goto :fail
curl.exe -fsS --connect-timeout 2 "%HEALTH%" >nul 2>nul
if not errorlevel 1 goto :open

echo Starting RAH Observer Wall...
pushd "%BRIDGE%"
start "RAH Observer Wall" /min "%PYEXE%" %PYARGS% "%SERVER%"
popd

for /l %%N in (1,1,12) do (
  timeout /t 1 /nobreak >nul
  curl.exe -fsS --connect-timeout 2 "%HEALTH%" >nul 2>nul
  if not errorlevel 1 goto :open
)

echo [ERROR] Observer Wall did not become ready on 127.0.0.1:18766.
pause
exit /b 10

:open
echo Observer Wall: ONLINE
start "" "%URL%"
exit /b 0

:fail
echo.
echo Observer Wall could not start.
pause
exit /b 20

:help
echo RAH Observer Wall v1.0
echo.
echo   RAH-OBSERVER-WALL.cmd          Start The Wall
echo   RAH-OBSERVER-WALL.cmd status   Check local Observer server
echo   RAH-OBSERVER-WALL.cmd selftest Compile-test Observer module
echo.
echo Local UI: %URL%
exit /b 0

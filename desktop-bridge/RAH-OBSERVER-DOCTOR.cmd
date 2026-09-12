@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0B
title RAH Observer Doctor v1.0

set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "DOCTOR=%BRIDGE%\observer_doctor.py"
set "CONTROL_SERVER=%BRIDGE%\observer_wall_server.py"
set "LIVE_SERVER=%BRIDGE%\observer_live_server.py"
set "ROOT=C:\RAH\AgentWork"
set "REPORT=%ROOT%\OBSERVER-LATEST.txt"
set "CONTROL_HEALTH=http://127.0.0.1:18766/health"
set "LIVE_HEALTH=http://127.0.0.1:18767/health"
set "PYEXE="
set "PYARGS="

if exist "%BRIDGE%\.venv\Scripts\python.exe" set "PYEXE=%BRIDGE%\.venv\Scripts\python.exe"
if not defined PYEXE if exist "%RUNTIME%\.venv\Scripts\python.exe" set "PYEXE=%RUNTIME%\.venv\Scripts\python.exe"
if not defined PYEXE for /f "delims=" %%P in ('where py.exe 2^>nul') do if not defined PYEXE (set "PYEXE=%%P"&set "PYARGS=-3")
if not defined PYEXE for /f "delims=" %%P in ('where python.exe 2^>nul') do if not defined PYEXE set "PYEXE=%%P"

if /I "%~1"=="help" goto :help
if /I "%~1"=="once" goto :once
if /I "%~1"=="status" goto :status
if /I "%~1"=="report" goto :report
if /I "%~1"=="copy" goto :copy
if /I "%~1"=="selftest" goto :selftest
if not "%~1"=="" goto :help
goto :once

:require
if not defined PYEXE (
  echo [ERROR] Python 3 not found.
  exit /b 2
)
if not exist "%DOCTOR%" (
  echo [ERROR] Observer Doctor missing: %DOCTOR%
  exit /b 3
)
exit /b 0

:health_control
curl.exe -fsS --connect-timeout 2 "%CONTROL_HEALTH%" >nul 2>nul
exit /b %ERRORLEVEL%

:health_live
curl.exe -fsS --connect-timeout 2 "%LIVE_HEALTH%" >nul 2>nul
exit /b %ERRORLEVEL%

:safe_recover
call :health_control
if errorlevel 1 if exist "%CONTROL_SERVER%" (
  echo [SAFE] Starting Observer Control Wall server...
  pushd "%BRIDGE%"
  start "RAH Observer Control Wall" /min "%PYEXE%" %PYARGS% "%CONTROL_SERVER%"
  popd
)
call :health_live
if errorlevel 1 if exist "%LIVE_SERVER%" (
  echo [SAFE] Starting Observer Live Wall server...
  pushd "%BRIDGE%"
  start "RAH Observer Live Wall" /min "%PYEXE%" %PYARGS% "%LIVE_SERVER%"
  popd
)
for /l %%N in (1,1,5) do (
  call :health_control
  if not errorlevel 1 call :health_live
  if not errorlevel 1 exit /b 0
  timeout /t 1 /nobreak >nul
)
exit /b 0

:once
call :require || exit /b %ERRORLEVEL%
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>nul
echo.
echo ========================================================================
echo                      RAH OBSERVER DOCTOR v1.0
echo ========================================================================
echo.
call :safe_recover
pushd "%BRIDGE%"
"%PYEXE%" %PYARGS% "%DOCTOR%"
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%

:status
if exist "%REPORT%" (
  findstr /C:"Overall: FAIL" "%REPORT%" >nul 2>nul && (echo OBSERVER : FAIL& exit /b 5)
  findstr /C:"Overall: PASS WITH WARNING" "%REPORT%" >nul 2>nul && (echo OBSERVER : PASS WITH WARNING& exit /b 6)
  findstr /C:"Overall: PASS" "%REPORT%" >nul 2>nul && (echo OBSERVER : PASS& exit /b 0)
)
echo OBSERVER : NO REPORT
exit /b 2

:report
if exist "%REPORT%" (type "%REPORT%"& exit /b 0)
echo No Observer Doctor report exists yet.
exit /b 2

:copy
if not exist "%REPORT%" call :once >nul
if not exist "%REPORT%" exit /b 2
type "%REPORT%" | clip.exe
echo [OK] Observer Doctor report copied to clipboard.
exit /b 0

:selftest
call :require || exit /b %ERRORLEVEL%
pushd "%BRIDGE%"
"%PYEXE%" %PYARGS% -m py_compile observer_doctor.py
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" exit /b %RC%
findstr /C:"RAH Observer Doctor v1.0" "%~f0" >nul || exit /b 8
findstr /C:"OBSERVER-LATEST.txt" "%DOCTOR%" >nul || exit /b 9
findstr /C:"Missing optional integrations are PLAN, not FAIL" "%DOCTOR%" >nul || exit /b 10
echo [PASS] Observer Doctor compile/contract self-test.
exit /b 0

:help
echo RAH Observer Doctor v1.0
echo.
echo   once      SAFE-start Observer servers if needed, then diagnose
echo   status    Show last Observer aggregate status
echo   report    Show C:\RAH\AgentWork\OBSERVER-LATEST.txt
echo   copy      Copy latest Observer report
echo   selftest  Compile/contract test
echo.
echo Policy: diagnose read-only; only SAFE server start is automatic.
exit /b 0

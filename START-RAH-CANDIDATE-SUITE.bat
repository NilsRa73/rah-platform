@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Candidate Acceptance Suite

set "INSTALLER=%~dp0INSTALL-RAH-RAVEN.bat"
set "CENTER=%~dp0RAH-CANDIDATE-ACCEPTANCE-CENTER.bat"
set "CENTER_PS1=%~dp0RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1"
set "DAILY_PY=%~dp0apps\rah-raven-daily-driver\.venv\Scripts\python.exe"

if not exist "%CENTER%" (
  echo ERROR: Candidate Acceptance Center is missing:
  echo %CENTER%
  exit /b 1
)
if not exist "%CENTER_PS1%" (
  echo ERROR: Candidate Acceptance Center script is missing:
  echo %CENTER_PS1%
  exit /b 1
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: Windows PowerShell was not found.
  exit /b 1
)

if /I "%~1"=="--self-test" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CENTER_PS1%" -SelfTest
  exit /b %ERRORLEVEL%
)

:menu
cls
echo ================================================================
echo RAH CANDIDATE ACCEPTANCE SUITE
echo ================================================================
echo Stable promotion remains BLOCKED.
echo Target-specific setup runs only after you choose a Candidate.
echo.
echo  1^) RAH Raven Studio 2.9 Candidate
echo  2^) RAH Raven Daily Driver 1.0 Candidate
echo  3^) RAH AI Investigator 1.0 RC2 Candidate
echo  Q^) Quit
echo.
set "CHOICE="
set /p "CHOICE=Choose acceptance kit: "
if /I "%CHOICE%"=="1" goto run_studio
if /I "%CHOICE%"=="2" goto run_daily
if /I "%CHOICE%"=="3" goto run_investigator
if /I "%CHOICE%"=="Q" exit /b 0
goto menu

:run_studio
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CENTER_PS1%" -Target studio
set "LAST_RC=%ERRORLEVEL%"
goto after_run

:run_daily
call :ensure_daily_driver
if errorlevel 1 (
  set "LAST_RC=1"
  goto after_run
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CENTER_PS1%" -Target daily-driver
set "LAST_RC=%ERRORLEVEL%"
goto after_run

:run_investigator
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CENTER_PS1%" -Target investigator
set "LAST_RC=%ERRORLEVEL%"
goto after_run

:after_run
echo.
echo Candidate acceptance exited with code %LAST_RC%.
echo Stable promotion remains BLOCKED.
echo.
pause
goto menu

:ensure_daily_driver
if exist "%DAILY_PY%" (
  powershell.exe -NoProfile -Command "$d=[Environment]::GetFolderPath('Desktop'); if(Test-Path -LiteralPath (Join-Path $d 'RAH Raven Daily Driver.lnk') -PathType Leaf){exit 0}else{exit 2}" >nul 2>nul
  if not errorlevel 2 exit /b 0
)

if not exist "%INSTALLER%" (
  echo ERROR: Fixed Daily Driver installer is missing:
  echo %INSTALLER%
  exit /b 1
)

echo.
echo ================================================================
echo RAH DAILY DRIVER - TARGET-SPECIFIC SETUP
echo ================================================================
echo Daily Driver install/shortcut is missing.
echo Setup runs only because Daily Driver was selected.
echo No Stable promotion is performed.
echo.
set "RAH_RAVEN_INSTALL_NO_START=1"
call "%INSTALLER%"
if errorlevel 1 goto daily_install_failed
set "RAH_RAVEN_INSTALL_NO_START="

if not exist "%DAILY_PY%" (
  echo ERROR: Daily Driver setup did not create the expected local Python runtime.
  exit /b 1
)
powershell.exe -NoProfile -Command "$d=[Environment]::GetFolderPath('Desktop'); if(Test-Path -LiteralPath (Join-Path $d 'RAH Raven Daily Driver.lnk') -PathType Leaf){exit 0}else{exit 2}" >nul 2>nul
if errorlevel 2 (
  echo ERROR: Daily Driver setup did not create the expected desktop shortcut.
  exit /b 1
)
exit /b 0

:daily_install_failed
set "RAH_RAVEN_INSTALL_NO_START="
echo ERROR: Daily Driver installation failed.
exit /b 1

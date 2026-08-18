@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Candidate Acceptance Suite

set "INSTALLER=%~dp0INSTALL-RAH-RAVEN.bat"
set "CENTER=%~dp0RAH-CANDIDATE-ACCEPTANCE-CENTER.bat"
set "DAILY_PY=%~dp0apps\rah-raven-daily-driver\.venv\Scripts\python.exe"

if not exist "%INSTALLER%" (
  echo ERROR: Fixed Daily Driver installer is missing:
  echo %INSTALLER%
  exit /b 1
)
if not exist "%CENTER%" (
  echo ERROR: Candidate Acceptance Center is missing:
  echo %CENTER%
  exit /b 1
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: Windows PowerShell was not found.
  exit /b 1
)

set "NEEDS_INSTALL=0"
if not exist "%DAILY_PY%" set "NEEDS_INSTALL=1"
powershell.exe -NoProfile -Command "$d=[Environment]::GetFolderPath('Desktop'); if(Test-Path -LiteralPath (Join-Path $d 'RAH Raven Daily Driver.lnk') -PathType Leaf){exit 0}else{exit 2}" >nul 2>nul
if errorlevel 2 set "NEEDS_INSTALL=1"

if "%NEEDS_INSTALL%"=="1" (
  echo ================================================================
  echo RAH CANDIDATE ACCEPTANCE SUITE - DAILY DRIVER SETUP
  echo ================================================================
  echo Daily Driver install/shortcut is missing. Running the fixed installer.
  echo No Stable promotion is performed.
  echo.
  set "RAH_RAVEN_INSTALL_NO_START=1"
  call "%INSTALLER%"
  set "RC=%ERRORLEVEL%"
  set "RAH_RAVEN_INSTALL_NO_START="
  if not "%RC%"=="0" (
    echo ERROR: Daily Driver installation failed with exit code %RC%.
    exit /b %RC%
  )
)

echo.
echo ================================================================
echo RAH CANDIDATE ACCEPTANCE SUITE
echo ================================================================
echo Opening the fixed fail-closed Candidate Acceptance Center.
echo Stable promotion remains BLOCKED.
echo.
call "%CENTER%"
exit /b %ERRORLEVEL%

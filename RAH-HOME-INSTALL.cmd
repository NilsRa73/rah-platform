@echo off
setlocal EnableExtensions
title RAH Home Unified Installer v1

set "RAH_BOOT=%TEMP%\RAH-HOME-INSTALL.ps1"
if exist "%RAH_BOOT%" del /q "%RAH_BOOT%" >nul 2>&1

echo [RAH] Henter stable Unified Installer v1...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $u='https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-INSTALL.ps1'; $p=$env:TEMP+'\RAH-HOME-INSTALL.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p; $t=[IO.File]::ReadAllText($p); if(-not $t.Contains('$script:RahHomeInstallerVersion = ''1.0.0''') -or -not $t.Contains('Invoke-RahInstallerSelfTest')){ throw 'Nedlastet installer besto ikke RAH v1-kontrakten.' }"
if errorlevel 1 (
  echo.
  echo [RAH] FEIL: Installer kunne ikke hentes eller valideres.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_BOOT%" %*
set "RAH_EXIT=%ERRORLEVEL%"
if not "%RAH_EXIT%"=="0" (
  echo.
  echo [RAH] Installasjonen stoppet med feil %RAH_EXIT%.
  pause
)
exit /b %RAH_EXIT%

@echo off
setlocal EnableExtensions DisableDelayedExpansion
if /I "%~1"=="--audit" goto audit
start "" "%~dp0RAVEN-FLASH-PREVIEW.html"
start "" notepad.exe "%~dp0LES-MEG.txt"
:audit
fltmc >nul 2>&1
if errorlevel 1 (
  set "RAH_FLASH_START=%~f0"
  powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -Command "try { Start-Process -FilePath $env:RAH_FLASH_START -ArgumentList '--audit' -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
  if errorlevel 1 (
    echo Oppstartskartleggingen trenger administrator for aa lese BCD.
    echo Ingen oppstartsinnstillinger er endret.
    pause
  )
  exit /b
)
set "RAH_FLASH_REPORT_DIR=%LOCALAPPDATA%\RAH\BOOT-AUDIT\%COMPUTERNAME%-%RANDOM%-%RANDOM%"
mkdir "%RAH_FLASH_REPORT_DIR%" >nul 2>&1
if not exist "%RAH_FLASH_REPORT_DIR%\" (
  echo Kunne ikke opprette rapportmappe.
  pause
  exit /b 1
)
set "RAH_FLASH_REPORT=%RAH_FLASH_REPORT_DIR%\RAH-BOOT-REPORT.txt"
>"%RAH_FLASH_REPORT%" echo RAH RAVEN FLASH R1.3 - READ ONLY BOOT AUDIT
>>"%RAH_FLASH_REPORT%" echo Computer: %COMPUTERNAME%
>>"%RAH_FLASH_REPORT%" echo Date: %DATE% %TIME%
>>"%RAH_FLASH_REPORT%" echo Status: NO BOOT CHANGES REQUESTED OR APPLIED
>>"%RAH_FLASH_REPORT%" echo.
>>"%RAH_FLASH_REPORT%" echo === WINDOWS AND MEMORY ===
systeminfo >>"%RAH_FLASH_REPORT%" 2>&1
>>"%RAH_FLASH_REPORT%" echo.
>>"%RAH_FLASH_REPORT%" echo === BOOT CONFIGURATION ===
bcdedit /enum all /v >>"%RAH_FLASH_REPORT%" 2>&1
>>"%RAH_FLASH_REPORT%" echo.
>>"%RAH_FLASH_REPORT%" echo === FIRMWARE ENTRIES ===
bcdedit /enum firmware /v >>"%RAH_FLASH_REPORT%" 2>&1
>>"%RAH_FLASH_REPORT%" echo.
>>"%RAH_FLASH_REPORT%" echo === DISKS AND VOLUMES ===
>"%RAH_FLASH_REPORT_DIR%\disk-list.txt" echo list disk
>>"%RAH_FLASH_REPORT_DIR%\disk-list.txt" echo list volume
>>"%RAH_FLASH_REPORT_DIR%\disk-list.txt" echo exit
diskpart /s "%RAH_FLASH_REPORT_DIR%\disk-list.txt" >>"%RAH_FLASH_REPORT%" 2>&1
>>"%RAH_FLASH_REPORT%" echo.
>>"%RAH_FLASH_REPORT%" echo === EXISTING MOUNT POINTS ===
mountvol >>"%RAH_FLASH_REPORT%" 2>&1
>>"%RAH_FLASH_REPORT%" echo.
>>"%RAH_FLASH_REPORT%" echo === WINDOWS RECOVERY ===
reagentc /info >>"%RAH_FLASH_REPORT%" 2>&1
>>"%RAH_FLASH_REPORT%" echo.
>>"%RAH_FLASH_REPORT%" echo === AVAILABLE POWER STATES ===
powercfg /a >>"%RAH_FLASH_REPORT%" 2>&1
>>"%RAH_FLASH_REPORT%" echo.
>>"%RAH_FLASH_REPORT%" echo Commands may report unavailable features; inspect each section.
>>"%RAH_FLASH_REPORT%" echo This report does not verify ISO contents or physical boot speed.
start "" notepad.exe "%RAH_FLASH_REPORT%"
start "" explorer.exe /select,"%RAH_FLASH_REPORT%"
exit /b 0

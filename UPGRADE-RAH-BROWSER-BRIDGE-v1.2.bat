@echo off
setlocal EnableExtensions
chcp 65001 >nul
color 0E
title RAH BROWSER BRIDGE v1.2 - REPO INSTALLER

set "ROOT=%LOCALAPPDATA%\RAH\LocalAgent"
set "TOKENFILE=%ROOT%\token.txt"
set "EXT=%LOCALAPPDATA%\RAH\BrowserBridgeV1"
set "RAW=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/browser-bridge-v1"

echo ============================================================
echo  RAH BROWSER BRIDGE v1.2 - REPO INSTALLER
echo ============================================================
echo.

if not exist "%TOKENFILE%" (
  color 0C
  echo ERROR: RAH Local Agent token not found:
  echo %TOKENFILE%
  pause
  exit /b 1
)

echo [1/5] Checking RAH Local Agent...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "try{$h=Invoke-RestMethod 'http://127.0.0.1:18779/health' -TimeoutSec 4;if(-not $h.ok){exit 2};Write-Host ('RAH Local Agent ONLINE v'+$h.version) -ForegroundColor Green}catch{Write-Host $_.Exception.Message -ForegroundColor Red;exit 2}"
if errorlevel 1 (
  color 0C
  echo RAH Local Agent is not online on 127.0.0.1:18779.
  pause
  exit /b 2
)

echo [2/5] Creating extension folder...
if not exist "%EXT%" mkdir "%EXT%"

echo [3/5] Downloading canonical Browser Bridge v1.2 from rah-platform...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';$base='%RAW%';$dst='%EXT%';$files=@('manifest.json','config.js','background.js','content.js','popup.html','popup.js','README.txt');foreach($f in $files){Invoke-WebRequest -UseBasicParsing ($base+'/'+$f) -OutFile (Join-Path $dst $f)}"
if errorlevel 1 goto :fail

echo [4/5] Injecting this PC's local agent token and verifying version...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';$t=(Get-Content '%TOKENFILE%' -Raw).Trim();$p='%EXT%\config.js';$s=Get-Content $p -Raw;$s=$s.Replace('__RAH_TOKEN__',$t);Set-Content -LiteralPath $p -Value $s -Encoding UTF8;$m=Get-Content '%EXT%\manifest.json' -Raw|ConvertFrom-Json;if($m.version -ne '1.2.0'){throw ('Wrong extension version: '+$m.version)};Write-Host 'RAH Browser Bridge v1.2 verified.' -ForegroundColor Green"
if errorlevel 1 goto :fail

echo [5/5] Opening browser extension page...
start "" explorer.exe "%EXT%"
where chrome.exe >nul 2>&1 && start "" chrome.exe "chrome://extensions/"
where msedge.exe >nul 2>&1 && start "" msedge.exe "edge://extensions/"

echo.
echo ============================================================
echo  RAH BROWSER BRIDGE v1.2 READY
echo ============================================================
echo Folder: %EXT%
echo.
echo Browser step:
echo   - If already loaded: press RELOAD on RAH Browser Bridge.
echo   - If not loaded: Developer mode ^> Load unpacked ^> select folder above.
echo   - Return to the same ChatGPT tab and press F5 once.
echo.
echo Extension popup now includes:
echo   HEALTH
 echo   DOM PROBE
 echo   END-TO-END CPU TEST
 echo   SHOW DIAGNOSTICS
 echo ============================================================
pause
exit /b 0

:fail
color 0C
echo.
echo RAH Browser Bridge v1.2 repo update failed.
echo Folder: %EXT%
pause
exit /b 9

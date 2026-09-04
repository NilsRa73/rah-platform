@echo off
setlocal EnableExtensions
chcp 65001 >nul
color 0E
title RAH AI BROWSER - LOCAL AGENT MODE

set "AGENTROOT=%LOCALAPPDATA%\RAH\LocalAgent"
set "TOKENFILE=%AGENTROOT%\token.txt"
set "EXT=%LOCALAPPDATA%\RAH\BrowserBridgeV1"
set "PROFILE=%LOCALAPPDATA%\RAH\RavenBrowserProfile"
set "RAW=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/browser-bridge-v1"

echo ============================================================
echo  RAH AI BROWSER
echo  ChatGPT + RAH Local Agent + Browser Bridge v1.2
echo ============================================================
echo.

if not exist "%TOKENFILE%" (
  color 0C
  echo ERROR: RAH Local Agent is not installed.
  echo Missing: %TOKENFILE%
  pause
  exit /b 1
)

echo [1/6] Checking local RAH Agent...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "try{$h=Invoke-RestMethod 'http://127.0.0.1:18779/health' -TimeoutSec 4;if(-not $h.ok){exit 2};Write-Host ('RAH Local Agent ONLINE v'+$h.version) -ForegroundColor Green}catch{Write-Host $_.Exception.Message -ForegroundColor Red;exit 2}"
if errorlevel 1 (
  color 0C
  echo RAH Local Agent is not answering on 127.0.0.1:18779.
  pause
  exit /b 2
)

echo [2/6] Updating canonical Browser Bridge v1.2...
if not exist "%EXT%" mkdir "%EXT%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';$base='%RAW%';$dst='%EXT%';$files=@('manifest.json','config.js','background.js','content.js','popup.html','popup.js','README.txt');foreach($f in $files){Invoke-WebRequest -UseBasicParsing ($base+'/'+$f) -OutFile (Join-Path $dst $f)};$t=(Get-Content '%TOKENFILE%' -Raw).Trim();$p=Join-Path $dst 'config.js';$s=Get-Content $p -Raw;$s=$s.Replace('__RAH_TOKEN__',$t);Set-Content -LiteralPath $p -Value $s -Encoding UTF8;$m=Get-Content (Join-Path $dst 'manifest.json') -Raw|ConvertFrom-Json;if($m.version -ne '1.2.0'){throw ('Wrong bridge version: '+$m.version)}"
if errorlevel 1 goto :fail

echo [3/6] Finding Chrome or Edge...
set "BROWSER="
set "BROWSERNAME="
for %%P in (
  "%ProgramFiles%\Google\Chrome\Application\chrome.exe"
  "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
  "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
) do (
  if not defined BROWSER if exist "%%~P" (
    set "BROWSER=%%~P"
    set "BROWSERNAME=Google Chrome"
  )
)
if not defined BROWSER (
  for %%P in (
    "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
    "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
  ) do (
    if not defined BROWSER if exist "%%~P" (
      set "BROWSER=%%~P"
      set "BROWSERNAME=Microsoft Edge"
    )
  )
)
if not defined BROWSER (
  color 0C
  echo No supported Chromium browser found.
  pause
  exit /b 3
)

echo Browser: %BROWSERNAME%

echo [4/6] Preparing dedicated RAH browser profile...
if not exist "%PROFILE%" mkdir "%PROFILE%"

echo [5/6] Creating RAH AI Browser desktop shortcut...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$desktop=[Environment]::GetFolderPath('Desktop');$lnk=Join-Path $desktop 'RAH AI Browser.lnk';$w=New-Object -ComObject WScript.Shell;$s=$w.CreateShortcut($lnk);$s.TargetPath='%BROWSER%';$s.Arguments='--user-data-dir=\"%PROFILE%\" --load-extension=\"%EXT%\" --no-first-run https://chatgpt.com/';$s.WorkingDirectory=Split-Path '%BROWSER%';$s.IconLocation='%BROWSER%,0';$s.Description='RAH AI Browser - ChatGPT connected to RAH Local Agent';$s.Save();Write-Host ('Shortcut: '+$lnk) -ForegroundColor Green"
if errorlevel 1 goto :fail

echo [6/6] Starting RAH AI Browser...
start "" "%BROWSER%" --user-data-dir="%PROFILE%" --load-extension="%EXT%" --no-first-run "https://chatgpt.com/"

echo.
echo ============================================================
echo  RAH AI BROWSER STARTED
echo ============================================================
echo Browser   : %BROWSERNAME%
echo Profile   : %PROFILE%
echo Extension : %EXT%
echo Agent     : http://127.0.0.1:18779
echo.
echo First launch may ask you to sign in to ChatGPT once because
echo this is a separate RAH browser profile.
echo.
echo When loaded correctly, ChatGPT shows:
echo   RAH ONLINE - queue 0
echo in the lower-right corner.
echo.
echo A desktop shortcut named RAH AI Browser is now installed.
echo ============================================================
pause
exit /b 0

:fail
color 0C
echo.
echo ============================================================
echo  RAH AI BROWSER SETUP FAILED
echo ============================================================
echo Extension folder: %EXT%
echo Agent root      : %AGENTROOT%
echo.
pause
exit /b 9

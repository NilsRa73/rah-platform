$ErrorActionPreference='Stop'
$Desktop=[Environment]::GetFolderPath('Desktop')
$Root=Join-Path $Desktop 'RAH AI Studios'
$Repo=Join-Path $Root 'rah-platform'
$Raw='https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
New-Item -ItemType Directory -Force -Path $Root,$Repo | Out-Null
$files=@('START-RAH-HOME-CONTROL.bat','START-RAH-BRIDGE-AUTOSTART.bat','INSTALL-RAH-AUTOSTART.bat','RAH-CHATGPT-WHEEL.user.js','UPDATE-RAH-RAVEN.ps1','START-RAH-RAVEN-V2.bat')
foreach($f in $files){ try { Invoke-WebRequest -UseBasicParsing -Uri "$Raw/$f" -OutFile (Join-Path $Repo $f) } catch { Write-Host "Hoppet over $f : $($_.Exception.Message)" -ForegroundColor Yellow } }
$links=@{
 'RAH - Home Control.lnk'='START-RAH-HOME-CONTROL.bat';
 'RAH - Start Raven.lnk'='START-RAH-RAVEN-V2.bat';
 'RAH - Update.lnk'='UPDATE-RAH-RAVEN.ps1';
 'RAH - Install Autostart.lnk'='INSTALL-RAH-AUTOSTART.bat';
 'RAH - Command Wheel.lnk'='RAH-CHATGPT-WHEEL.user.js'
}
$ws=New-Object -ComObject WScript.Shell
foreach($name in $links.Keys){$target=Join-Path $Repo $links[$name];if(Test-Path $target){$s=$ws.CreateShortcut((Join-Path $Root $name));if($target.EndsWith('.ps1')){$s.TargetPath='powershell.exe';$s.Arguments="-NoProfile -ExecutionPolicy Bypass -File `"$target`""}else{$s.TargetPath=$target};$s.WorkingDirectory=$Repo;$s.Save()}}
$readme=@'
RAH AI STUDIOS - START HER

1. RAH - Start Raven      = start/installer hovedsystem
2. RAH - Home Control     = åpne Home Control
3. RAH - Update           = hent siste RAH-versjon
4. RAH - Install Autostart= gjør Bridge klar ved Windows-innlogging
5. RAH - Command Wheel    = åpne Tampermonkey-scriptet for ChatGPT

Normal bruk etter oppsett: ChatGPT -> RAH Wheel -> Home Control.
'@
Set-Content -LiteralPath (Join-Path $Root 'START HER.txt') -Value $readme -Encoding UTF8
Write-Host "RAH AI Studios-mappen er klar på skrivebordet:" -ForegroundColor Green
Write-Host $Root -ForegroundColor Cyan
Start-Process explorer.exe -ArgumentList "`"$Root`""

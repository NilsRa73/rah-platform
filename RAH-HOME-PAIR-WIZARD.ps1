param([ValidateRange(1024,65535)][int]$Port=18766)
$ErrorActionPreference='Stop'
$roots=@((Join-Path $env:LOCALAPPDATA 'RAH\Home'),(Join-Path $env:LOCALAPPDATA 'RAH\HomeNode'))
$client=$null
foreach($r in $roots){$p=Join-Path $r 'RAH-HOME-NODE-CLIENT.ps1';if(Test-Path -LiteralPath $p){$client=$p;break}}
if(-not $client){throw 'Installer først RAH-HOME-INSTALL.ps1 i Leader-modus.'}
function PrivateIP([string]$ip){if($ip-eq'127.0.0.1'){return $true};$p=$ip.Split('.');if($p.Count-ne4){return $false};try{$n=$p|%{[int]$_}}catch{return $false};return($n[0]-eq10)-or($n[0]-eq192-and$n[1]-eq168)-or($n[0]-eq172-and$n[1]-ge16-and$n[1]-le31)}
Write-Host 'RAH HOME PAIR WIZARD' -ForegroundColor Yellow
Write-Host 'Kun for egne/autoriserte maskiner på privat lokalnett.'
$ip=(Read-Host 'Worker IP-adresse').Trim();if(-not(PrivateIP $ip)){throw 'Kun privat RFC1918 IPv4 er tillatt.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $ip -Port $Port -Action hello
if($LASTEXITCODE-ne0){throw 'Fant ikke en fungerende RAH Node Agent på adressen.'}
$code=(Read-Host 'Skriv PAIR CODE som vises på worker-PC').Trim();if($code-notmatch '^\d{6}$'){throw 'Pair code må være seks sifre.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $ip -Port $Port -Action pair -PairCode $code
if($LASTEXITCODE-ne0){throw 'Pairing feilet.'}
$raw=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $ip -Port $Port -Action systemInfo | Out-String
if($LASTEXITCODE-ne0){throw 'Pairing ble lagret, men systemInfo-test feilet.'}
try{$info=$raw|ConvertFrom-Json}catch{throw 'Noden svarte, men systemInfo kunne ikke valideres.'}
if(-not $info.ok -or -not $info.result.computerName){throw 'Noden returnerte ugyldig systemInfo.'}
$receipt=[pscustomobject]@{schema='rah-home-pairing-receipt';version=1;nodeAddress=$ip;port=$Port;computerName=[string]$info.result.computerName;pairedAt=(Get-Date).ToUniversalTime().ToString('o');source='explicit-pair-code-and-authenticated-system-info'}
$out=Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\rah-home-pairing.json'
$receipt|ConvertTo-Json|Set-Content -LiteralPath $out -Encoding utf8
Write-Host "FERDIG: $($receipt.computerName) ($ip) er paret og verifisert." -ForegroundColor Green
Write-Host "Pairing-bevis uten token: $out"
Start-Process 'https://nilsra73.github.io/rah-platform/RAH-HOME-TRUST.html'
Start-Process explorer.exe -ArgumentList "/select,`"$out`""

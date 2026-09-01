param([ValidateRange(1024,65535)][int]$Port=18766)
$ErrorActionPreference='Stop'
$dir=Join-Path $env:LOCALAPPDATA 'RAH\HomeNode'
$client=Join-Path $dir 'RAH-HOME-NODE-CLIENT.ps1'
if(-not(Test-Path -LiteralPath $client)){throw 'Installer først RAH-HOME-NODE-SETUP.ps1 i Leader-modus.'}
function PrivateIP([string]$ip){
 if($ip -eq '127.0.0.1'){return $true};$p=$ip.Split('.');if($p.Count-ne 4){return $false};try{$n=$p|%{[int]$_}}catch{return $false};
 return ($n[0]-eq 10)-or($n[0]-eq 192-and$n[1]-eq 168)-or($n[0]-eq 172-and$n[1]-ge16-and$n[1]-le31)
}
Write-Host 'RAH HOME PAIR WIZARD' -ForegroundColor Yellow
Write-Host 'Kun for egne/autoriserte maskiner på privat lokalnett.'
$ip=(Read-Host 'Worker IP-adresse').Trim()
if(-not(PrivateIP $ip)){throw 'Kun privat RFC1918 IPv4 er tillatt.'}
Write-Host 'Tester Node Agent...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $ip -Port $Port -Action hello
if($LASTEXITCODE-ne0){throw 'Fant ikke en fungerende RAH Node Agent på adressen.'}
$code=(Read-Host 'Skriv PAIR CODE som vises på worker-PC').Trim()
if($code-notmatch '^\d{6}$'){throw 'Pair code må være seks sifre.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $ip -Port $Port -Action pair -PairCode $code
if($LASTEXITCODE-ne0){throw 'Pairing feilet.'}
Write-Host 'Pairing OK. Tester health...' -ForegroundColor Green
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $ip -Port $Port -Action health
if($LASTEXITCODE-ne0){throw 'Pairing ble lagret, men health-test feilet.'}
Write-Host "FERDIG: $ip er paret og svarer som RAH Home Node." -ForegroundColor Green
Write-Host 'Neste: åpne RAH Home Nexus / Home Cluster og bruk samme IP på den klarerte worker-en.'

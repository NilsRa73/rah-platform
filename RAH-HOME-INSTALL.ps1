param([ValidateSet('Leader','Worker')][string]$Mode='Leader')
$ErrorActionPreference='Stop'
$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$dir=Join-Path $env:LOCALAPPDATA 'RAH\Home'
New-Item -ItemType Directory -Path $dir -Force|Out-Null
$common=@('RAH-HOME-NODE-AGENT.ps1','RAH-HOME-NODE-CLIENT.ps1','RAH-HOME-NODE-JOB.ps1','RAH-HOME-CLUSTER-RUN.ps1','RAH-HOME-PAIR-WIZARD.ps1')
foreach($f in $common){Invoke-WebRequest -UseBasicParsing -Uri "$base/$f" -OutFile (Join-Path $dir $f)}
$desktop=[Environment]::GetFolderPath('Desktop')
function Test-PrivateIPv4([string]$ip){$p=$ip.Split('.');if($p.Count-ne4){return $false};try{$n=$p|%{[int]$_}}catch{return $false};return($n[0]-eq10)-or($n[0]-eq192-and$n[1]-eq168)-or($n[0]-eq172-and$n[1]-ge16-and$n[1]-le31)}
if($Mode-eq'Worker'){
 $candidates=@(Get-NetIPConfiguration -ErrorAction SilentlyContinue|?{$_.NetAdapter.Status-eq'Up'}|%{$_.IPv4Address.IPAddress}|?{$_-and(Test-PrivateIPv4 $_)}|Select-Object -Unique)
 if($candidates.Count-eq0){throw 'Fant ingen aktiv privat IPv4-adresse. Koble PC-en til hjemmenettverket og kjør installasjonen igjen.'}
 Write-Host 'Private adresser på denne PC-en:' -ForegroundColor Yellow
 for($i=0;$i-lt$candidates.Count;$i++){Write-Host "[$($i+1)] $($candidates[$i])"}
 if($candidates.Count-eq1){$lanIp=$candidates[0]}else{$choice=[int](Read-Host 'Velg adressen som tilhører RAH-hjemmenettverket');if($choice-lt1-or$choice-gt$candidates.Count){throw 'Ugyldig valg.'};$lanIp=$candidates[$choice-1]}
 $agent=Join-Path $dir 'RAH-HOME-NODE-AGENT.ps1';$cmd=Join-Path $desktop 'RAH Home Worker.cmd'
 "@echo off`r`ntitle RAH Home Worker - $lanIp`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$agent`" -ListenAddress $lanIp -AllowLan -Port 18766`r`npause"|Set-Content -LiteralPath $cmd -Encoding ascii
 Write-Host 'WORKER READY' -ForegroundColor Green;Write-Host "Bundet eksplisitt til $lanIp`:18766";Write-Host 'Start RAH Home Worker fra skrivebordet. Pair code vises i vinduet.'
}else{
 $pair=Join-Path $dir 'RAH-HOME-PAIR-WIZARD.ps1';$pairCmd=Join-Path $desktop 'RAH Pair Worker.cmd'
 "@echo off`r`ntitle RAH Pair Worker`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$pair`"`r`npause"|Set-Content -LiteralPath $pairCmd -Encoding ascii
 $url=Join-Path $desktop 'RAH Home Nexus.url';"[InternetShortcut]`r`nURL=https://nilsra73.github.io/rah-platform/RAH-HOME-NEXUS.html"|Set-Content -LiteralPath $url -Encoding ascii
 Write-Host 'LEADER READY' -ForegroundColor Green;Write-Host 'Skrivebord: RAH Home Nexus + RAH Pair Worker.'
}
Write-Host "Installert i $dir";Write-Host 'Ingen wildcard-binding eller vilkårlig fjern-shell. LAN og pairing må godkjennes eksplisitt.'

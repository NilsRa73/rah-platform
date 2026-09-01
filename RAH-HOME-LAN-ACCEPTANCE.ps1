param(
 [Parameter(Mandatory=$true)][string]$WorkerAddress,
 [ValidateRange(1024,65535)][int]$Port=18766,
 [string]$OutputPath=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'rah-home-lan-acceptance.json')
)
$ErrorActionPreference='Stop'
$client=Join-Path $env:LOCALAPPDATA 'RAH\Home\RAH-HOME-NODE-CLIENT.ps1'
if(-not(Test-Path $client)){throw 'RAH Home Leader er ikke installert. Kjør RAH-HOME-INSTALL.ps1 -Mode Leader først.'}
function Test-PrivateIPv4([string]$ip){$p=$ip.Split('.');if($p.Count-ne4){return $false};try{$n=$p|ForEach-Object{[int]$_}}catch{return $false};if($n|Where-Object{$_-lt0-or$_-gt255}){return $false};return($n[0]-eq10)-or($n[0]-eq192-and$n[1]-eq168)-or($n[0]-eq172-and$n[1]-ge16-and$n[1]-le31)}
if(-not(Test-PrivateIPv4 $WorkerAddress)){throw 'WorkerAddress må være en privat RFC1918 IPv4-adresse.'}
$results=@()
foreach($action in @('hello','health','systemInfo','benchmark')){
 $started=(Get-Date).ToUniversalTime().ToString('o')
 $text=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $WorkerAddress -Port $Port -Action $action 2>&1|Out-String
 $exit=$LASTEXITCODE
 $parsed=$null;try{$parsed=$text|ConvertFrom-Json}catch{}
 $results+=[pscustomobject]@{action=$action;ok=($exit-eq0-and$parsed-and$parsed.ok);startedAt=$started;finishedAt=(Get-Date).ToUniversalTime().ToString('o');result=$parsed;raw=if($parsed){$null}else{$text.Trim()}}
 if($exit-ne0){break}
}
$pass=($results.Count-eq4-and(@($results|Where-Object{-not$_.ok}).Count-eq0))
$out=[pscustomobject]@{schema='rah-home-lan-acceptance';version=1;workerAddress=$WorkerAddress;port=$Port;createdAt=(Get-Date).ToUniversalTime().ToString('o');pass=$pass;results=$results}
$out|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $OutputPath -Encoding utf8
if($pass){Write-Host 'PASS: RAH Home fysisk 2-PC LAN acceptance' -ForegroundColor Green;Write-Host "Resultat: $OutputPath";exit 0}
Write-Host 'FAIL: RAH Home fysisk 2-PC LAN acceptance' -ForegroundColor Red;Write-Host "Resultat: $OutputPath";exit 1

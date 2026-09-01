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
Write-Host 'RAH HOME 2-PC LAN ACCEPTANCE' -ForegroundColor Yellow
Write-Host "Worker: $WorkerAddress`:$Port"
Write-Host 'Forutsetning: RAH Home Worker kjører på den andre PC-en.'
$results=@()
$helloText=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $WorkerAddress -Port $Port -Action hello 2>&1|Out-String
$helloExit=$LASTEXITCODE;$hello=$null;try{$hello=$helloText|ConvertFrom-Json}catch{}
$helloOk=($helloExit-eq0-and$hello-and$hello.ok)
$results+=[pscustomobject]@{action='hello';ok=[bool]$helloOk;result=$hello;raw=if($hello){$null}else{$helloText.Trim()}}
if(-not$helloOk){throw "HELLO feilet: $helloText"}
Write-Host 'HELLO OK' -ForegroundColor Green
$pairCode=Read-Host 'Skriv den seks-sifrede PAIR CODE som vises på Worker-PC-en'
if($pairCode-notmatch '^\d{6}$'){throw 'Pair code må være seks sifre.'}
$pairText=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $WorkerAddress -Port $Port -Action pair -PairCode $pairCode 2>&1|Out-String
$pairExit=$LASTEXITCODE
$pairOk=($pairExit-eq0)
$results+=[pscustomobject]@{action='pair';ok=[bool]$pairOk;result=$null;raw=$pairText.Trim()}
if(-not$pairOk){throw "PAIR feilet: $pairText"}
Write-Host 'PAIR OK' -ForegroundColor Green
foreach($action in @('health','systemInfo','benchmark')){
 $started=(Get-Date).ToUniversalTime().ToString('o')
 $text=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $WorkerAddress -Port $Port -Action $action 2>&1|Out-String
 $exit=$LASTEXITCODE;$parsed=$null;try{$parsed=$text|ConvertFrom-Json}catch{}
 $ok=($exit-eq0-and$parsed-and$parsed.ok)
 $results+=[pscustomobject]@{action=$action;ok=[bool]$ok;startedAt=$started;finishedAt=(Get-Date).ToUniversalTime().ToString('o');result=$parsed;raw=if($parsed){$null}else{$text.Trim()}}
 Write-Host ("{0}: {1}" -f $action,$(if($ok){'OK'}else{'FEIL'})) -ForegroundColor $(if($ok){'Green'}else{'Red'})
}
$pass=($results.Count-eq5-and(@($results|Where-Object{-not$_.ok}).Count-eq0))
$out=[pscustomobject]@{schema='rah-home-lan-acceptance';version=1;workerAddress=$WorkerAddress;port=$Port;createdAt=(Get-Date).ToUniversalTime().ToString('o');pass=$pass;results=$results}
$out|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $OutputPath -Encoding utf8
if($pass){Write-Host 'PASS: RAH Home fysisk 2-PC LAN acceptance' -ForegroundColor Green;Write-Host "Resultat: $OutputPath";exit 0}
Write-Host 'FAIL: RAH Home fysisk 2-PC LAN acceptance' -ForegroundColor Red;Write-Host "Resultat: $OutputPath";exit 1

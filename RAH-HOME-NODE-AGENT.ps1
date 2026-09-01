param(
    [string]$ListenAddress = '127.0.0.1',
    [switch]$AllowLan,
    [ValidateRange(1024,65535)][int]$Port = 18766
)
$ErrorActionPreference='Stop'
function Test-PrivateIPv4([string]$Address){$p=$Address.Split('.');if($p.Count-ne4){return $false};try{$n=$p|%{[int]$_}}catch{return $false};if($n|?{$_-lt0-or$_-gt255}){return $false};return($n[0]-eq10)-or($n[0]-eq192-and$n[1]-eq168)-or($n[0]-eq172-and$n[1]-ge16-and$n[1]-le31)}
function New-RandomToken{$b=New-Object byte[] 32;$r=[Security.Cryptography.RandomNumberGenerator]::Create();try{$r.GetBytes($b)}finally{$r.Dispose()};(($b|%{$_.ToString('x2')})-join'')}
if($ListenAddress-eq'0.0.0.0'){throw 'Wildcard 0.0.0.0 er ikke tillatt. Bruk loopback eller eksplisitt privat LAN-adresse.'}
if($ListenAddress-ne'127.0.0.1'){
 if(-not$AllowLan){throw 'LAN-lytting krever eksplisitt -AllowLan.'}
 if(-not(Test-PrivateIPv4 $ListenAddress)){throw 'LAN ListenAddress må være privat RFC1918 IPv4.'}
 $local=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue|%{$_.IPAddress})
 if($local-notcontains$ListenAddress){throw 'ListenAddress finnes ikke på denne maskinen.'}
}
$rahDir=Join-Path $env:LOCALAPPDATA 'RAH';$statePath=Join-Path $rahDir 'home-node-agent.json';New-Item -ItemType Directory -Path $rahDir -Force|Out-Null
$token=$null;if(Test-Path -LiteralPath $statePath){try{$old=Get-Content $statePath -Raw|ConvertFrom-Json;if($old.token-and([string]$old.token).Length-ge32){$token=[string]$old.token}}catch{}}
if(-not$token){$token=New-RandomToken;[pscustomobject]@{version=1;token=$token;createdAt=(Get-Date).ToUniversalTime().ToString('o')}|ConvertTo-Json|Set-Content $statePath -Encoding utf8}
$pairCode=Get-Random -Minimum 100000 -Maximum 999999;$pairExpires=(Get-Date).AddMinutes(10);$pairFailures=0;$lockUntil=[datetime]::MinValue
$listener=New-Object Net.Sockets.TcpListener ([Net.IPAddress]::Parse($ListenAddress),$Port);$listener.Start()
function Send-Json($s,$o){$j=($o|ConvertTo-Json -Depth 6 -Compress)+"`n";$b=[Text.Encoding]::UTF8.GetBytes($j);$s.Write($b,0,$b.Length);$s.Flush()}
function Read-Line($s){$r=New-Object IO.StreamReader($s,[Text.Encoding]::UTF8,$false,4096,$true);$r.ReadLine()}
function Get-SystemInfo{$os=Get-CimInstance Win32_OperatingSystem;$cpu=Get-CimInstance Win32_Processor|select -First 1;[pscustomobject]@{computerName=$env:COMPUTERNAME;os=[string]$os.Caption;osVersion=[string]$os.Version;cpu=[string]$cpu.Name;logicalProcessors=[int]$cpu.NumberOfLogicalProcessors;memoryGB=[math]::Round(([double]$os.TotalVisibleMemorySize/1MB),1);agentVersion=2}}
function Invoke-SafeBenchmark{$sw=[Diagnostics.Stopwatch]::StartNew();$sum=0L;for($i=1;$i-le2000000;$i++){$sum=($sum+(($i*31)%9973))%2147483647};$sw.Stop();[pscustomobject]@{durationMs=$sw.ElapsedMilliseconds;checksum=$sum;iterations=2000000}}
Write-Host '';Write-Host 'RAH HOME NODE AGENT v0.2' -ForegroundColor Yellow;Write-Host "Lytter på $ListenAddress`:$Port";Write-Host "PAIR CODE: $pairCode (gyldig i 10 minutter)" -ForegroundColor Cyan;Write-Host 'Maks 5 feil pairingforsøk før 60 sekunders låsing.';Write-Host 'Tillatt: hello, pair, health, systemInfo, benchmark. Ingen vilkårlig shell.'
try{while($true){$client=$listener.AcceptTcpClient();try{$remote=([Net.IPEndPoint]$client.Client.RemoteEndPoint).Address.ToString();if($ListenAddress-ne'127.0.0.1'-and-not(Test-PrivateIPv4 $remote)){$client.Dispose();continue};$client.ReceiveTimeout=5000;$client.SendTimeout=5000;$s=$client.GetStream();$line=Read-Line $s;if(-not$line-or$line.Length-gt8192){Send-Json $s @{ok=$false;error='invalid-request'};continue};try{$req=$line|ConvertFrom-Json}catch{Send-Json $s @{ok=$false;error='invalid-json'};continue};$a=[string]$req.action;if($a-eq'hello'){Send-Json $s @{ok=$true;product='RAH Home Node Agent';version=2;computerName=$env:COMPUTERNAME;pairingRequired=$true};continue};if($a-eq'pair'){if((Get-Date)-lt$lockUntil){Send-Json $s @{ok=$false;error='pairing-temporarily-locked'};continue};if((Get-Date)-gt$pairExpires){Send-Json $s @{ok=$false;error='pair-code-expired'};continue};if([string]$req.code-ne[string]$pairCode){$pairFailures++;if($pairFailures-ge5){$lockUntil=(Get-Date).AddSeconds(60);$pairFailures=0};Send-Json $s @{ok=$false;error='pair-code-rejected'} }else{$pairFailures=0;Send-Json $s @{ok=$true;paired=$true;token=$token;computerName=$env:COMPUTERNAME}};continue};if([string]$req.token-ne$token){Send-Json $s @{ok=$false;error='unauthorized'};continue};switch($a){health{Send-Json $s @{ok=$true;status='ready';computerName=$env:COMPUTERNAME;utc=(Get-Date).ToUniversalTime().ToString('o')}}systemInfo{Send-Json $s @{ok=$true;result=(Get-SystemInfo)}}benchmark{Send-Json $s @{ok=$true;result=(Invoke-SafeBenchmark)}}default{Send-Json $s @{ok=$false;error='unsupported-action'}}}}finally{if($client){$client.Dispose()}}}}finally{$listener.Stop()}

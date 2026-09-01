param(
 [Parameter(Mandatory=$true)][string]$PlanPath,
 [string]$OutputPath=(Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'rah-home-cluster-results.json')
)
$ErrorActionPreference='Stop'
$client=Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1'
if(-not(Test-Path $client)){throw 'RAH-HOME-NODE-CLIENT.ps1 mangler ved siden av controlleren.'}
if(-not(Test-Path $PlanPath)){throw 'Cluster-planfil finnes ikke.'}
$plan=Get-Content $PlanPath -Raw|ConvertFrom-Json
if($plan.schema-ne'rah-home-cluster-plan'-or[int]$plan.version-ne1){throw 'Ugyldig cluster-plan schema/version.'}
$nodes=@($plan.nodes);if($nodes.Count-lt1-or$nodes.Count-gt16){throw 'Planen må inneholde 1-16 noder.'}
$allowed=@('health','systemInfo','benchmark')
function Test-PrivateIPv4([string]$ip){if($ip-eq'127.0.0.1'){return $true};$p=$ip.Split('.');if($p.Count-ne4){return $false};try{$n=$p|%{[int]$_}}catch{return $false};return($n[0]-eq10)-or($n[0]-eq192-and$n[1]-eq168)-or($n[0]-eq172-and$n[1]-ge16-and$n[1]-le31)}
$results=@()
foreach($n in $nodes){
 $ip=[string]$n.nodeAddress;$port=[int]$n.port;$job=[string]$n.job
 if(-not(Test-PrivateIPv4 $ip)){throw "Avviser ikke-privat node: $ip"}
 if($port-lt1024-or$port-gt65535){throw "Ugyldig port for $ip"}
 if($allowed-notcontains$job){throw "Ikke tillatt cluster-jobb: $job"}
 $started=(Get-Date).ToUniversalTime().ToString('o')
 $text='';$exit=1
 try{$text=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $ip -Port $port -Action $job 2>&1|Out-String;$exit=$LASTEXITCODE}catch{$text=$_.Exception.Message;$exit=1}
 $parsed=$null;try{$parsed=$text|ConvertFrom-Json}catch{}
 $results+=[pscustomobject]@{nodeAddress=$ip;port=$port;job=$job;ok=($exit-eq0-and$parsed-and$parsed.ok);startedAt=$started;finishedAt=(Get-Date).ToUniversalTime().ToString('o');result=$parsed;message=if($parsed){$null}else{$text.Trim()}}
}
$out=[pscustomobject]@{schema='rah-home-cluster-results';version=1;createdAt=(Get-Date).ToUniversalTime().ToString('o');results=$results}
$parent=Split-Path -Parent $OutputPath;if($parent){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
$out|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "RAH Cluster ferdig: $($results.Count) node-jobber. Resultat: $OutputPath" -ForegroundColor Green

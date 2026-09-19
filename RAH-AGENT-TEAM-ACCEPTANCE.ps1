param(
    [string]$BridgeRoot='C:\RAH\AgentBridge',
    [string]$WorkerRoot='C:\RAH\AgentWorker',
    [string]$BusRoot='C:\RAH\AgentBus',
    [int]$TimeoutSeconds=90,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:RahAgentTeamAcceptanceVersion='1.0.0'
$script:Utf8=New-Object Text.UTF8Encoding($false)

function Wait-RahJobFile {
    param([string]$JobId,[int]$Seconds)
    $end=(Get-Date).AddSeconds($Seconds)
    do {
        foreach($pair in @(@('completed','results'),@('failed','failed'))){
            $path=Join-Path (Join-Path $BusRoot $pair[1]) ($JobId + '.json')
            if(Test-Path -LiteralPath $path -PathType Leaf){
                $doc=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
                return [pscustomobject]@{status=$pair[0];path=$path;doc=$doc}
            }
        }
        Start-Sleep -Milliseconds 300
    } while((Get-Date)-lt$end)
    return $null
}

function Invoke-RahEnqueue {
    param([string]$Kind,[object]$Payload)
    $tokenPath=Join-Path $BridgeRoot 'token.txt'
    if(-not(Test-Path -LiteralPath $tokenPath -PathType Leaf)){throw 'Agent Bridge token missing.'}
    $token=(Get-Content -LiteralPath $tokenPath -Raw).Trim()
    if($token.Length -lt 24){throw 'Agent Bridge token invalid.'}
    $body=@{kind=$Kind;source='rah-agent-team-acceptance';payload=$Payload}|ConvertTo-Json -Depth 8
    return Invoke-RestMethod -Uri 'http://127.0.0.1:18781/v1/jobs/enqueue' -Method Post -Headers @{Authorization=('Bearer '+$token)} -ContentType 'application/json' -Body $body -TimeoutSec 8
}

if($SelfTest){
    if($script:RahAgentTeamAcceptanceVersion -ne '1.0.0'){throw 'version mismatch'}
    if($TimeoutSeconds -lt 5){throw 'timeout self-test mismatch'}
    Write-Host 'PASS: RAH Agent Team Acceptance v1 self-test' -ForegroundColor Green
    exit 0
}

$reportRoot=Join-Path $WorkerRoot 'reports'
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$bridge=$null;$worker=$null;$raven=$null;$ai=$null;$providers=$null
try{$bridge=Invoke-RestMethod 'http://127.0.0.1:18781/health' -TimeoutSec 5}catch{}
$statePath=Join-Path $WorkerRoot 'worker-state.json'
if(Test-Path -LiteralPath $statePath -PathType Leaf){try{$worker=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json}catch{}}
try{$raven=Invoke-RestMethod 'http://127.0.0.1:18765/agent/jobs/health' -TimeoutSec 5}catch{}
try{$ai=Invoke-RestMethod 'http://127.0.0.1:18765/ai/health' -TimeoutSec 5}catch{}
try{$providers=Invoke-RestMethod 'http://127.0.0.1:18765/ai/providers' -TimeoutSec 6}catch{}

$corePass=[bool]($bridge -and $bridge.ok -and $worker -and [string]$worker.version -eq '1.0.0' -and $worker.execCapability -eq $false)
$ravenSmoke='SKIP_NOT_READY'
$aiSmoke='SKIP_NOT_READY'
$ravenJobId=$null;$aiJobId=$null

if($corePass -and $raven -and $raven.ready -eq $true){
    try{
        $q=Invoke-RahEnqueue 'system.inventory' @{}
        $ravenJobId=[string]$q.job.id
        $done=Wait-RahJobFile $ravenJobId $TimeoutSeconds
        if($done -and $done.status -eq 'completed'){$ravenSmoke='PASS'}
        elseif($done){$ravenSmoke='FAIL'}else{$ravenSmoke='TIMEOUT'}
    }catch{$ravenSmoke='FAIL'}
}

if($corePass -and $ai -and $ai.ok -eq $true){
    try{
        $q=Invoke-RahEnqueue 'agent.message' @{message='Svar kun med: RAH AGENT TEAM OK'}
        $aiJobId=[string]$q.job.id
        $done=Wait-RahJobFile $aiJobId $TimeoutSeconds
        if($done -and $done.status -eq 'completed'){$aiSmoke='PASS'}
        elseif($done){$aiSmoke='FAIL'}else{$aiSmoke='TIMEOUT'}
    }catch{$aiSmoke='FAIL'}
}

$providerRows=@()
if($providers -and $providers.providers){
    foreach($p in @($providers.providers)){
        $providerRows += [pscustomobject]@{id=[string]$p.id;online=[bool]$p.online;ready=[bool]$p.ready;detail=[string]$p.detail}
    }
}
$overall=if(-not$corePass){'FAIL'}elseif($ravenSmoke -in @('FAIL','TIMEOUT') -or $aiSmoke -in @('FAIL','TIMEOUT')){'FAIL'}elseif($ravenSmoke -eq 'PASS' -or $aiSmoke -eq 'PASS'){'PASS'}else{'CORE_PASS_PROVIDER_PENDING'}
$doc=[pscustomobject]@{
 schema='rah-agent-team-acceptance';version=1;acceptanceVersion=$script:RahAgentTeamAcceptanceVersion;
 createdAt=(Get-Date).ToUniversalTime().ToString('o');computerName=$env:COMPUTERNAME;
 corePass=$corePass;ravenSmoke=$ravenSmoke;aiSmoke=$aiSmoke;ravenJobId=$ravenJobId;aiJobId=$aiJobId;
 providers=@($providerRows);overall=$overall;bridgeTokenCollected=$false;arbitraryCommands=$false
}
$json=Join-Path $reportRoot 'rah-agent-team-acceptance-latest.json'
$txt=Join-Path $reportRoot 'RAH-AGENT-TEAM-ACCEPTANCE.txt'
[IO.File]::WriteAllText($json,($doc|ConvertTo-Json -Depth 8),$script:Utf8)
$lines=@(
 'RAH AGENT TEAM ACCEPTANCE v1',
 '============================',
 ('CORE      : '+$corePass),
 ('RAVEN     : '+$ravenSmoke),
 ('AI        : '+$aiSmoke),
 ('OVERALL   : '+$overall),
 'TOKEN DUMP: False',
 'SHELL/EXEC : False'
)
foreach($p in $providerRows){$lines += ('PROVIDER  : '+$p.id+' online='+$p.online+' ready='+$p.ready+' - '+$p.detail)}
[IO.File]::WriteAllLines($txt,$lines,$script:Utf8)
$lines|ForEach-Object{Write-Host $_}
if($overall -eq 'FAIL'){exit 1}else{exit 0}
param(
    [string]$BridgeRoot = 'C:\RAH\AgentBridge',
    [string]$WorkerRoot = 'C:\RAH\AgentWorker',
    [string]$BusRoot = 'C:\RAH\AgentBus',
    [string]$BridgeUrl = 'http://127.0.0.1:18781',
    [string]$FabricUrl = 'http://127.0.0.1:18765',
    [int]$TimeoutSeconds = 120,
    [switch]$SkipTaskStart,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RahAgentTeamLiveTestVersion = '1.0.0'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

function Test-RahLoopbackUrl {
    param([string]$Url)
    try {
        $u = [Uri]$Url
        if ($u.Scheme -ne 'http') { return $false }
        return $u.Host -in @('127.0.0.1','localhost','::1')
    } catch {
        return $false
    }
}

function Join-RahUrl {
    param([string]$Base,[string]$Path)
    return $Base.TrimEnd('/') + $Path
}


function Get-RahProp {
    param([object]$Object,[string]$Name,[object]$Default='')
    if($null -eq $Object){ return $Default }
    $prop=$Object.PSObject.Properties[$Name]
    if($prop){ return $prop.Value }
    return $Default
}

function Wait-RahJson {
    param([string]$Url,[int]$Seconds=20)
    $end = (Get-Date).AddSeconds([math]::Max(1,$Seconds))
    do {
        try {
            return Invoke-RestMethod -Uri $Url -TimeoutSec 4 -ErrorAction Stop
        } catch {}
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $end)
    return $null
}

function Start-RahTask {
    param([string]$Name)
    try {
        $task = Get-ScheduledTask -TaskName $Name -ErrorAction Stop
        Start-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
        return [pscustomobject]@{name=$Name;present=$true;started=$true;state=[string]$task.State}
    } catch {
        return [pscustomobject]@{name=$Name;present=$false;started=$false;state='MISSING'}
    }
}

function Wait-RahJobFile {
    param([string]$JobId,[int]$Seconds)
    $end=(Get-Date).AddSeconds($Seconds)
    do {
        foreach($pair in @(@('completed','results'),@('failed','failed'))) {
            $path=Join-Path (Join-Path $BusRoot $pair[1]) ($JobId + '.json')
            if(Test-Path -LiteralPath $path -PathType Leaf) {
                try {
                    $doc=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
                    return [pscustomobject]@{status=$pair[0];path=$path;doc=$doc}
                } catch {
                    return [pscustomobject]@{status='invalid';path=$path;doc=$null}
                }
            }
        }
        Start-Sleep -Milliseconds 300
    } while((Get-Date)-lt$end)
    return $null
}

function Get-RahToken {
    $tokenPath=Join-Path $BridgeRoot 'token.txt'
    if(-not(Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
        throw "Agent Bridge token missing: $tokenPath"
    }
    $token=(Get-Content -LiteralPath $tokenPath -Raw).Trim()
    if($token.Length -lt 24) { throw 'Agent Bridge token invalid.' }
    return $token
}

function Invoke-RahEnqueue {
    param([string]$Token,[string]$Kind,[object]$Payload)
    $body=@{
        kind=$Kind
        source='rah-agent-team-live-test'
        payload=$Payload
    } | ConvertTo-Json -Depth 10
    return Invoke-RestMethod -Uri (Join-RahUrl $BridgeUrl '/v1/jobs/enqueue') -Method Post -Headers @{Authorization=('Bearer '+$Token)} -ContentType 'application/json' -Body $body -TimeoutSec 10
}

function Get-RahProviderRows {
    param([object]$Providers)
    $rows=@()
    if($Providers -and $Providers.providers) {
        foreach($p in @($Providers.providers)) {
            $rows += [pscustomobject]@{
                id=[string]$p.id
                online=[bool]$p.online
                ready=[bool]$p.ready
                detail=[string]$p.detail
            }
        }
    }
    return @($rows)
}

function Write-RahReport {
    param([object]$Doc)
    $reportRoot=Join-Path $WorkerRoot 'reports'
    New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
    $json=Join-Path $reportRoot 'rah-agent-team-live-latest.json'
    $txt=Join-Path $reportRoot 'RAH-AGENT-TEAM-LIVE.txt'
    [IO.File]::WriteAllText($json,($Doc|ConvertTo-Json -Depth 12),$script:Utf8)

    $lines=@(
        'RAH AGENT TEAM LIVE TEST v1',
        '===========================',
        ('PC          : '+$Doc.computerName),
        ('BRIDGE      : '+$Doc.bridge),
        ('WORKER      : '+$Doc.worker),
        ('RAVEN       : '+$Doc.raven),
        ('AI FABRIC   : '+$Doc.aiFabric),
        ('RAVEN JOB   : '+$Doc.ravenJob),
        ('RAVEN BY    : '+$Doc.ravenHandledBy),
        ('RAVEN TRY   : '+$Doc.ravenAttemptCount),
        ('AI JOB      : '+$Doc.aiJob),
        ('HANDLED BY  : '+$Doc.aiHandledBy),
        ('PROVIDER    : '+$Doc.aiProvider),
        ('MODEL       : '+$Doc.aiModel),
        ('BACKEND     : '+$Doc.aiBackend),
        ('ATTEMPTS    : '+$Doc.aiAttemptCount),
        ('FALLBACK    : '+$Doc.aiFallbackUsed),
        ('AI REPLY    : '+$Doc.aiReply),
        ('OVERALL     : '+$Doc.overall),
        ('SMALLEST FIX: '+$Doc.smallestFix),
        'TOKEN DUMP  : False',
        'SHELL/EXEC  : False'
    )
    $i=0
    foreach($a in @($Doc.ravenAttempts)) {
        $i++
        $lines += ('RAVEN TRY '+$i+' : provider='+(Get-RahProp $a 'provider')+' capability='+(Get-RahProp $a 'capability')+' result='+(Get-RahProp $a 'result')+' durationMs='+(Get-RahProp $a 'durationMs' 0))
    }
    $i=0
    foreach($a in @($Doc.aiAttempts)) {
        $i++
        $lines += ('AI TRY '+$i+'    : provider='+(Get-RahProp $a 'provider')+' model='+(Get-RahProp $a 'model')+' result='+(Get-RahProp $a 'result')+' quarantined='+(Get-RahProp $a 'quarantined' $false)+' durationMs='+(Get-RahProp $a 'durationMs' 0)+' reason='+(Get-RahProp $a 'reason'))
    }
    foreach($p in @($Doc.providers)) {
        $lines += ('PROVIDER    : '+$p.id+' online='+$p.online+' ready='+$p.ready+' - '+$p.detail)
    }
    $lines += 'MODEL HEALTH: C:\RAH\AI-Fabric\model-health.json'
    [IO.File]::WriteAllLines($txt,$lines,$script:Utf8)
    return [pscustomobject]@{json=$json;txt=$txt}
}

function Invoke-RahSelfTest {
    if(-not(Test-RahLoopbackUrl 'http://127.0.0.1:18781')) { throw 'Loopback self-test failed.' }
    if(-not(Test-RahLoopbackUrl 'http://localhost:18765')) { throw 'Localhost self-test failed.' }
    if(Test-RahLoopbackUrl 'https://example.com') { throw 'Public URL self-test failed.' }
    if($script:RahAgentTeamLiveTestVersion -ne '1.0.0') { throw 'Version self-test failed.' }

    $tmp=Join-Path $env:TEMP ('RAH-AgentTeam-Live-SelfTest-'+[guid]::NewGuid().ToString('N'))
    try {
        $oldWorkerRoot=$WorkerRoot
        Set-Variable -Name WorkerRoot -Value $tmp -Scope Script
        $doc=[pscustomobject]@{
            schema='rah-agent-team-live'
            version=1
            liveTestVersion=$script:RahAgentTeamLiveTestVersion
            createdAt=(Get-Date).ToUniversalTime().ToString('o')
            computerName='SELFTEST'
            bridge='PASS'
            worker='PASS'
            raven='PASS'
            aiFabric='PASS'
            ravenJob='PASS'
            ravenHandledBy='raven'
            ravenAttemptCount=1
            ravenAttempts=@([pscustomobject]@{provider='raven';capability='system-inventory';result='PASS';durationMs=1})
            aiJob='PASS'
            aiHandledBy='mock'
            aiProvider='mock'
            aiModel='mock'
            aiBackend='mock-backend'
            aiAttemptCount=1
            aiFallbackUsed=$false
            aiAttempts=@([pscustomobject]@{provider='mock';model='mock';result='PASS';quarantined=$false;durationMs=1;reason=''})
            aiReply='RAH LIVE AGENT OK'
            overall='PASS'
            smallestFix=''
            providers=@()
            bridgeTokenCollected=$false
            arbitraryCommands=$false
        }
        $paths=Write-RahReport $doc
        if(-not(Test-Path -LiteralPath $paths.json -PathType Leaf)) { throw 'JSON report self-test failed.' }
        if(-not(Test-Path -LiteralPath $paths.txt -PathType Leaf)) { throw 'TXT report self-test failed.' }
        $raw=Get-Content -LiteralPath $paths.json -Raw
        if($raw -match '(?i)bearer\s+[A-Za-z0-9_\-]+' -or $raw -match '(?i)"token"\s*:') {
            throw 'Self-test detected token-like data in report.'
        }
        Set-Variable -Name WorkerRoot -Value $oldWorkerRoot -Scope Script
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host 'PASS: RAH Agent Team Live Test v1 self-test' -ForegroundColor Green
}

if($SelfTest) {
    Invoke-RahSelfTest
    exit 0
}

if(-not(Test-RahLoopbackUrl $BridgeUrl)) { throw 'BridgeUrl must be localhost HTTP.' }
if(-not(Test-RahLoopbackUrl $FabricUrl)) { throw 'FabricUrl must be localhost HTTP.' }
if($TimeoutSeconds -lt 15 -or $TimeoutSeconds -gt 600) { throw 'TimeoutSeconds must be between 15 and 600.' }

$reportRoot=Join-Path $WorkerRoot 'reports'
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null

$taskRows=@()
if(-not $SkipTaskStart) {
    foreach($name in @(
        'RAH Raven AI Providers',
        'RAH Raven Bridge',
        'RAH Agent Bridge',
        'RAH Agent Worker'
    )) {
        $taskRows += Start-RahTask $name
    }
}

$bridge = Wait-RahJson (Join-RahUrl $BridgeUrl '/health') 20
$workerState=$null
$workerStatePath=Join-Path $WorkerRoot 'worker-state.json'
$workerEnd=(Get-Date).AddSeconds(20)
do {
    if(Test-Path -LiteralPath $workerStatePath -PathType Leaf) {
        try {
            $workerState=Get-Content -LiteralPath $workerStatePath -Raw | ConvertFrom-Json
            if([string]$workerState.version -eq '1.0.0' -and $workerState.execCapability -eq $false) { break }
        } catch {}
    }
    Start-Sleep -Milliseconds 400
} while((Get-Date)-lt$workerEnd)

$fabric = Wait-RahJson (Join-RahUrl $FabricUrl '/health') 25
$raven = Wait-RahJson (Join-RahUrl $FabricUrl '/agent/jobs/health') 15
$ai = Wait-RahJson (Join-RahUrl $FabricUrl '/ai/health') 25
$providers = Wait-RahJson (Join-RahUrl $FabricUrl '/ai/providers') 15
$providerRows=Get-RahProviderRows $providers

if($ai -and $ai.ok -eq $true -and -not @($providerRows | Where-Object ready).Count -and -not $SkipTaskStart) {
    $null=Start-RahTask 'RAH Raven AI Providers'
    Start-Sleep -Seconds 2
    $ai=Wait-RahJson (Join-RahUrl $FabricUrl '/ai/health') 25
    $providers=Wait-RahJson (Join-RahUrl $FabricUrl '/ai/providers') 15
    $providerRows=Get-RahProviderRows $providers
}

$coreBridge=[bool]($bridge -and $bridge.ok)
$coreWorker=[bool]($workerState -and [string]$workerState.version -eq '1.0.0' -and $workerState.execCapability -eq $false)
$coreRaven=[bool]($raven -and $raven.ready -eq $true)
$readyAiProviders=@($providerRows | Where-Object { $_.id -in @('lmstudio','anythingllm','openai-compatible') -and $_.ready })
$coreAi=[bool]($ai -and $ai.ok -eq $true -and $readyAiProviders.Count -gt 0)

$ravenStatus='NOT_RUN'
$aiStatus='NOT_RUN'
$ravenJobId=''
$aiJobId=''
$ravenHandledBy=''
$ravenAttemptCount=0
$ravenAttempts=@()
$aiHandledBy=''
$aiProvider=''
$aiModel=''
$aiBackend=''
$aiAttemptCount=0
$aiFallbackUsed=$false
$aiAttempts=@()
$aiReply=''
$smallestFix=''

if(-not $coreBridge) {
    $smallestFix='RAH Agent Bridge svarer ikke paa localhost.'
}
elseif(-not $coreWorker) {
    $smallestFix='RAH Agent Worker har ikke gyldig non-admin state.'
}
elseif(-not $coreRaven) {
    $smallestFix='Raven Job Executor er ikke ready.'
}
elseif(-not $coreAi) {
    $smallestFix='Ingen AI-provider er ready i AI Fabric. Start LM Studio med modell eller konfigurer AnythingLLM API.'
}
else {
    $token=Get-RahToken

    try {
        $q=Invoke-RahEnqueue -Token $token -Kind 'system.inventory' -Payload @{}
        $ravenJobId=[string]$q.job.id
        $done=Wait-RahJobFile -JobId $ravenJobId -Seconds $TimeoutSeconds
        if($done -and $done.status -eq 'completed' -and [string]$done.doc.result.route -eq 'raven' -and [string]$done.doc.result.capability -eq 'system-inventory') {
            $ravenHandledBy=[string](Get-RahProp $done.doc.result 'handledBy' (Get-RahProp $done.doc.result 'provider' 'raven'))
            $ravenAttemptCount=[int](Get-RahProp $done.doc.result 'attemptCount' 0)
            $ravenAttempts=@(Get-RahProp $done.doc.result 'attempts' @())
            if($ravenHandledBy -eq 'raven' -and $ravenAttemptCount -gt 0) {
                $ravenStatus='PASS'
            } else {
                $ravenStatus='FAIL'
                $smallestFix='Raven-jobben mangler provider trace.'
            }
        }
        elseif($done -and $done.status -eq 'failed') {
            $ravenStatus='FAIL'
            $smallestFix='Raven system.inventory-jobben feilet: '+[string]$done.doc.error.message
        }
        elseif($done) {
            $ravenStatus='FAIL'
            $smallestFix='Raven system.inventory returnerte uventet resultat.'
        }
        else {
            $ravenStatus='TIMEOUT'
            $smallestFix='Raven system.inventory-jobben fikk timeout.'
        }
    } catch {
        $ravenStatus='FAIL'
        $smallestFix='Raven enqueue feilet: '+$_.Exception.Message
    }

    if($ravenStatus -eq 'PASS') {
        try {
            $q=Invoke-RahEnqueue -Token $token -Kind 'agent.message' -Payload @{
                message='Svar kun med: RAH LIVE AGENT OK'
                provider='auto'
            }
            $aiJobId=[string]$q.job.id
            $done=Wait-RahJobFile -JobId $aiJobId -Seconds $TimeoutSeconds
            if($done -and $done.status -eq 'completed' -and [string]$done.doc.result.route -eq 'ai-fabric') {
                $aiProvider=[string](Get-RahProp $done.doc.result 'provider')
                $aiHandledBy=[string](Get-RahProp $done.doc.result 'handledBy' $aiProvider)
                $aiModel=[string](Get-RahProp $done.doc.result 'model')
                $aiBackend=[string](Get-RahProp $done.doc.result 'backend')
                $aiAttemptCount=[int](Get-RahProp $done.doc.result 'attemptCount' 0)
                $aiFallbackUsed=[bool](Get-RahProp $done.doc.result 'fallbackUsed' $false)
                $aiAttempts=@(Get-RahProp $done.doc.result 'attempts' @())
                $aiReply=([string](Get-RahProp $done.doc.result 'text')).Trim()
                if($aiReply.Length -gt 300) { $aiReply=$aiReply.Substring(0,300) }
                if($aiReply -match 'RAH LIVE AGENT OK' -and $aiHandledBy -and $aiAttemptCount -gt 0 -and $aiAttempts.Count -eq $aiAttemptCount) {
                    $aiStatus='PASS'
                } elseif($aiReply -notmatch 'RAH LIVE AGENT OK') {
                    $aiStatus='FAIL'
                    $smallestFix='AI-jobben fullforte, men svaret manglet forventet LIVE-markor.'
                } else {
                    $aiStatus='FAIL'
                    $smallestFix='AI-jobben fullforte, men provider trace mangler eller er inkonsistent.'
                }
            }
            elseif($done -and $done.status -eq 'failed') {
                $aiStatus='FAIL'
                $smallestFix='AI-jobben feilet: '+[string]$done.doc.error.message
            }
            elseif($done) {
                $aiStatus='FAIL'
                $smallestFix='AI-jobben returnerte uventet resultat.'
            }
            else {
                $aiStatus='TIMEOUT'
                $smallestFix='AI-jobben fikk timeout.'
            }
        } catch {
            $aiStatus='FAIL'
            $smallestFix='AI enqueue feilet: '+$_.Exception.Message
        }
    }
}

$overall = if(
    $coreBridge -and $coreWorker -and $coreRaven -and $coreAi -and
    $ravenStatus -eq 'PASS' -and $ravenAttemptCount -gt 0 -and
    $aiStatus -eq 'PASS' -and $aiAttemptCount -gt 0
) { 'PASS' } else { 'FAIL' }

$doc=[pscustomobject]@{
    schema='rah-agent-team-live'
    version=1
    liveTestVersion=$script:RahAgentTeamLiveTestVersion
    createdAt=(Get-Date).ToUniversalTime().ToString('o')
    computerName=$env:COMPUTERNAME
    bridge=$(if($coreBridge){'PASS'}else{'FAIL'})
    worker=$(if($coreWorker){'PASS'}else{'FAIL'})
    raven=$(if($coreRaven){'PASS'}else{'FAIL'})
    aiFabric=$(if($coreAi){'PASS'}else{'FAIL'})
    ravenJob=$ravenStatus
    ravenHandledBy=$ravenHandledBy
    ravenAttemptCount=$ravenAttemptCount
    ravenAttempts=@($ravenAttempts)
    aiJob=$aiStatus
    ravenJobId=$ravenJobId
    aiJobId=$aiJobId
    aiHandledBy=$aiHandledBy
    aiProvider=$aiProvider
    aiModel=$aiModel
    aiBackend=$aiBackend
    aiAttemptCount=$aiAttemptCount
    aiFallbackUsed=$aiFallbackUsed
    aiAttempts=@($aiAttempts)
    aiReply=$aiReply
    providers=@($providerRows)
    tasks=@($taskRows)
    overall=$overall
    smallestFix=$smallestFix
    bridgeTokenCollected=$false
    arbitraryCommands=$false
}

$paths=Write-RahReport $doc
Get-Content -LiteralPath $paths.txt | ForEach-Object { Write-Host $_ }

if($overall -eq 'PASS') {
    Write-Host ''
    Write-Host 'RAH AGENT TEAM LIVE: FULL PASS' -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host ('RAH AGENT TEAM LIVE: FAIL - '+$smallestFix) -ForegroundColor Red
exit 1

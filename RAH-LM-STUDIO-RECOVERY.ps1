[CmdletBinding()]
param(
    [switch]$SelfTest,
    [string]$LmsPath = '',
    [int]$Port = 1234,
    [int]$PerModelTimeoutSeconds = 150
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:RahLmStudioRecoveryVersion = '1.0.0'
$script:SelfPath = $PSCommandPath
$script:Utf8 = New-Object Text.UTF8Encoding($false)
$script:StateRoot = 'C:\RAH\AI-Fabric'
$script:RecoveryRoot = 'C:\RAH\AI-Fabric\LMStudioRecovery'
$script:SafeModelFile = 'C:\RAH\AI-Fabric\lmstudio-model.txt'
$script:ModelHealthFile = 'C:\RAH\AI-Fabric\model-health.json'
$script:BaseUrl = ('http://127.0.0.1:{0}' -f $Port)
$script:ProbePrompt = 'What is 2 + 2? Answer briefly with the result.'
$script:Attempts = [System.Collections.Generic.List[object]]::new()

function Test-RahAdministrator {
    try {
        $id=[Security.Principal.WindowsIdentity]::GetCurrent()
        $p=New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-RahLms {
    if($LmsPath){
        if(Test-Path -LiteralPath $LmsPath -PathType Leaf){ return [IO.Path]::GetFullPath($LmsPath) }
        throw ('Specified lms.exe not found: '+$LmsPath)
    }
    $cmd=Get-Command lms.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if($cmd){ return [string]$cmd.Source }
    foreach($p in @(
        (Join-Path $HOME '.lmstudio\bin\lms.exe'),
        (Join-Path $HOME '.cache\lm-studio\bin\lms.exe')
    )){
        if(Test-Path -LiteralPath $p -PathType Leaf){ return [IO.Path]::GetFullPath($p) }
    }
    throw 'LM Studio CLI (lms.exe) ble ikke funnet. LM Studio maa ha vaert startet minst en gang.'
}

function Invoke-RahProcess {
    param(
        [string]$File,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 30,
        [switch]$IgnoreExitCode
    )
    $tmp=Join-Path $env:TEMP ('rah-lms-proc-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $stdout=Join-Path $tmp 'stdout.txt'
    $stderr=Join-Path $tmp 'stderr.txt'
    try {
        $quoted=@()
        foreach($arg in $Arguments){
            $a=[string]$arg
            if($a -match '[\s"]'){
                $a='"'+($a -replace '"','\"')+'"'
            }
            $quoted += $a
        }
        $p=Start-Process -FilePath $File -ArgumentList ($quoted -join ' ') -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if(-not $p.WaitForExit([math]::Max(1,$TimeoutSeconds)*1000)){
            try{$p.Kill()}catch{}
            return [pscustomobject]@{exitCode=124;timedOut=$true;stdout='';stderr='timeout'}
        }
        $out=if(Test-Path -LiteralPath $stdout){Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue}else{''}
        $err=if(Test-Path -LiteralPath $stderr){Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue}else{''}
        $result=[pscustomobject]@{exitCode=[int]$p.ExitCode;timedOut=$false;stdout=[string]$out;stderr=[string]$err}
        if(-not $IgnoreExitCode -and $p.ExitCode -ne 0){
            throw ('Process failed: '+$File+' '+($Arguments -join ' ')+' exit='+$p.ExitCode+' '+([string]$err).Trim())
        }
        return $result
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-RahProbeReply {
    param([string]$Text)
    $value=([string]$Text).Trim()
    if([string]::IsNullOrWhiteSpace($value)){ return $false }
    $lower=$value.ToLowerInvariant()
    if($lower -in @('incorrect','wrong','error','invalid')){ return $false }
    if($lower -match 'incorrect prompt|invalid prompt|unsupported prompt|prompt format|template error'){ return $false }
    return [bool]($value -match '(^|[^0-9])4([^0-9]|$)')
}

function Get-RahLocalModelKeys {
    param([object]$JsonValue)
    $items=@()
    if($JsonValue -is [System.Array]){
        $items=@($JsonValue)
    } elseif($null -ne $JsonValue) {
        foreach($name in @('models','data','items')){
            $prop=$JsonValue.PSObject.Properties[$name]
            if($prop -and $null -ne $prop.Value){
                $items=@($prop.Value)
                break
            }
        }
    }
    $keys=[System.Collections.Generic.List[string]]::new()
    foreach($item in $items){
        if($null -eq $item){continue}
        $typeProp=$item.PSObject.Properties['type']
        $type=if($typeProp){[string]$typeProp.Value}else{''}
        $isEmbedding=$item.PSObject.Properties['isEmbedding']
        if($type -and $type.ToLowerInvariant() -notin @('llm','model')){continue}
        if($isEmbedding -and $isEmbedding.Value -eq $true){continue}
        $key=''
        foreach($field in @('path','modelKey','key','identifier','id')){
            $prop=$item.PSObject.Properties[$field]
            if($prop -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)){
                $key=[string]$prop.Value
                break
            }
        }
        if($key -and -not $keys.Contains($key)){ $keys.Add($key) }
    }
    return @($keys)
}

function Wait-RahLmServer {
    param([int]$Seconds=35)
    $end=(Get-Date).AddSeconds($Seconds)
    do {
        try {
            $r=Invoke-RestMethod -Uri ($script:BaseUrl+'/v1/models') -TimeoutSec 4 -ErrorAction Stop
            if($null -ne $r){ return $true }
        } catch {}
        Start-Sleep -Milliseconds 700
    } while((Get-Date)-lt$end)
    return $false
}

function Get-RahApiModelKeys {
    try {
        $r=Invoke-RestMethod -Uri ($script:BaseUrl+'/v1/models') -TimeoutSec 8 -ErrorAction Stop
        $keys=[System.Collections.Generic.List[string]]::new()
        foreach($item in @($r.data)){
            $id=[string]$item.id
            if($id -and -not $keys.Contains($id)){ $keys.Add($id) }
        }
        return @($keys)
    } catch {
        return @()
    }
}

function Invoke-RahModelProbe {
    param([string]$Model,[int]$TimeoutSeconds)
    $started=Get-Date
    try {
        $body=@{
            model=$Model
            messages=@(@{role='user';content=$script:ProbePrompt})
            temperature=0
            max_tokens=32
            stream=$false
        } | ConvertTo-Json -Depth 6 -Compress
        $r=Invoke-RestMethod -Method Post -Uri ($script:BaseUrl+'/v1/chat/completions') -ContentType 'application/json' -Body $body -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        $text=''
        if($r.choices -and @($r.choices).Count -gt 0){
            $text=[string]$r.choices[0].message.content
        }
        $ms=[int]((Get-Date)-$started).TotalMilliseconds
        if(Test-RahProbeReply $text){
            return [pscustomobject]@{ok=$true;text=$text;reason='';durationMs=$ms}
        }
        return [pscustomobject]@{ok=$false;text=$text;reason=('invalid probe reply: '+$text);durationMs=$ms}
    } catch {
        $ms=[int]((Get-Date)-$started).TotalMilliseconds
        return [pscustomobject]@{ok=$false;text='';reason=$_.Exception.Message;durationMs=$ms}
    }
}

function Read-RahModelHealth {
    if(Test-Path -LiteralPath $script:ModelHealthFile -PathType Leaf){
        try {
            $doc=Get-Content -LiteralPath $script:ModelHealthFile -Raw | ConvertFrom-Json
            if($doc -and $doc.models){ return $doc }
        } catch {}
    }
    return [pscustomobject]@{schema='rah-ai-model-health';version=1;models=[pscustomobject]@{}}
}

function Set-RahModelHealthEntry {
    param(
        [object]$Doc,
        [string]$Model,
        [bool]$Healthy,
        [string]$Reason,
        [int]$DurationMs
    )
    $modelsProp=$Doc.PSObject.Properties['models']
    if(-not $modelsProp -or $null -eq $modelsProp.Value){
        $Doc | Add-Member -NotePropertyName models -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    $models=$Doc.PSObject.Properties['models'].Value
    $existing=$models.PSObject.Properties[$Model]
    $failCount=0
    $previousLastFailure=$null
    $previousLastSuccess=$null
    if($existing -and $existing.Value){
        $fc=$existing.Value.PSObject.Properties['failCount']
        if($fc){try{$failCount=[int]$fc.Value}catch{}}
        $lf=$existing.Value.PSObject.Properties['lastFailure']
        if($lf){$previousLastFailure=$lf.Value}
        $ls=$existing.Value.PSObject.Properties['lastSuccess']
        if($ls){$previousLastSuccess=$ls.Value}
    }
    if($Healthy){
        $value=[pscustomobject]@{
            state='HEALTHY'
            failCount=0
            lastSuccess=(Get-Date).ToUniversalTime().ToString('o')
            lastFailure=$previousLastFailure
            reason=''
            retryAfter=$null
            retryAfterEpoch=$null
            latencyMs=$DurationMs
            recoverySafeModel=$true
        }
    } else {
        $reasonText=[string]$Reason
        $value=[pscustomobject]@{
            state='RETEST_REQUIRED'
            failCount=($failCount+1)
            lastSuccess=$previousLastSuccess
            lastFailure=(Get-Date).ToUniversalTime().ToString('o')
            reason=$reasonText.Substring(0,[math]::Min(700,$reasonText.Length))
            retryAfter=$null
            retryAfterEpoch=$null
            lastLatencyMs=$DurationMs
            recoveryAcknowledged=$true
        }
    }
    $models | Add-Member -NotePropertyName $Model -NotePropertyValue $value -Force
}

function Save-RahModelHealth {
    param([object]$Doc)
    New-Item -ItemType Directory -Path $script:StateRoot -Force | Out-Null
    $Doc | Add-Member -NotePropertyName schema -NotePropertyValue 'rah-ai-model-health' -Force
    $Doc | Add-Member -NotePropertyName version -NotePropertyValue 1 -Force
    $Doc | Add-Member -NotePropertyName updatedAt -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
    $tmp=$script:ModelHealthFile+'.new'
    [IO.File]::WriteAllText($tmp,($Doc|ConvertTo-Json -Depth 12),$script:Utf8)
    Move-Item -LiteralPath $tmp -Destination $script:ModelHealthFile -Force
}

function Restart-RahTasks {
    $ordered=@(
        'RAH Raven AI Providers',
        'RAH Raven Bridge',
        'RAH Agent Bridge',
        'RAH Agent Worker'
    )
    foreach($name in $ordered){
        try{Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue | Out-Null}catch{}
    }
    Start-Sleep -Seconds 2
    foreach($name in $ordered){
        try{Start-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue | Out-Null}catch{}
    }
}

function Wait-RahUrl {
    param([string]$Uri,[int]$Seconds=35)
    $end=(Get-Date).AddSeconds($Seconds)
    do{
        try{
            $r=Invoke-RestMethod -Uri $Uri -TimeoutSec 4 -ErrorAction Stop
            if($null -ne $r){return $r}
        }catch{}
        Start-Sleep -Milliseconds 700
    }while((Get-Date)-lt$end)
    return $null
}

function Write-RahRecoveryState {
    param([string]$Status,[string]$SafeModel,[string]$Reason,[string]$Lms)
    try{
        New-Item -ItemType Directory -Path $script:RecoveryRoot -Force | Out-Null
        $doc=[pscustomobject]@{
            schema='rah-lm-studio-recovery'
            version=1
            recoveryVersion=$script:RahLmStudioRecoveryVersion
            createdAt=(Get-Date).ToUniversalTime().ToString('o')
            computer=$env:COMPUTERNAME
            status=$Status
            safeModel=$SafeModel
            reason=$Reason
            lmsPath=$Lms
            attempts=@($script:Attempts)
            modelDownloads=$false
            serverBind='127.0.0.1'
        }
        [IO.File]::WriteAllText((Join-Path $script:RecoveryRoot 'rah-lm-studio-recovery-latest.json'),($doc|ConvertTo-Json -Depth 10),$script:Utf8)
    }catch{}
}

function Invoke-RahSelfTest {
    if(-not(Test-RahProbeReply '4')){throw 'probe validator rejected 4'}
    if(-not(Test-RahProbeReply '2 + 2 = 4.')){throw 'probe validator rejected normal arithmetic answer'}
    if(Test-RahProbeReply 'incorrect'){throw 'probe validator accepted incorrect'}
    if(Test-RahProbeReply 'invalid prompt format'){throw 'probe validator accepted invalid prompt'}
    $sample='[{"path":"publisher/model-a","type":"llm"},{"path":"embed/model","type":"embedding"},{"modelKey":"publisher/model-b","type":"llm"}]' | ConvertFrom-Json
    $keys=@(Get-RahLocalModelKeys $sample)
    if($keys.Count -ne 2 -or $keys[0] -ne 'publisher/model-a' -or $keys[1] -ne 'publisher/model-b'){throw 'model JSON parser self-test failed'}
    $raw=Get-Content -LiteralPath $script:SelfPath -Raw
    foreach($marker in @('lms.exe','server','start','127.0.0.1','ls','--llm','--json','unload','--all','/v1/chat/completions','lmstudio-model.txt','model-health.json','RETEST_REQUIRED','RAH_LMSTUDIO_MODEL','RAH Raven Bridge','/ai/chat')){
        if(-not $raw.Contains($marker)){throw ('recovery contract missing: '+$marker)}
    }
    Write-Host 'RAH LM STUDIO RECOVERY SELFTEST: PASS'
}

if($SelfTest){
    Invoke-RahSelfTest
    exit 0
}

if(-not(Test-RahAdministrator)){
    throw 'Administrator kreves for RAH LM Studio Recovery.'
}

$lms=''
$safeModel=''
$finalReason=''
try{
    New-Item -ItemType Directory -Path $script:StateRoot,$script:RecoveryRoot -Force | Out-Null
    $lms=Get-RahLms

    $help=Invoke-RahProcess -File $lms -Arguments @('--help') -TimeoutSeconds 20 -IgnoreExitCode
    if($help.timedOut -or $help.exitCode -ne 0){throw 'lms.exe svarer ikke korrekt.'}

    $status=Invoke-RahProcess -File $lms -Arguments @('server','status','--json','--quiet') -TimeoutSeconds 20 -IgnoreExitCode
    $serverRunning=$false
    if(-not $status.timedOut -and $status.stdout){
        try{$serverRunning=[bool](($status.stdout|ConvertFrom-Json).running)}catch{}
    }
    if(-not $serverRunning -or -not(Wait-RahLmServer 5)){
        $start=Invoke-RahProcess -File $lms -Arguments @('server','start','--port',([string]$Port),'--bind','127.0.0.1') -TimeoutSeconds 45 -IgnoreExitCode
        if($start.timedOut -or $start.exitCode -ne 0){throw ('LM Studio server kunne ikke startes: '+$start.stderr)}
        if(-not(Wait-RahLmServer 45)){throw 'LM Studio server startet ikke paa localhost.'}
    }

    $ls=Invoke-RahProcess -File $lms -Arguments @('ls','--llm','--json') -TimeoutSeconds 45 -IgnoreExitCode
    if($ls.timedOut -or $ls.exitCode -ne 0){throw ('lms ls feilet: '+$ls.stderr)}
    $cliKeys=@()
    try{$cliKeys=@(Get-RahLocalModelKeys ($ls.stdout|ConvertFrom-Json))}catch{}

    $apiKeys=@(Get-RahApiModelKeys)
    $models=[System.Collections.Generic.List[string]]::new()
    foreach($m in @($apiKeys+$cliKeys)){
        if($m -and -not $models.Contains([string]$m)){$models.Add([string]$m)}
    }
    if($models.Count -eq 0){throw 'Ingen lokale LLM-modeller ble funnet i LM Studio.'}

    $preferred=''
    if(Test-Path -LiteralPath $script:SafeModelFile -PathType Leaf){
        try{$preferred=(Get-Content -LiteralPath $script:SafeModelFile -Raw).Trim()}catch{}
    }
    $ordered=[System.Collections.Generic.List[string]]::new()
    if($preferred -and $models.Contains($preferred)){$ordered.Add($preferred)}
    foreach($m in $models){if(-not $ordered.Contains($m)){$ordered.Add($m)}}

    $health=Read-RahModelHealth
    foreach($model in $ordered){
        $null=Invoke-RahProcess -File $lms -Arguments @('unload','--all') -TimeoutSeconds 30 -IgnoreExitCode
        Start-Sleep -Milliseconds 700

        $probe=Invoke-RahModelProbe -Model $model -TimeoutSeconds $PerModelTimeoutSeconds
        if($probe.ok){
            Set-RahModelHealthEntry -Doc $health -Model $model -Healthy $true -Reason '' -DurationMs $probe.durationMs
            $script:Attempts.Add([pscustomobject]@{model=$model;result='PASS';reason='';durationMs=$probe.durationMs;quarantined=$false})
            $safeModel=$model
            break
        }

        Set-RahModelHealthEntry -Doc $health -Model $model -Healthy $false -Reason $probe.reason -DurationMs $probe.durationMs
        $script:Attempts.Add([pscustomobject]@{model=$model;result='FAILED';reason=([string]$probe.reason).Substring(0,[math]::Min(500,([string]$probe.reason).Length));durationMs=$probe.durationMs;quarantined=$true})
    }

    Save-RahModelHealth $health
    if(-not $safeModel){throw 'Ingen installert LM Studio-modell besto load/inference-testen.'}

    [IO.File]::WriteAllText($script:SafeModelFile,$safeModel+[Environment]::NewLine,$script:Utf8)
    [Environment]::SetEnvironmentVariable('RAH_LMSTUDIO_MODEL',$safeModel,'User')
    $env:RAH_LMSTUDIO_MODEL=$safeModel

    Restart-RahTasks
    $bridge=Wait-RahUrl 'http://127.0.0.1:18765/health' 45
    if(-not $bridge -or $bridge.ai_fabric -ne $true){throw 'RAH Raven Bridge/AI Fabric kom ikke tilbake etter restart.'}

    $body=@{
        provider='lmstudio'
        model=$safeModel
        message=$script:ProbePrompt
    } | ConvertTo-Json -Compress
    $final=Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18765/ai/chat' -ContentType 'application/json' -Body $body -TimeoutSec $PerModelTimeoutSeconds -ErrorAction Stop
    if(-not $final.ok -or -not(Test-RahProbeReply ([string]$final.text))){
        throw 'RAH slutt-test gjennom AI Fabric feilet med SAFE MODEL.'
    }

    Write-RahRecoveryState -Status 'PASS' -SafeModel $safeModel -Reason '' -Lms $lms
    Write-Host ''
    Write-Host '===============================================' -ForegroundColor Green
    Write-Host ' RAH LM STUDIO: READY' -ForegroundColor Green
    Write-Host (' SAFE MODEL: '+$safeModel) -ForegroundColor Green
    Write-Host ' RAH AI: READY' -ForegroundColor Green
    Write-Host '===============================================' -ForegroundColor Green
    exit 0
}
catch{
    $finalReason=$_.Exception.Message
    Write-RahRecoveryState -Status 'FAIL' -SafeModel $safeModel -Reason $finalReason -Lms $lms
    Write-Host ''
    Write-Host '===============================================' -ForegroundColor Red
    Write-Host ' RAH LM STUDIO: FAIL AFTER AUTO-RECOVERY' -ForegroundColor Red
    Write-Host (' REASON: '+$finalReason) -ForegroundColor Yellow
    Write-Host '===============================================' -ForegroundColor Red
    exit 1
}

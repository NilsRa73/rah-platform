[CmdletBinding()]
param(
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:RahRavenFinalVersion = '2.0.0'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$aiFabricInstaller = Join-Path $root 'INSTALL-RAH-AI-FABRIC.ps1'
$aiRecovery = Join-Path $root 'RAH-AI-CHAT-RECOVERY.ps1'
$agentBridgeInstaller = Join-Path $root 'INSTALL-RAH-AGENT-BRIDGE.ps1'
$workerInstaller = Join-Path $root 'INSTALL-RAH-AGENT-WORKER.ps1'
$liveTest = Join-Path $root 'RAH-AGENT-TEAM-LIVE-TEST.ps1'
$bridgeDir = Join-Path $root 'desktop-bridge'
$runtimeRoot = 'C:\RAH\AI-Fabric\rah-platform'
$logDir = 'C:\RAH\Logs'
$jobDir = 'C:\RAH\AgentJobs'
$latestJson = Join-Path $logDir 'RAVEN-HOVED-PC-FINAL-LATEST.json'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcript = Join-Path $logDir ("RAVEN-HOVED-PC-FINAL-{0}.log" -f $timestamp)
$bridgeHealthUrl = 'http://127.0.0.1:18765/health'
$jobHealthUrl = 'http://127.0.0.1:18765/agent/jobs/health'
$aiHealthUrl = 'http://127.0.0.1:18765/ai/health'
$agentBridgeHealthUrl = 'http://127.0.0.1:18781/health'
$jobsUrl = 'http://127.0.0.1:18765/agent/jobs'
$recoveryJson = 'C:\RAH\AI-Fabric\Recovery\rah-ai-chat-recovery-latest.json'
$workerStatePath = 'C:\RAH\AgentWorker\worker-state.json'
$bridgeTaskName = 'RAH Raven Bridge'
$agentBridgeTaskName = 'RAH Agent Bridge'
$workerTaskName = 'RAH Agent Worker'
$script:Checks = [System.Collections.Generic.List[object]]::new()

function Test-RahAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Add-Check {
    param([string]$Name,[bool]$Ok,[string]$Detail)
    $script:Checks.Add([pscustomobject]@{name=$Name;ok=$Ok;detail=$Detail})
    if(-not $Ok){ throw ("{0}: {1}" -f $Name,$Detail) }
}

function Assert-RahPowerShellParse {
    param([string]$Path)
    $tokens=$null
    $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors) | Out-Null
    if(@($errors).Count){ throw ("{0} parse failed: {1}" -f $Path,$errors[0].Message) }
}

function Invoke-RahPowerShell {
    param([string]$Path,[string[]]$Arguments=@())
    & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Path @Arguments
    if($LASTEXITCODE -ne 0){ throw ("{0} failed with exit {1}" -f [IO.Path]::GetFileName($Path),$LASTEXITCODE) }
}

function Wait-RahJson {
    param([string]$Uri,[int]$Seconds=30)
    $end=(Get-Date).AddSeconds([math]::Max(1,$Seconds))
    do{
        try{ return Invoke-RestMethod -Method Get -Uri $Uri -TimeoutSec 4 -ErrorAction Stop }catch{}
        Start-Sleep -Milliseconds 600
    }while((Get-Date)-lt$end)
    return $null
}

function Invoke-RahSelfTest {
    $required=@(
        $aiFabricInstaller,
        $aiRecovery,
        $agentBridgeInstaller,
        $workerInstaller,
        $liveTest,
        (Join-Path $bridgeDir 'raven_ai_fabric.py'),
        (Join-Path $bridgeDir 'raven_bridge_agent.py'),
        (Join-Path $bridgeDir 'raven_jobs.py')
    )
    foreach($path in $required){
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){ throw ("Missing canonical file: {0}" -f $path) }
    }
    foreach($path in @($aiFabricInstaller,$aiRecovery,$agentBridgeInstaller,$workerInstaller,$liveTest)){
        Assert-RahPowerShellParse $path
    }
    $installerText=Get-Content -LiteralPath $aiFabricInstaller -Raw
    $recoveryText=Get-Content -LiteralPath $aiRecovery -Raw
    if($installerText -notmatch '\[switch\]\$NoPause'){ throw 'AI Fabric installer lacks noninteractive NoPause contract.' }
    foreach($marker in @(
        "RahAiChatRecoveryVersion = '1.2.0'",
        'AI_FABRIC_VERSION = "1.3.1"',
        '/ai/self-test',
        'AUTO-REPAIR',
        'RAH AUTO SELFTEST: FULL PASS'
    )){
        if(-not $recoveryText.Contains($marker)){ throw ("Recovery marker missing: {0}" -f $marker) }
    }
    Write-Host 'PASS: RAH Raven FINAL v2 autonomous self-test'
}

if($SelfTest){
    Invoke-RahSelfTest
    exit 0
}

if(-not(Test-RahAdministrator)){
    $self=$MyInvocation.MyCommand.Path
    $quotedSelf=('"{0}"' -f $self)
    $child=Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$quotedSelf
    ) -Verb RunAs -Wait -PassThru
    exit $child.ExitCode
}

New-Item -ItemType Directory -Force -Path $logDir,$jobDir | Out-Null
Start-Transcript -Path $transcript -Force | Out-Null

$final='FAIL'
$errorText=$null
$jobResult=$null
$winnerProvider=''
$winnerModel=''

try{
    Invoke-RahSelfTest
    Add-Check 'Canonical package' $true 'parse + autonomous repair contract'

    Invoke-RahPowerShell $aiFabricInstaller @('-Mode','Repair','-NoPause')
    Add-Check 'AI Fabric repair' $true 'canonical runtime refreshed and tasks installed'

    Invoke-RahPowerShell $agentBridgeInstaller @(
        '-InstallRoot','C:\RAH\AgentBridge',
        '-BusRoot','C:\RAH\AgentBus',
        '-SourceDirectory',$root
    )
    Add-Check 'Agent Bridge repair' $true 'loopback structured AgentBus installed'

    Invoke-RahPowerShell $aiRecovery @(
        '-RuntimeRoot',$runtimeRoot,
        '-SourceDirectory',$root
    )
    Add-Check 'Autonomous AI repair/self-test' $true 'fallback + quarantine + Agent Team LIVE passed'

    if(Test-Path -LiteralPath $recoveryJson -PathType Leaf){
        $recovery=Get-Content -LiteralPath $recoveryJson -Raw | ConvertFrom-Json
        Add-Check 'Recovery state' ([string]$recovery.status -eq 'PASS') ([string]$recovery.status)
        $winnerProvider=[string]$recovery.winnerProvider
        $winnerModel=[string]$recovery.winnerModel
        Add-Check 'AI winner' (-not [string]::IsNullOrWhiteSpace($winnerProvider)) ($winnerProvider+'/'+$winnerModel)
    }else{
        throw ("Recovery state missing: {0}" -f $recoveryJson)
    }

    $bridgeTask=Get-ScheduledTask -TaskName $bridgeTaskName -ErrorAction Stop
    Add-Check 'Bridge task RunLevel' ([string]$bridgeTask.Principal.RunLevel -eq 'Highest') ([string]$bridgeTask.Principal.RunLevel)
    $bridgeAction=(($bridgeTask.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments) $($_.WorkingDirectory)" }) -join ' ')
    Add-Check 'Single canonical runtime' ($bridgeAction -match [regex]::Escape('C:\RAH\AI-Fabric\rah-platform')) $bridgeAction

    $null=Get-ScheduledTask -TaskName $agentBridgeTaskName -ErrorAction Stop
    $null=Get-ScheduledTask -TaskName $workerTaskName -ErrorAction Stop
    Add-Check 'Agent tasks present' $true 'Agent Bridge + Agent Worker'

    $h=Wait-RahJson $bridgeHealthUrl 35
    Add-Check 'Raven Bridge' ($h -and $h.job_executor -eq $true -and $h.job_executor_ready -eq $true -and $h.job_executor_elevated -eq $true -and $h.ai_fabric -eq $true) '18765 ready/elevated/AI'

    $jh=Wait-RahJson $jobHealthUrl 10
    Add-Check 'Raven Jobs' ($jh -and $jh.ready -eq $true -and $jh.elevated -eq $true -and $jh.arbitrary_commands -eq $false -and $jh.arguments_allowed -eq $false) 'ready/elevated/read-only allowlist'

    $ah=Wait-RahJson $agentBridgeHealthUrl 10
    Add-Check 'Agent Bridge' ($ah -and $ah.ok -eq $true -and $ah.execCapability -eq $false) '18781 loopback structured bus'

    $aih=Wait-RahJson $aiHealthUrl 10
    Add-Check 'AI provider ready' ($aih -and $aih.ok -eq $true -and @($aih.ready_providers).Count -gt 0) ($winnerProvider+'/'+$winnerModel)

    if(Test-Path -LiteralPath $workerStatePath -PathType Leaf){
        $ws=Get-Content -LiteralPath $workerStatePath -Raw | ConvertFrom-Json
        Add-Check 'Agent Worker state' ($ws.execCapability -eq $false) 'execCapability=false'
    }else{
        throw ("Agent Worker state missing: {0}" -f $workerStatePath)
    }

    $requestId=("hovedpc-final-{0}" -f $timestamp)
    $payload=@{
        capability='system-inventory'
        confirm=$true
        client_request_id=$requestId
    } | ConvertTo-Json -Compress
    $submitted=Invoke-RestMethod -Method Post -Uri $jobsUrl -ContentType 'application/json' -Body $payload -TimeoutSec 8
    Add-Check 'System inventory accepted' ($submitted.ok -eq $true -and $submitted.accepted -eq $true) ([string]$submitted.job.id)
    $jobId=[string]$submitted.job.id
    if([string]::IsNullOrWhiteSpace($jobId)){ throw 'Raven returned no system-inventory job id.' }

    for($i=0;$i -lt 40;$i++){
        Start-Sleep -Milliseconds 500
        $poll=Wait-RahJson ("{0}/{1}" -f $jobsUrl,$jobId) 2
        if($poll -and $poll.job.status -in @('succeeded','failed','completed')){
            $jobResult=$poll.job
            break
        }
    }
    if($null -eq $jobResult){ throw 'system-inventory did not reach terminal status.' }
    Add-Check 'System inventory result' ($jobResult.status -in @('succeeded','completed') -and $jobResult.result.ok -eq $true) ([string]$jobResult.status)
    Add-Check 'Read-only invariant' ($jobResult.result.read_only -eq $true -and $jobResult.result.files_modified -eq $false -and $jobResult.result.arbitrary_commands -eq $false) 'read_only=true; files_modified=false; arbitrary_commands=false'

    $final='PASS'
}
catch{
    $errorText=$_.Exception.Message
}
finally{
    $report=[ordered]@{
        schema='rah-raven-hovedpc-final-v2'
        version=$script:RahRavenFinalVersion
        generated_at=(Get-Date).ToString('o')
        computer=$env:COMPUTERNAME
        result=$final
        error=$errorText
        canonical_runtime=$runtimeRoot
        winner_provider=$winnerProvider
        winner_model=$winnerModel
        checks=@($script:Checks)
        system_inventory_job=$jobResult
        transcript=$transcript
    }
    $report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $latestJson -Encoding UTF8
    try{Stop-Transcript | Out-Null}catch{}
}

if($final -eq 'PASS'){ exit 0 }
exit 1

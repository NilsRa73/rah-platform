param(
    [switch]$Interactive,
    [switch]$NoRepair
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$StateDir = "C:\RAH\AI-Fabric"
$StatusDir = "C:\RAH\Status"
$ReportDir = "C:\RAH\Reports\AI-Self-Check"
$BridgeBase = "http://127.0.0.1:18765"
$LmBase = "http://127.0.0.1:1234"
$ModelFile = Join-Path $StateDir "lmstudio-model.txt"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Txt = Join-Path $ReportDir "AI-SELF-CHECK-$Stamp.txt"
$Json = Join-Path $ReportDir "AI-SELF-CHECK-$Stamp.json"
$Latest = Join-Path $StatusDir "AI-SELF-CHECK-LATEST.txt"

$BridgeTask = "RAH Raven Bridge"
$ProviderTask = "RAH Raven AI Providers"
$WatchdogTask = "RAH Raven AI Fabric Watchdog"

function Say([string]$Text,[ConsoleColor]$Color=[ConsoleColor]::Gray) {
    if($Interactive){ Write-Host $Text -ForegroundColor $Color }
}

function Is-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Elevate-IfInteractive {
    if(-not$Interactive -or (Is-Admin)){ return }
    $quoted='"' + $PSCommandPath + '"'
    $p=Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @("-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File",$quoted,"-Interactive")
    exit $p.ExitCode
}

function Start-KnownTask([string]$Name) {
    if($NoRepair){ return }
    try {
        if(Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue){
            Start-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
            Say "Startet $Name" DarkGray
        }
    } catch {}
}

function Get-Json([string]$Url,[int]$Timeout=5) {
    try { return Invoke-RestMethod -Uri $Url -TimeoutSec $Timeout }
    catch { return $null }
}

function Post-Json([string]$Url,[object]$Body,[int]$Timeout=90) {
    try {
        $payload=$Body|ConvertTo-Json -Depth 12
        return Invoke-RestMethod -Method POST -Uri $Url -ContentType "application/json" -Body $payload -TimeoutSec $Timeout
    } catch { return $null }
}

function Wait-Json([string]$Url,[int]$Seconds=20) {
    $end=(Get-Date).AddSeconds($Seconds)
    do {
        $x=Get-Json $Url 4
        if($x){ return $x }
        Start-Sleep -Milliseconds 800
    } while((Get-Date)-lt$end)
    return $null
}

function Find-Lms {
    foreach($name in @("lms.exe","lms")){
        try {
            $c=Get-Command $name -ErrorAction SilentlyContinue
            if($c){ return $c.Source }
        } catch {}
    }
    foreach($p in @("$env:USERPROFILE\.lmstudio\bin\lms.exe","$env:LOCALAPPDATA\LM Studio\bin\lms.exe")){
        if(Test-Path -LiteralPath $p){ return $p }
    }
    return $null
}

function Test-LmInference([string]$Model) {
    if([string]::IsNullOrWhiteSpace($Model)){ return $false }
    try {
        $body=@{
            model=$Model
            messages=@(@{role="user";content="Svar kun med OK"})
            temperature=0.0
            max_tokens=8
            stream=$false
        }
        $payload=$body|ConvertTo-Json -Depth 8
        $r=Invoke-RestMethod -Method POST -Uri "$LmBase/v1/chat/completions" -ContentType "application/json" -Body $payload -TimeoutSec 60
        $text=[string]$r.choices[0].message.content
        return -not[string]::IsNullOrWhiteSpace($text)
    } catch { return $false }
}

function Try-LoadPinnedModel([string]$Model) {
    if($NoRepair -or [string]::IsNullOrWhiteSpace($Model)){ return $false }
    $lms=Find-Lms
    if(-not$lms){ return $false }
    try {
        & $lms server start | Out-Null
        & $lms load $Model --context-length 2048 | Out-Null
        Start-Sleep -Seconds 2
        return (Test-LmInference $Model)
    } catch { return $false }
}

Elevate-IfInteractive
New-Item -ItemType Directory -Force -Path $StatusDir,$ReportDir|Out-Null

$state=[ordered]@{
    schema="rah-raven-ai-self-check"
    version=2
    timestamp=(Get-Date).ToString("o")
    pc=$env:COMPUTERNAME
    bridge="UNKNOWN"
    ai_fabric_version=""
    jobs="UNKNOWN"
    lmstudio="UNKNOWN"
    lmstudio_model=""
    anythingllm="UNKNOWN"
    project_memory="UNKNOWN"
    project_memory_workspace=""
    approval_gate="UNKNOWN"
    approval_mode=""
    approval_local_only=$false
    council="UNKNOWN"
    ready_advisers=@()
    repairs=@()
    final="FAIL"
    smallest_fix=""
}

try {
    Say "RAH Raven AI Self-Check" Yellow

    $health=Get-Json "$BridgeBase/health" 4
    if(-not$health -or $health.ai_fabric-ne$true){
        Start-KnownTask $ProviderTask
        Start-KnownTask $BridgeTask
        Start-KnownTask $WatchdogTask
        $state.repairs += "wake-raven-stack"
        $health=Wait-Json "$BridgeBase/health" 25
    }

    if(-not$health -or $health.ai_fabric-ne$true){
        $state.bridge="FAIL"
        $state.smallest_fix="Kjor C:\RAH\START-HER.cmd for Raven runtime repair."
        throw $state.smallest_fix
    }

    $state.bridge="PASS"
    $state.ai_fabric_version=[string]$health.ai_fabric_version

    $jobs=Get-Json "$BridgeBase/agent/jobs/health" 5
    if($jobs -and $jobs.ready-eq$true -and $jobs.elevated-eq$true){
        $state.jobs="PASS"
    } else {
        Start-KnownTask $BridgeTask
        $state.repairs += "restart-bridge-for-job-executor"
        Start-Sleep -Seconds 2
        $jobs=Get-Json "$BridgeBase/agent/jobs/health" 5
        $state.jobs=if($jobs -and $jobs.ready-eq$true -and $jobs.elevated-eq$true){"PASS"}else{"FAIL"}
    }

    $memory=Get-Json "$BridgeBase/ai/memory/status" 5
    if(-not$memory){
        $state.project_memory="MISSING_ROUTE"
        $state.smallest_fix="Raven runtime mangler Project Memory. Kjor C:\RAH\START-HER.cmd."
        throw $state.smallest_fix
    }

    $state.project_memory_workspace=[string]$memory.workspace
    if($memory.ready-eq$true){
        $state.project_memory="READY"
    } elseif([string]$memory.detail -match "token.*not configured"){
        $state.project_memory="NEEDS_TOKEN"
    } elseif([string]$memory.detail -match "workspace not found"){
        $state.project_memory="WORKSPACE_MISSING"
    } else {
        $state.project_memory="NOT_READY"
    }

    $approval=Get-Json "$BridgeBase/agent/approval/status" 5
    if(-not$approval){
        $state.approval_gate="MISSING_ROUTE"
    } else {
        $state.approval_mode=[string]$approval.mode
        $state.approval_local_only=($approval.local_only-eq$true)
        $approvalSafe=(
            $approval.local_only-eq$true -and
            $approval.arbitrary_commands-eq$false -and
            $approval.file_writes-eq$false -and
            $approval.high_impact_approval-eq$false
        )
        if(-not$approvalSafe){
            $state.approval_gate="UNSAFE"
        } elseif($approval.configured-eq$true){
            $state.approval_gate="READY"
        } else {
            $state.approval_gate="NEEDS_CONFIG"
        }
    }

    $providers=Get-Json "$BridgeBase/ai/providers" 6
    if(-not$providers){
        Start-KnownTask $ProviderTask
        $state.repairs += "start-ai-providers"
        Start-Sleep -Seconds 3
        $providers=Get-Json "$BridgeBase/ai/providers" 6
    }
    if(-not$providers){ throw "AI provider status svarer ikke." }

    $lm=$null
    $anything=$null
    foreach($p in @($providers.providers)){
        if([string]$p.id-eq"lmstudio"){$lm=$p}
        if([string]$p.id-eq"anythingllm"){$anything=$p}
    }

    $pinned=""
    if(Test-Path -LiteralPath $ModelFile){
        try{$pinned=[IO.File]::ReadAllText($ModelFile).Trim()}catch{}
    }

    $lmModel=if($pinned){$pinned}elseif($lm){[string]$lm.model}else{""}
    $state.lmstudio_model=$lmModel

    $lmOk=$false
    if($lm -and $lm.ready-eq$true){ $lmOk=Test-LmInference $lmModel }
    if(-not$lmOk -and $lmModel){
        Start-KnownTask $ProviderTask
        $state.repairs += "wake-lmstudio"
        Start-Sleep -Seconds 2
        if(Try-LoadPinnedModel $lmModel){
            $lmOk=$true
            $state.repairs += "reload-pinned-lmstudio-model"
        }
    }
    $state.lmstudio=if($lmOk){"READY"}elseif($lm -and $lm.online){"ONLINE_BUT_INFERENCE_FAIL"}else{"OFFLINE"}

    if($anything -and $anything.ready-eq$true){
        $state.anythingllm="READY"
    } elseif($anything -and $anything.online){
        $state.anythingllm="NEEDS_AUTH"
    } else {
        Start-KnownTask $ProviderTask
        $state.repairs += "wake-anythingllm"
        Start-Sleep -Seconds 3
        $providers2=Get-Json "$BridgeBase/ai/providers" 6
        $anything2=$null
        if($providers2){
            foreach($p in @($providers2.providers)){if([string]$p.id-eq"anythingllm"){$anything2=$p}}
        }
        if($anything2 -and $anything2.ready-eq$true){$state.anythingllm="READY"}
        elseif($anything2 -and $anything2.online){$state.anythingllm="NEEDS_AUTH"}
        else{$state.anythingllm="OFFLINE"}
    }

    $providers=Get-Json "$BridgeBase/ai/providers" 6
    $ready=@()
    if($providers){
        foreach($p in @($providers.providers)){
            if($p.ready-eq$true -and [string]$p.id -in @("lmstudio","anythingllm","openai-compatible")){
                $ready += [string]$p.id
            }
        }
    }
    $state.ready_advisers=$ready

    $council=Post-Json "$BridgeBase/ai/council/run" @{
        message="RAH Raven self-check. Svar kort med systemstatus og ett trygt neste steg. Ikke utfor maskinhandlinger."
    } 150

    if($council -and $council.ok-eq$true){
        $good=@($council.replies|Where-Object{$_.ok-eq$true -and -not[string]::IsNullOrWhiteSpace([string]$_.text)})
        if($good.Count-ge2){$state.council="MULTI-AI PASS"}
        elseif($good.Count-eq1){$state.council="PARTIAL PASS"}
        else{$state.council="FAIL"}
    } else {
        $state.council="FAIL"
    }

    if($state.bridge-eq"PASS" -and $state.jobs-eq"PASS" -and $state.lmstudio-eq"READY" -and $state.project_memory-eq"READY" -and $state.council-eq"MULTI-AI PASS"){
        $state.final="PASS"
    } elseif($state.bridge-eq"PASS" -and $state.jobs-eq"PASS" -and $state.lmstudio-eq"READY"){
        $state.final="PARTIAL"
        if(-not$state.smallest_fix){
            if($state.project_memory-ne"READY"){
                $state.smallest_fix="Kjor C:\RAH\CONFIGURE-RAH-PROJECT-MEMORY.cmd for AnythingLLM token/workspace."
            } elseif($state.council-ne"MULTI-AI PASS"){
                $state.smallest_fix="Minst to AI-radgivere ma vaere READY for full Council PASS."
            }
        }
    } else {
        $state.final="FAIL"
        if(-not$state.smallest_fix){
            $state.smallest_fix="Kjor C:\RAH\START-HER.cmd og deretter C:\RAH\RAVEN-AI-SELF-CHECK.cmd."
        }
    }
}
catch {
    if(-not$state.smallest_fix){$state.smallest_fix=$_.Exception.Message}
}
finally {
    $state|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $Json -Encoding UTF8
    $lines=@(
        "RAH RAVEN AI SELF-CHECK",
        "=======================",
        "Timestamp        : $($state.timestamp)",
        "PC               : $($state.pc)",
        "FINAL            : $($state.final)",
        "Bridge           : $($state.bridge)",
        "AI Fabric        : $($state.ai_fabric_version)",
        "Job Executor     : $($state.jobs)",
        "LM Studio        : $($state.lmstudio)",
        "LM Model         : $($state.lmstudio_model)",
        "AnythingLLM      : $($state.anythingllm)",
        "Project Memory   : $($state.project_memory)",
        "Workspace        : $($state.project_memory_workspace)",
        "Approval Gate    : $($state.approval_gate)",
        "Approval Mode    : $($state.approval_mode)",
        "Approval Local   : $($state.approval_local_only)",
        "Ready advisers   : $($state.ready_advisers -join ', ')",
        "Council          : $($state.council)",
        "Repairs attempted: $($state.repairs -join ', ')",
        "Smallest fix     : $($state.smallest_fix)",
        "JSON             : $Json"
    )
    [IO.File]::WriteAllLines($Txt,[string[]]$lines,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllLines($Latest,[string[]]$lines,[Text.UTF8Encoding]::new($false))
    foreach($line in $lines){
        $color="Gray"
        if($line -match "^FINAL\s+: PASS"){$color="Green"}
        elseif($line -match "^FINAL\s+: (PARTIAL|FAIL)"){$color="Yellow"}
        Say $line $color
    }
}

if($state.final-eq"PASS"){exit 0}
elseif($state.final-eq"PARTIAL"){exit 2}
else{exit 1}

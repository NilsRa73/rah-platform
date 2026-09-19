param(
    [string]$RuntimeRoot = 'C:\RAH\AI-Fabric\rah-platform',
    [string]$SourceDirectory = '',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RahAiChatRecoveryVersion = '1.0.0'
$script:ExpectedFabricMarker = 'AI_FABRIC_VERSION = "1.2.0"'
$script:FabricRelativePath = 'desktop-bridge\raven_ai_fabric.py'
$script:LiveRelativePath = 'RAH-AGENT-TEAM-LIVE-TEST.ps1'
$script:FabricUrl = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/desktop-bridge/raven_ai_fabric.py'
$script:LiveUrl = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-AGENT-TEAM-LIVE-TEST.ps1'
$script:BridgeTask = 'RAH Raven Bridge'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

function Test-RahAdministrator {
    try {
        $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
        $principal=New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-RahPython {
    $venv = 'C:\RAH\AI-Fabric\venv\Scripts\python.exe'
    if(Test-Path -LiteralPath $venv -PathType Leaf){ return $venv }
    $py=Get-Command py.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if($py){
        $exe=(& $py.Source -3 -c "import sys; print(sys.executable)" 2>$null | Select-Object -First 1)
        if($LASTEXITCODE -eq 0 -and $exe -and (Test-Path -LiteralPath $exe -PathType Leaf)){ return [string]$exe }
    }
    $python=Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if($python){ return [string]$python.Source }
    throw 'Python 3 ble ikke funnet.'
}

function Get-RahSourceFile {
    param([string]$RelativePath,[string]$Url,[string]$Destination)
    if($SourceDirectory){
        $src=Join-Path $SourceDirectory $RelativePath
        if(-not(Test-Path -LiteralPath $src -PathType Leaf)){ throw "Source mangler: $src" }
        Copy-Item -LiteralPath $src -Destination $Destination -Force
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination -TimeoutSec 60
    }
    $item=Get-Item -LiteralPath $Destination
    if($item.Length -le 0 -or $item.Length -gt 4194304){ throw "Ugyldig source-storrelse: $RelativePath" }
}

function Assert-RahPowerShellParse {
    param([string]$Path)
    $tokens=$null
    $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)|Out-Null
    if(@($errors).Count){ throw "PowerShell parse feilet: $($errors[0].Message)" }
}

function Wait-RahFabric {
    param([int]$Seconds=35)
    $end=(Get-Date).AddSeconds($Seconds)
    do{
        try{
            $h=Invoke-RestMethod -Uri 'http://127.0.0.1:18765/health' -TimeoutSec 4 -ErrorAction Stop
            if($h.ai_fabric -eq $true -and [string]$h.ai_fabric_version -eq '1.2.0'){ return $h }
        }catch{}
        Start-Sleep -Milliseconds 700
    }while((Get-Date)-lt$end)
    return $null
}

function Write-RahRecoveryReport {
    param([string]$Status,[string]$Message,[string]$Backup,[int]$LiveExit)
    $root='C:\RAH\AI-Fabric\Recovery'
    try{
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $doc=[pscustomobject]@{
            schema='rah-ai-chat-recovery'
            version=1
            recoveryVersion=$script:RahAiChatRecoveryVersion
            createdAt=(Get-Date).ToUniversalTime().ToString('o')
            computerName=$env:COMPUTERNAME
            status=$Status
            message=$Message
            backup=$Backup
            liveExit=$LiveExit
            fabricVersion='1.2.0'
            tokenCollected=$false
            arbitraryCommands=$false
        }
        [IO.File]::WriteAllText((Join-Path $root 'rah-ai-chat-recovery-latest.json'),($doc|ConvertTo-Json -Depth 6),$script:Utf8)
        $lines=@(
            'RAH AI CHAT RECOVERY',
            ('STATUS: '+$Status),
            ('MESSAGE: '+$Message),
            ('BACKUP: '+$Backup),
            ('LIVE EXIT: '+$LiveExit),
            'TOKEN DUMP: False',
            'SHELL/EXEC: False'
        )
        [IO.File]::WriteAllLines((Join-Path $root 'RAH-AI-CHAT-RECOVERY.txt'),$lines,$script:Utf8)
    }catch{}
}

function Invoke-RahSelfTest {
    $tmp=Join-Path $env:TEMP ('RAH-AI-Chat-Recovery-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try{
        $fabric=Join-Path $tmp 'raven_ai_fabric.py'
        $live=Join-Path $tmp 'RAH-AGENT-TEAM-LIVE-TEST.ps1'
        Get-RahSourceFile $script:FabricRelativePath $script:FabricUrl $fabric
        Get-RahSourceFile $script:LiveRelativePath $script:LiveUrl $live
        $raw=Get-Content -LiteralPath $fabric -Raw
        if(-not $raw.Contains($script:ExpectedFabricMarker)){ throw 'AI Fabric v1.2 marker mangler.' }
        foreach($required in @('_lm_model_candidates','LM_FAILURE_QUARANTINE_SECONDS','Ingen AI-provider fullførte forespørselen')){
            if(-not $raw.Contains($required)){ throw "Recovery contract mangler: $required" }
        }
        Assert-RahPowerShellParse $live
        $python=Get-RahPython
        & $python -m py_compile $fabric
        if($LASTEXITCODE -ne 0){ throw 'AI Fabric py_compile feilet.' }
        Write-Host 'PASS: RAH AI Chat Recovery v1 self-test' -ForegroundColor Green
    }
    finally{
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if($SelfTest){
    Invoke-RahSelfTest
    exit 0
}

if(-not(Test-RahAdministrator)){ throw 'Administrator kreves for AI Chat Recovery.' }

$target=Join-Path $RuntimeRoot $script:FabricRelativePath
if(-not(Test-Path -LiteralPath $target -PathType Leaf)){
    throw "Eksisterende AI Fabric runtime mangler: $target. Kjor full AI Fabric Repair."
}

$python=Get-RahPython
$stage=Join-Path $env:TEMP ('RAH-AI-Chat-Recovery-'+[guid]::NewGuid().ToString('N'))
$backupRoot='C:\RAH\AI-Fabric\Backup'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$backup=Join-Path $backupRoot ("raven_ai_fabric-before-chat-recovery-$stamp.py")
$liveExit=999

New-Item -ItemType Directory -Path $stage,$backupRoot -Force | Out-Null
try{
    $candidate=Join-Path $stage 'raven_ai_fabric.py'
    $live=Join-Path $stage 'RAH-AGENT-TEAM-LIVE-TEST.ps1'

    Write-Host '[1/5] Henter og validerer AI Fabric v1.2 ...' -ForegroundColor Cyan
    Get-RahSourceFile $script:FabricRelativePath $script:FabricUrl $candidate
    $raw=Get-Content -LiteralPath $candidate -Raw
    if(-not $raw.Contains($script:ExpectedFabricMarker)){ throw 'Nedlastet AI Fabric er ikke v1.2.0.' }
    & $python -m py_compile $candidate
    if($LASTEXITCODE -ne 0){ throw 'Ny AI Fabric runtime besto ikke py_compile.' }

    Write-Host '[2/5] Tar backup og installerer runtime atomisk ...' -ForegroundColor Cyan
    Copy-Item -LiteralPath $target -Destination $backup -Force
    Copy-Item -LiteralPath $candidate -Destination ($target+'.new') -Force
    Move-Item -LiteralPath ($target+'.new') -Destination $target -Force

    Write-Host '[3/5] Restarter Raven Bridge ...' -ForegroundColor Cyan
    $null=Get-ScheduledTask -TaskName $script:BridgeTask -ErrorAction Stop
    Stop-ScheduledTask -TaskName $script:BridgeTask -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 700
    Start-ScheduledTask -TaskName $script:BridgeTask -ErrorAction Stop
    $health=Wait-RahFabric 40
    if(-not $health){
        Write-Warning 'Ny runtime ble ikke healthy. Ruller tilbake backup.'
        Copy-Item -LiteralPath $backup -Destination $target -Force
        Stop-ScheduledTask -TaskName $script:BridgeTask -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        Start-ScheduledTask -TaskName $script:BridgeTask -ErrorAction SilentlyContinue
        throw 'AI Fabric v1.2 ble ikke healthy etter restart; gammel runtime er gjenopprettet.'
    }

    Write-Host '[4/5] Henter LIVE TEST ...' -ForegroundColor Cyan
    Get-RahSourceFile $script:LiveRelativePath $script:LiveUrl $live
    Assert-RahPowerShellParse $live

    Write-Host '[5/5] Kjorer ekte Agent Team LIVE TEST pa nytt ...' -ForegroundColor Cyan
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $live -BridgeRoot 'C:\RAH\AgentBridge' -WorkerRoot 'C:\RAH\AgentWorker' -BusRoot 'C:\RAH\AgentBus'
    $liveExit=$LASTEXITCODE

    if($liveExit -eq 0){
        Write-RahRecoveryReport 'PASS' 'AI Fabric v1.2 installert og LIVE TEST fullforte.' $backup $liveExit
        Write-Host ''
        Write-Host 'RAH AI CHAT RECOVERY: FULL PASS' -ForegroundColor Green
        Write-Host 'LIVE rapport: C:\RAH\AgentWorker\reports\RAH-AGENT-TEAM-LIVE.txt'
        exit 0
    }

    Write-RahRecoveryReport 'PATCH_PASS_LIVE_FAIL' 'AI Fabric v1.2 er healthy, men LIVE TEST feilet. Se LIVE-rapport for minste fix.' $backup $liveExit
    Write-Host ''
    Write-Host 'RAH AI CHAT RECOVERY: PATCH PASS / LIVE FAIL' -ForegroundColor Yellow
    Write-Host 'Se: C:\RAH\AgentWorker\reports\RAH-AGENT-TEAM-LIVE.txt'
    exit $liveExit
}
catch{
    Write-RahRecoveryReport 'FAIL' $_.Exception.Message $backup $liveExit
    throw
}
finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}

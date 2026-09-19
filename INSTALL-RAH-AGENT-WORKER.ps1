param(
    [string]$InstallRoot = 'C:\RAH\AgentWorker',
    [string]$BridgeRoot = 'C:\RAH\AgentBridge',
    [string]$SourceDirectory = '',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RahAgentWorkerInstallerVersion = '1.0.0'
$script:TaskName = 'RAH Agent Worker'
$script:WorkerFile = 'rah_agent_worker.py'
$script:RawBase = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

function Get-RahPython {
    $py = Get-Command py.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($py) {
        $exe = (& $py.Source -3 -c "import sys; print(sys.executable)" 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $exe -and (Test-Path -LiteralPath $exe -PathType Leaf)) {
            return [IO.Path]::GetFullPath([string]$exe)
        }
    }
    $python = Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($python) { return [IO.Path]::GetFullPath($python.Source) }
    throw 'Python 3 was not found.'
}

function Get-RahSource {
    param([string]$Name,[string]$Destination)
    if ($SourceDirectory) {
        $src = Join-Path $SourceDirectory $Name
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "Source missing: $src" }
        Copy-Item -LiteralPath $src -Destination $Destination -Force
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri "$script:RawBase/$Name" -OutFile $Destination
    }
    $item = Get-Item -LiteralPath $Destination
    if ($item.Length -le 0 -or $item.Length -gt 4194304) { throw "Invalid source size: $Name" }
}

function Get-RahJson {
    param([string]$Url,[int]$Timeout=4)
    try { return Invoke-RestMethod -Uri $Url -TimeoutSec $Timeout -ErrorAction Stop } catch { return $null }
}

function Write-RahDiagnostics {
    param([string]$Message)
    try {
        $support = Join-Path $InstallRoot 'support'
        New-Item -ItemType Directory -Path $support -Force | Out-Null
        $task = $null
        try {
            $t = Get-ScheduledTask -TaskName $script:TaskName -ErrorAction Stop
            $task = [pscustomobject]@{present=$true;state=[string]$t.State;taskPath=[string]$t.TaskPath}
        } catch { $task = [pscustomobject]@{present=$false} }
        $bridge = Get-RahJson 'http://127.0.0.1:18781/health'
        $fabric = Get-RahJson 'http://127.0.0.1:18765/health'
        $providers = Get-RahJson 'http://127.0.0.1:18765/ai/providers' 6
        $statePath = Join-Path $InstallRoot 'worker-state.json'
        $state = $null
        if (Test-Path -LiteralPath $statePath -PathType Leaf) {
            try { $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json } catch {}
        }
        $doc=[pscustomobject]@{
            schema='rah-agent-worker-diagnostics'
            version=1
            createdAt=(Get-Date).ToUniversalTime().ToString('o')
            message=$Message
            computerName=$env:COMPUTERNAME
            task=$task
            bridge=$bridge
            fabric=$fabric
            providers=$providers
            workerState=$state
            bridgeTokenCollected=$false
        }
        [IO.File]::WriteAllText((Join-Path $support 'agent-worker-last-diagnostics.json'),($doc | ConvertTo-Json -Depth 10),$script:Utf8)
        [IO.File]::WriteAllText((Join-Path $support 'agent-worker-last-diagnostics.txt'),("RAH Agent Worker diagnostics`r`n$Message`r`nBridge token collected: False`r`n"),$script:Utf8)
    } catch {}
}

trap {
    $failure=$_
    Write-RahDiagnostics ([string]$failure.Exception.Message)
    Write-Error $failure
    exit 1
}

function Invoke-RahSelfTest {
    param([string]$Python)
    $tmp = Join-Path $env:TEMP ('RAH-AgentWorker-SelfTest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $dst = Join-Path $tmp $script:WorkerFile
        Get-RahSource $script:WorkerFile $dst
        $text = Get-Content -LiteralPath $dst -Raw
        foreach($marker in @('VERSION = "1.0.0"','DEFAULT_BRIDGE = "http://127.0.0.1:18781"','DEFAULT_FABRIC = "http://127.0.0.1:18765"','execCapability')) {
            if(-not $text.Contains($marker)){ throw "Worker marker missing: $marker" }
        }
        foreach($forbidden in @('import subprocess','subprocess.','os.system','eval(','exec(')) {
            if($text.Contains($forbidden)){ throw "Forbidden Worker capability found: $forbidden" }
        }
        & $Python -m py_compile $dst
        if($LASTEXITCODE -ne 0){ throw 'Worker py_compile failed.' }
        & $Python $dst --self-test
        if($LASTEXITCODE -ne 0){ throw 'Worker self-test failed.' }
        Write-Host 'PASS: RAH Agent Worker installer v1 self-test' -ForegroundColor Green
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$python=Get-RahPython
if($SelfTest){
    Invoke-RahSelfTest $python
    exit 0
}

$root=[IO.Path]::GetFullPath($InstallRoot)
$bridgeRootFull=[IO.Path]::GetFullPath($BridgeRoot)
$tokenFile=Join-Path $bridgeRootFull 'token.txt'
if(-not (Test-Path -LiteralPath $tokenFile -PathType Leaf)){
    throw "RAH Agent Bridge token mangler. Kjor Agent Bridge-installasjonen forst: $tokenFile"
}

New-Item -ItemType Directory -Path $root,(Join-Path $root 'logs') -Force | Out-Null
$worker=Join-Path $root $script:WorkerFile
Get-RahSource $script:WorkerFile $worker
& $python -m py_compile $worker
if($LASTEXITCODE -ne 0){ throw 'Worker py_compile failed.' }
& $python $worker --self-test
if($LASTEXITCODE -ne 0){ throw 'Worker self-test failed.' }

$bridge=Get-RahJson 'http://127.0.0.1:18781/health'
if(-not $bridge -or -not $bridge.ok){
    try { Start-ScheduledTask -TaskName 'RAH Agent Bridge' -ErrorAction SilentlyContinue } catch {}
    for($i=0;$i -lt 20;$i++){
        Start-Sleep -Milliseconds 500
        $bridge=Get-RahJson 'http://127.0.0.1:18781/health'
        if($bridge -and $bridge.ok){ break }
    }
}
if(-not $bridge -or -not $bridge.ok){ throw 'RAH Agent Bridge is not healthy on 127.0.0.1:18781.' }

$runner=Join-Path $root 'START-RAH-AGENT-WORKER.cmd'
$state=Join-Path $root 'worker-state.json'
$logs=Join-Path $root 'logs'
$runnerText=@"
@echo off
setlocal
set "PYTHON_BASIC_REPL=1"
if not exist "$logs" mkdir "$logs" >nul 2>&1
"$python" "$worker" --bridge http://127.0.0.1:18781 --fabric http://127.0.0.1:18765 --token-file "$tokenFile" --state-file "$state" 1>>"$logs\worker.log" 2>>"$logs\worker.err.log"
exit /b %ERRORLEVEL%
"@
[IO.File]::WriteAllText($runner,$runnerText,$script:Utf8)

try { Stop-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue } catch {}
try { Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}

$user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
$action=New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/d /c ""{0}""' -f $runner) -WorkingDirectory $root
$trigger=New-ScheduledTaskTrigger -AtLogOn -User $user
$principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Seconds 0)
Register-ScheduledTask -TaskName $script:TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'RAH Agent Worker v1 - local AgentBus to AI Fabric router, no shell capability' -Force | Out-Null
Start-ScheduledTask -TaskName $script:TaskName

$workerState=$null
for($i=0;$i -lt 30;$i++){
    Start-Sleep -Milliseconds 300
    if(Test-Path -LiteralPath $state -PathType Leaf){
        try{
            $workerState=Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
            if([string]$workerState.version -eq '1.0.0'){ break }
        }catch{}
    }
}
if(-not $workerState -or [string]$workerState.version -ne '1.0.0'){ throw 'Agent Worker did not create a valid state file.' }
if($workerState.execCapability -ne $false){ throw 'Agent Worker safety contract failed: execCapability must be false.' }

$fabric=Get-RahJson 'http://127.0.0.1:18765/health'
$providers=Get-RahJson 'http://127.0.0.1:18765/ai/providers' 6
$providerSummary=@()
if($providers -and $providers.providers){
    foreach($p in @($providers.providers)){
        $providerSummary += "$($p.id): online=$($p.online) ready=$($p.ready)"
    }
}

$report=[pscustomobject]@{
    schema='rah-agent-worker-install-state'
    version=1
    installedAt=(Get-Date).ToUniversalTime().ToString('o')
    installRoot=$root
    taskName=$script:TaskName
    runLevel='Limited'
    bridgeHealthy=[bool]($bridge -and $bridge.ok)
    fabricHealthy=[bool]($fabric -and $fabric.ok)
    providers=@($providerSummary)
    execCapability=$false
    tokenCollectedInReports=$false
}
[IO.File]::WriteAllText((Join-Path $root 'install-state.json'),($report | ConvertTo-Json -Depth 6),$script:Utf8)

$desktop=[Environment]::GetFolderPath('Desktop')
if($desktop){
    $statusCmd=@"
@echo off
title RAH Agent Team Status
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "`$ErrorActionPreference='SilentlyContinue'; Write-Host '=== Agent Bridge ===' -ForegroundColor Yellow; Invoke-RestMethod 'http://127.0.0.1:18781/health' -TimeoutSec 4 ^| ConvertTo-Json -Depth 6; Write-Host '=== AI Fabric Providers ===' -ForegroundColor Yellow; Invoke-RestMethod 'http://127.0.0.1:18765/ai/providers' -TimeoutSec 6 ^| ConvertTo-Json -Depth 8; Write-Host '=== Worker State ===' -ForegroundColor Yellow; Get-Content '$state' -Raw"
pause
"@
    [IO.File]::WriteAllText((Join-Path $desktop 'RAH Agent Team Status.cmd'),$statusCmd,$script:Utf8)
}

Write-RahDiagnostics 'installation-pass'
Write-Host '=============================================================' -ForegroundColor Yellow
Write-Host 'RAH AGENT WORKER v1: PASS' -ForegroundColor Green
Write-Host "$script:TaskName : Limited / non-admin"
Write-Host 'Bridge    : http://127.0.0.1:18781'
Write-Host 'AI Fabric : http://127.0.0.1:18765'
Write-Host "State     : $state"
if($providerSummary.Count){ $providerSummary | ForEach-Object { Write-Host ("Provider  : " + $_) -ForegroundColor Cyan } }
else { Write-Host 'Provider  : AI Fabric not ready yet; worker stays idle/retrying.' -ForegroundColor DarkYellow }
Write-Host 'Shell/exec: DISABLED by design' -ForegroundColor Cyan
Write-Host '=============================================================' -ForegroundColor Yellow
exit 0
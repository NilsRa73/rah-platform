param(
    [string]$InstallRoot = 'C:\RAH\AgentBridge',
    [string]$BusRoot = 'C:\RAH\AgentBus',
    [string]$SourceDirectory = '',
    [int]$Port = 18781,
    [string]$DesktopPath = '',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahAgentBridgeInstallerVersion = '1.1.0'
$script:RahAgentBridgeTaskName = 'RAH Agent Bridge'
$script:RahAgentWorkerTaskName = 'RAH Agent Worker'
$script:RahAgentBridgeServer = 'rah_agent_bridge.py'
$script:RahAgentBridgeClient = 'RAH-AGENT-BUS.ps1'
$script:RahAgentBridgeWorker = 'rah_agent_worker.py'
$script:RahRawBase = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main'

$script:RahDiagnosticRoot = if ($SelfTest) { Join-Path $env:TEMP 'RAH-AgentBridge-SelfTest-Diagnostics' } else { [IO.Path]::GetFullPath($InstallRoot) }

trap {
    $failure = $_
    try {
        $support = Join-Path $script:RahDiagnosticRoot 'support'
        New-Item -ItemType Directory -Path $support -Force | Out-Null
        $taskInfo = $null
        try {
            $task = Get-ScheduledTask -TaskName $script:RahAgentBridgeTaskName -ErrorAction Stop
            $taskInfo = [pscustomobject]@{present=$true;state=[string]$task.State;taskPath=[string]$task.TaskPath}
        } catch { $taskInfo = [pscustomobject]@{present=$false} }
        $listeners = @()
        try {
            foreach($n in @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)){
                $listeners += [pscustomobject]@{address=[string]$n.LocalAddress;port=[int]$n.LocalPort;pid=[int]$n.OwningProcess}
            }
        } catch {}
        $logTail = @()
        foreach($name in @('bridge.log','bridge.err.log','worker.log','worker.err.log')){
            $p = Join-Path (Join-Path $script:RahDiagnosticRoot 'logs') $name
            if(Test-Path -LiteralPath $p -PathType Leaf){
                $logTail += [pscustomobject]@{name=$name;tail=@(Get-Content -LiteralPath $p -Tail 40 -ErrorAction SilentlyContinue)}
            }
        }
        $doc=[pscustomobject]@{
            schema='rah-agent-bridge-failure'
            version=1
            createdAt=(Get-Date).ToUniversalTime().ToString('o')
            message=[string]$failure.Exception.Message
            scriptStack=[string]$failure.ScriptStackTrace
            computerName=$env:COMPUTERNAME
            installRoot=$InstallRoot
            busRoot=$BusRoot
            port=$Port
            administrator=[bool](Test-RahAdministrator)
            task=$taskInfo
            workerTask=$(try {
                $wt = Get-ScheduledTask -TaskName $script:RahAgentWorkerTaskName -ErrorAction Stop
                [pscustomobject]@{present=$true;state=[string]$wt.State;taskPath=[string]$wt.TaskPath}
            } catch { [pscustomobject]@{present=$false} })
            listeners=@($listeners)
            logs=@($logTail)
            tokenCollected=$false
        }
        [IO.File]::WriteAllText((Join-Path $support 'agent-bridge-last-failure.json'),($doc | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path $support 'agent-bridge-last-failure.txt'),("RAH Agent Bridge FAIL" + [Environment]::NewLine + $doc.message + [Environment]::NewLine + "Token collected: False" + [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
        Write-Host ("RAH Agent Bridge diagnostics: " + $support) -ForegroundColor Yellow
    } catch {}
    Write-Error $failure
    exit 1
}

function Test-RahAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

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

function Assert-RahPowerShellParse {
    param([string]$Path)
    $tokens=$null
    $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count) { throw "PowerShell parse failed for $Path : $($errors[0].Message)" }
}

function Get-RahSource {
    param([string]$Name,[string]$Destination)
    if ($SourceDirectory) {
        $src = Join-Path $SourceDirectory $Name
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "Source file missing: $src" }
        Copy-Item -LiteralPath $src -Destination $Destination -Force
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri "$script:RahRawBase/$Name" -OutFile $Destination
    }
    $item = Get-Item -LiteralPath $Destination
    if ($item.Length -le 0 -or $item.Length -gt 4194304) { throw "Invalid source size: $Name" }
}

function New-RahToken {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existing=(Get-Content -LiteralPath $Path -Raw).Trim()
        if ($existing.Length -ge 24) { return $existing }
    }
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $token = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
    [IO.File]::WriteAllText($Path,$token + [Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
    try {
        $acl = New-Object Security.AccessControl.FileSecurity
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object Security.AccessControl.FileSystemAccessRule($identity,'FullControl','Allow')
        $acl.SetOwner([Security.Principal.NTAccount]$identity)
        $acl.SetAccessRuleProtection($true,$false)
        $acl.AddAccessRule($rule)
        Set-Acl -LiteralPath $Path -AclObject $acl
    } catch {
        Write-Warning ("Token ACL hardening warning: " + $_.Exception.Message)
    }
    return $token
}

function Write-RahLauncher {
    param(
        [string]$Path,
        [string]$Python,
        [string]$ServerPath,
        [string]$Root,
        [string]$Bus,
        [int]$ListenPort
    )
    $logs = Join-Path $Root 'logs'
    $text = @"
@echo off
setlocal
set "PYTHON_BASIC_REPL=1"
if not exist "$logs" mkdir "$logs" >nul 2>&1
"$Python" "$ServerPath" --root "$Root" --bus-root "$Bus" --host 127.0.0.1 --port $ListenPort 1>>"$logs\bridge.log" 2>>"$logs\bridge.err.log"
exit /b %ERRORLEVEL%
"@
    [IO.File]::WriteAllText($Path,$text,(New-Object Text.UTF8Encoding($false)))
}


function Write-RahWorkerLauncher {
    param(
        [string]$Path,
        [string]$Python,
        [string]$WorkerPath,
        [string]$Root,
        [int]$BridgePort
    )
    $logs = Join-Path $Root 'logs'
    $workerRoot = 'C:\RAH\AgentWorker'
    New-Item -ItemType Directory -Path $workerRoot -Force | Out-Null
    $tokenPath = Join-Path $Root 'token.txt'
    $statePath = Join-Path $workerRoot 'worker-state.json'
    $text = @"
@echo off
setlocal
set "PYTHON_BASIC_REPL=1"
if not exist "$logs" mkdir "$logs" >nul 2>&1
if not exist "$workerRoot" mkdir "$workerRoot" >nul 2>&1
"$Python" "$WorkerPath" --bridge "http://127.0.0.1:$BridgePort" --fabric "http://127.0.0.1:18765" --token-file "$tokenPath" --state-file "$statePath" 1>>"$logs\worker.log" 2>>"$logs\worker.err.log"
exit /b %ERRORLEVEL%
"@
    [IO.File]::WriteAllText($Path,$text,(New-Object Text.UTF8Encoding($false)))
}

function Write-RahDesktopTools {
    param([string]$Desktop,[string]$Root,[string]$Bus)
    if (-not $Desktop) { return }
    New-Item -ItemType Directory -Path $Desktop -Force | Out-Null
    $statusTemplate = @'
@echo off
title RAH Agent Bridge Status
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod 'http://127.0.0.1:__PORT__/health' -TimeoutSec 5 | ConvertTo-Json -Depth 8 } catch { Write-Host ('FAIL: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"
pause
'@
    $status = $statusTemplate.Replace('__PORT__',[string]$Port)
    [IO.File]::WriteAllText((Join-Path $Desktop 'RAH Agent Bridge Status.cmd'),$status,(New-Object Text.UTF8Encoding($false)))
    $open = '@echo off' + [Environment]::NewLine + 'start "" explorer.exe "' + $Bus + '"' + [Environment]::NewLine
    [IO.File]::WriteAllText((Join-Path $Desktop 'RAH AgentBus Open.cmd'),$open,(New-Object Text.UTF8Encoding($false)))
}

function Invoke-RahAgentBridgeSelfTest {
    param([string]$Python)
    $tmp = Join-Path $env:TEMP ('RAH-AgentBridge-SelfTest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $server = Join-Path $tmp $script:RahAgentBridgeServer
        $client = Join-Path $tmp $script:RahAgentBridgeClient
        $worker = Join-Path $tmp $script:RahAgentBridgeWorker
        Get-RahSource $script:RahAgentBridgeServer $server
        Get-RahSource $script:RahAgentBridgeClient $client
        Get-RahSource $script:RahAgentBridgeWorker $worker
        Assert-RahPowerShellParse $client
        $pyText = Get-Content -LiteralPath $server -Raw
        if ($pyText -notmatch 'VERSION\s*=\s*"1\.0\.0"' -or $pyText -match '(?im)^\s*(?:os\.)?system\s*\(' -or $pyText -match '\bsubprocess\b') {
            throw 'Agent Bridge source contract failed.'
        }
        $clientText = Get-Content -LiteralPath $client -Raw
        if ($clientText -notmatch "RahAgentBusClientVersion = '1\.0\.0'") { throw 'Agent Bus client marker missing.' }
        & $Python -m py_compile $server $worker
        if ($LASTEXITCODE -ne 0) { throw 'Agent Bridge/Worker py_compile failed.' }
        & $Python $server --self-test
        if ($LASTEXITCODE -ne 0) { throw 'Agent Bridge Python self-test failed.' }
        & $Python $worker --self-test
        if ($LASTEXITCODE -ne 0) { throw 'Agent Worker Python self-test failed.' }
        powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $client -SelfTest
        if ($LASTEXITCODE -ne 0) { throw 'Agent Bus PowerShell self-test failed.' }
        Write-Host 'PASS: RAH Agent Bridge installer v1 self-test' -ForegroundColor Green
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$python = Get-RahPython
if ($SelfTest) {
    Invoke-RahAgentBridgeSelfTest $python
    exit 0
}
if (-not (Test-RahAdministrator)) { throw 'Administrator is required for RAH Agent Bridge installation.' }
if ($Port -lt 1024 -or $Port -gt 65535) { throw 'Port must be between 1024 and 65535.' }

$root = [IO.Path]::GetFullPath($InstallRoot)
$bus = [IO.Path]::GetFullPath($BusRoot)
if (-not $DesktopPath) { $DesktopPath = [Environment]::GetFolderPath('Desktop') }
New-Item -ItemType Directory -Path $root,$bus,(Join-Path $root 'logs') -Force | Out-Null
foreach ($dir in @('inbox','working','results','failed','archive','logs')) {
    New-Item -ItemType Directory -Path (Join-Path $bus $dir) -Force | Out-Null
}

$serverPath = Join-Path $root $script:RahAgentBridgeServer
$clientPath = Join-Path $root $script:RahAgentBridgeClient
$workerPath = Join-Path $root $script:RahAgentBridgeWorker
Get-RahSource $script:RahAgentBridgeServer $serverPath
Get-RahSource $script:RahAgentBridgeClient $clientPath
Get-RahSource $script:RahAgentBridgeWorker $workerPath
Assert-RahPowerShellParse $clientPath
& $python -m py_compile $serverPath $workerPath
if ($LASTEXITCODE -ne 0) { throw 'Agent Bridge/Worker py_compile failed.' }
& $python $serverPath --self-test
if ($LASTEXITCODE -ne 0) { throw 'Agent Bridge Python self-test failed.' }
& $python $workerPath --self-test
if ($LASTEXITCODE -ne 0) { throw 'Agent Worker Python self-test failed.' }
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $clientPath -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Agent Bus PowerShell self-test failed.' }

$tokenPath = Join-Path $root 'token.txt'
$null = New-RahToken $tokenPath
$launcherPath = Join-Path $root 'START-RAH-AGENT-BRIDGE.cmd'
$workerLauncherPath = Join-Path $root 'START-RAH-AGENT-WORKER.cmd'
Write-RahLauncher -Path $launcherPath -Python $python -ServerPath $serverPath -Root $root -Bus $bus -ListenPort $Port
Write-RahWorkerLauncher -Path $workerLauncherPath -Python $python -WorkerPath $workerPath -Root $root -BridgePort $Port

foreach ($taskName in @($script:RahAgentBridgeTaskName,$script:RahAgentWorkerTaskName)) {
    try { Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue } catch {}
    try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
}

$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/d /c ""{0}""' -f $launcherPath) -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -AtLogOn
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 9 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $script:RahAgentBridgeTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'RAH Agent Bridge v1 localhost structured job bus' -Force | Out-Null

$workerAction = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/d /c ""{0}""' -f $workerLauncherPath) -WorkingDirectory $root
$workerPrincipal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $script:RahAgentWorkerTaskName -Action $workerAction -Trigger $trigger -Principal $workerPrincipal -Settings $settings -Description 'RAH Agent Worker v1: AgentBus to Raven AI Fabric localhost router' -Force | Out-Null

Start-ScheduledTask -TaskName $script:RahAgentBridgeTaskName

$health = $null
for ($i=0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2
        if ($health.ok) { break }
    } catch {}
}
if (-not $health -or -not $health.ok) { throw 'RAH Agent Bridge health check failed.' }
if ([string]$health.version -ne '1.0.0' -or [string]$health.bind -ne '127.0.0.1' -or $health.execCapability -ne $false) {
    throw 'RAH Agent Bridge health contract mismatch.'
}

if (-not (Test-Path -LiteralPath 'C:\RAH\AI-Fabric\STATUS.json' -PathType Leaf)) {
    Write-Warning 'RAH AI Fabric status file not found yet. Worker will wait/retry until Raven AI Fabric is available.'
}
Start-ScheduledTask -TaskName $script:RahAgentWorkerTaskName
$workerStatePath = 'C:\RAH\AgentWorker\worker-state.json'
$workerState = $null
for ($i=0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Path -LiteralPath $workerStatePath -PathType Leaf) {
        try {
            $workerState = Get-Content -LiteralPath $workerStatePath -Raw | ConvertFrom-Json
            if ([string]$workerState.version -eq '1.0.0' -and $workerState.execCapability -eq $false) { break }
        } catch {}
    }
}
if (-not $workerState -or [string]$workerState.version -ne '1.0.0' -or $workerState.execCapability -ne $false) {
    throw 'RAH Agent Worker state/health verification failed.'
}

$state = [pscustomobject]@{
    schema='rah-agent-bridge-install-state'
    version=1
    installedAt=(Get-Date).ToUniversalTime().ToString('o')
    installRoot=$root
    busRoot=$bus
    bind='127.0.0.1'
    port=$Port
    taskName=$script:RahAgentBridgeTaskName
    workerTaskName=$script:RahAgentWorkerTaskName
    workerState='C:\RAH\AgentWorker\worker-state.json'
    python=$python
    execCapability=$false
}
[IO.File]::WriteAllText((Join-Path $root 'install-state.json'),($state | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
Write-RahDesktopTools -Desktop $DesktopPath -Root $root -Bus $bus

Write-Host '=============================================================' -ForegroundColor Yellow
Write-Host 'RAH AGENT BRIDGE v1: PASS' -ForegroundColor Green
Write-Host "Health : http://127.0.0.1:$Port/health"
Write-Host "Bus    : $bus"
Write-Host "Client : $clientPath"
Write-Host "Bridge Task : $script:RahAgentBridgeTaskName"
Write-Host "Worker Task : $script:RahAgentWorkerTaskName (Limited token)"
Write-Host "Worker State: C:\RAH\AgentWorker\worker-state.json"
Write-Host 'Exec        : disabled by design in AgentBus/Worker' -ForegroundColor Cyan
Write-Host '=============================================================' -ForegroundColor Yellow
exit 0

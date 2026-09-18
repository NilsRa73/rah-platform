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

$script:RahAgentBridgeInstallerVersion = '1.0.0'
$script:RahAgentBridgeTaskName = 'RAH Agent Bridge'
$script:RahAgentBridgeServer = 'rah_agent_bridge.py'
$script:RahAgentBridgeClient = 'RAH-AGENT-BUS.ps1'
$script:RahRawBase = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main'

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
        Get-RahSource $script:RahAgentBridgeServer $server
        Get-RahSource $script:RahAgentBridgeClient $client
        Assert-RahPowerShellParse $client
        $pyText = Get-Content -LiteralPath $server -Raw
        if ($pyText -notmatch 'VERSION\s*=\s*"1\.0\.0"' -or $pyText -match '(?im)^\s*(?:os\.)?system\s*\(' -or $pyText -match '\bsubprocess\b') {
            throw 'Agent Bridge source contract failed.'
        }
        $clientText = Get-Content -LiteralPath $client -Raw
        if ($clientText -notmatch "RahAgentBusClientVersion = '1\.0\.0'") { throw 'Agent Bus client marker missing.' }
        & $Python -m py_compile $server
        if ($LASTEXITCODE -ne 0) { throw 'Agent Bridge py_compile failed.' }
        & $Python $server --self-test
        if ($LASTEXITCODE -ne 0) { throw 'Agent Bridge Python self-test failed.' }
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
Get-RahSource $script:RahAgentBridgeServer $serverPath
Get-RahSource $script:RahAgentBridgeClient $clientPath
Assert-RahPowerShellParse $clientPath
& $python -m py_compile $serverPath
if ($LASTEXITCODE -ne 0) { throw 'Agent Bridge py_compile failed.' }
& $python $serverPath --self-test
if ($LASTEXITCODE -ne 0) { throw 'Agent Bridge Python self-test failed.' }
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $clientPath -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Agent Bus PowerShell self-test failed.' }

$tokenPath = Join-Path $root 'token.txt'
$null = New-RahToken $tokenPath
$launcherPath = Join-Path $root 'START-RAH-AGENT-BRIDGE.cmd'
Write-RahLauncher -Path $launcherPath -Python $python -ServerPath $serverPath -Root $root -Bus $bus -ListenPort $Port

try { Stop-ScheduledTask -TaskName $script:RahAgentBridgeTaskName -ErrorAction SilentlyContinue } catch {}
try { Unregister-ScheduledTask -TaskName $script:RahAgentBridgeTaskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}

$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/d /c ""{0}""' -f $launcherPath) -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -AtLogOn
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 9 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $script:RahAgentBridgeTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'RAH Agent Bridge v1 localhost structured job bus' -Force | Out-Null
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

$state = [pscustomobject]@{
    schema='rah-agent-bridge-install-state'
    version=1
    installedAt=(Get-Date).ToUniversalTime().ToString('o')
    installRoot=$root
    busRoot=$bus
    bind='127.0.0.1'
    port=$Port
    taskName=$script:RahAgentBridgeTaskName
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
Write-Host "Task   : $script:RahAgentBridgeTaskName"
Write-Host 'Exec   : disabled by design (structured job bus only)' -ForegroundColor Cyan
Write-Host '=============================================================' -ForegroundColor Yellow
exit 0

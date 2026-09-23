param(
    [ValidateSet('Status','Precheck','Repair','Start','Diagnostics')]
    [string]$Mode = 'Precheck',
    [switch]$JsonOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version = '7.0.0-foundation'
$script:RahRoot = 'C:\RAH'
$script:CoreRoot = 'C:\RAH\RavenCore7'
$script:StateRoot = Join-Path $script:CoreRoot 'state'
$script:LogRoot = Join-Path $script:CoreRoot 'logs'
$script:StatusFile = Join-Path $script:StateRoot 'status.json'
$script:NodeIdFile = Join-Path $script:StateRoot 'node-id.txt'
$script:AuditFile = Join-Path $script:LogRoot 'core7-audit.jsonl'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force -Path $script:CoreRoot,$script:StateRoot,$script:LogRoot | Out-Null

function Write-CoreAudit {
    param([string]$Event,[string]$Detail)
    $record = [pscustomobject][ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        event = $Event
        detail = $Detail
        computer = $env:COMPUTERNAME
        version = $script:Version
    }
    Add-Content -LiteralPath $script:AuditFile -Value ($record | ConvertTo-Json -Compress) -Encoding UTF8
}

function Get-CoreNodeId {
    if(Test-Path -LiteralPath $script:NodeIdFile -PathType Leaf){
        $existing = (Get-Content -LiteralPath $script:NodeIdFile -Raw).Trim()
        if($existing -match '^RAVEN-[A-F0-9]{12}$'){ return $existing }
    }
    $id = 'RAVEN-' + ([guid]::NewGuid().ToString('N').Substring(0,12).ToUpperInvariant())
    [IO.File]::WriteAllText($script:NodeIdFile,$id,$script:Utf8)
    return $id
}

function Find-RahFile {
    param([Parameter(Mandatory=$true)][string]$Name,[string[]]$ExtraRoots=@())
    $roots = @(
        $PSScriptRoot,
        $script:RahRoot,
        'C:\RAH\RavenOS',
        'C:\RAH\rah-platform',
        'C:\RAH\RAH-Platform',
        'C:\RAH\2PCProof',
        'C:\RAH\AI-Fabric'
    ) + $ExtraRoots
    foreach($root in $roots){
        if([string]::IsNullOrWhiteSpace($root)){ continue }
        $candidate = Join-Path $root $Name
        if(Test-Path -LiteralPath $candidate -PathType Leaf){
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    return $null
}

function Test-LocalPort {
    param([int]$Port)
    try {
        $client = New-Object Net.Sockets.TcpClient
        $iar = $client.BeginConnect('127.0.0.1',$Port,$null,$null)
        $ok = $iar.AsyncWaitHandle.WaitOne(450,$false)
        if($ok -and $client.Connected){
            $client.EndConnect($iar)
            $client.Close()
            return $true
        }
        $client.Close()
    } catch {}
    return $false
}

function Get-LocalJson {
    param([Parameter(Mandatory=$true)][string]$Uri)
    $allowed = @(
        'http://127.0.0.1:18765/health',
        'http://127.0.0.1:18765/agent/capabilities',
        'http://127.0.0.1:18765/agent/jobs/health',
        'http://127.0.0.1:18765/ai/providers',
        'http://127.0.0.1:18765/ai/memory/status',
        'http://127.0.0.1:1234/v1/models'
    )
    if($allowed -notcontains $Uri){ throw 'Core 7 local HTTP allowlist rejected the URI.' }
    try { return Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 3 }
    catch { return $null }
}

function Get-MachineSummary {
    $os = $null
    $cpu = $null
    $gpu = @()
    $cs = $null
    $systemDrive = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1 } catch {}
    try { $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1 } catch {}
    try { $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object { [string]$_.Name }) } catch {}
    try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop | Select-Object -First 1 } catch {}
    try { $systemDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop | Select-Object -First 1 } catch {}
    [pscustomobject][ordered]@{
        nodeId = Get-CoreNodeId
        hostname = $env:COMPUTERNAME
        user = $env:USERNAME
        os = if($os){ [string]$os.Caption }else{ [Environment]::OSVersion.VersionString }
        osVersion = if($os){ [string]$os.Version }else{ '' }
        cpu = if($cpu){ [string]$cpu.Name }else{ '' }
        ramGB = if($cs -and $cs.TotalPhysicalMemory){ [Math]::Round(([double]$cs.TotalPhysicalMemory / 1GB),1) }else{ $null }
        gpus = @($gpu | Where-Object { $_ })
        systemDriveFreeGB = if($systemDrive -and $systemDrive.FreeSpace){ [Math]::Round(([double]$systemDrive.FreeSpace / 1GB),1) }else{ $null }
    }
}

function Invoke-HardwareRegistryRefresh {
    $registry = Find-RahFile 'RAH-HARDWARE-REGISTRY.ps1'
    if(-not $registry){ return [pscustomobject]@{status='WARN';detail='RAH-HARDWARE-REGISTRY.ps1 not found.'} }
    try {
        $out = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $registry -CollectLocal 2>&1
        if($LASTEXITCODE -ne 0){ throw (($out | Out-String).Trim()) }
        return [pscustomobject]@{status='PASS';detail='Local hardware profile refreshed.'}
    } catch {
        return [pscustomobject]@{status='WARN';detail=('Hardware refresh warning: ' + $_.Exception.Message)}
    }
}

function Get-CoreStatus {
    $bridgePort = Test-LocalPort 18765
    $nodePort = Test-LocalPort 18766
    $lmPort = Test-LocalPort 1234
    $anythingPort = Test-LocalPort 3001

    $bridgeHealth = if($bridgePort){ Get-LocalJson 'http://127.0.0.1:18765/health' }else{ $null }
    $capabilities = if($bridgePort){ Get-LocalJson 'http://127.0.0.1:18765/agent/capabilities' }else{ $null }
    $jobsHealth = if($bridgePort){ Get-LocalJson 'http://127.0.0.1:18765/agent/jobs/health' }else{ $null }
    $aiProviders = if($bridgePort){ Get-LocalJson 'http://127.0.0.1:18765/ai/providers' }else{ $null }
    $memoryStatus = if($bridgePort){ Get-LocalJson 'http://127.0.0.1:18765/ai/memory/status' }else{ $null }
    $lmModels = if($lmPort){ Get-LocalJson 'http://127.0.0.1:1234/v1/models' }else{ $null }

    $frontDoor = Find-RahFile 'START-HER-RAH-OS.cmd'
    $frontSelfTest = Find-RahFile 'RAH-OS-SELFTEST.ps1'
    $frontRepair = Find-RahFile 'REPAIR-RAH-OS.cmd'
    $fabric = Find-RahFile 'START-RAH-AI-FABRIC.cmd'
    $commandCenter = Find-RahFile 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
    $grid = Find-RahFile 'START-HER-RAH-2PC-GRID.cmd'
    $gridVerify = Find-RahFile 'VERIFY-RAH-2PC-GRID.cmd'
    $projectSync = Find-RahFile 'SYNC-RAH-PROJECT-MEMORY.ps1'
    $hardwareRegistry = Test-Path -LiteralPath 'C:\RAH\HardwareRegistry\registry.json' -PathType Leaf
    $projectMemoryConfig = Test-Path -LiteralPath 'C:\RAH\AI-Fabric\project-memory.json' -PathType Leaf

    $requiredMissing = @()
    if(-not $frontDoor){ $requiredMissing += 'START-HER-RAH-OS.cmd' }
    if(-not $frontSelfTest){ $requiredMissing += 'RAH-OS-SELFTEST.ps1' }
    if(-not $fabric){ $requiredMissing += 'START-RAH-AI-FABRIC.cmd' }

    $capCount = 0
    if($capabilities -and $capabilities.capabilities){ $capCount = @($capabilities.capabilities).Count }

    $modelCount = 0
    if($lmModels -and $lmModels.data){ $modelCount = @($lmModels.data).Count }

    [pscustomobject][ordered]@{
        schema = 'rah-raven-core-status-v1'
        version = $script:Version
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        overall = if($requiredMissing.Count -gt 0){'FAIL'}elseif($bridgePort){'PASS'}else{'READY-TO-START'}
        machine = Get-MachineSummary
        foundation = [pscustomobject][ordered]@{
            frontDoor = [bool]$frontDoor
            frontDoorSelfTest = [bool]$frontSelfTest
            frontDoorRepair = [bool]$frontRepair
            aiFabricLauncher = [bool]$fabric
            commandCenter = [bool]$commandCenter
            grid = [bool]$grid
            gridVerify = [bool]$gridVerify
            hardwareRegistry = [bool]$hardwareRegistry
            projectMemoryConfig = [bool]$projectMemoryConfig
            projectMemorySync = [bool]$projectSync
            missingRequired = @($requiredMissing)
        }
        services = [pscustomobject][ordered]@{
            ravenCore18765 = [bool]$bridgePort
            nodeAgent18766 = [bool]$nodePort
            lmStudio1234 = [bool]$lmPort
            anythingLlm3001 = [bool]$anythingPort
        }
        raven = [pscustomobject][ordered]@{
            health = $bridgeHealth
            jobExecutor = $jobsHealth
            capabilityCount = $capCount
        }
        ai = [pscustomobject][ordered]@{
            lmStudioModelCount = $modelCount
            providers = $aiProviders
            memory = $memoryStatus
        }
        safety = [pscustomobject][ordered]@{
            arbitraryShell = $false
            backgroundNetworkDiscovery = $false
            automaticFirewallChanges = $false
            nodeTokenPersistence = $false
            automaticRemoteNodeStart = $false
            remoteAuthority = 'existing fixed Raven capability allowlist only'
        }
    }
}

function Save-CoreStatus {
    param($Status)
    $tmp = $script:StatusFile + '.tmp'
    [IO.File]::WriteAllText($tmp,(($Status | ConvertTo-Json -Depth 12) + [Environment]::NewLine),$script:Utf8)
    Move-Item -LiteralPath $tmp -Destination $script:StatusFile -Force
}

function Write-CoreStatus {
    param($Status)
    if($JsonOnly){
        $Status | ConvertTo-Json -Depth 12
        return
    }
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkYellow
    Write-Host '                 RAH RAVEN CORE 7.0' -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor DarkYellow
    Write-Host ('Machine .......... ' + $Status.machine.hostname + ' / ' + $Status.machine.nodeId)
    Write-Host ('Raven Core ....... ' + $(if($Status.services.ravenCore18765){'PASS'}else{'OFFLINE'}))
    Write-Host ('Node Agent ....... ' + $(if($Status.services.nodeAgent18766){'ONLINE / EXPLICIT'}else{'OFFLINE / EXPLICIT'}))
    Write-Host ('LM Studio ........ ' + $(if($Status.services.lmStudio1234){'ONLINE'}else{'OFFLINE'}))
    Write-Host ('AnythingLLM ...... ' + $(if($Status.services.anythingLlm3001){'ONLINE'}else{'OFFLINE'}))
    Write-Host ('Hardware Registry  ' + $(if($Status.foundation.hardwareRegistry){'READY'}else{'NOT BUILT'}))
    Write-Host ('Project Memory ... ' + $(if($Status.foundation.projectMemoryConfig){'CONFIGURED'}else{'NOT CONFIGURED'}))
    Write-Host ('2-PC Grid ........ ' + $(if($Status.foundation.grid){'READY'}else{'NOT FOUND'}))
    Write-Host ('Capabilities ..... ' + [string]$Status.raven.capabilityCount)
    Write-Host ''
    if(@($Status.foundation.missingRequired).Count -gt 0){
        Write-Host ('Missing required: ' + (@($Status.foundation.missingRequired) -join ', ')) -ForegroundColor Red
    }
    Write-Host ('CORE STATUS: ' + $Status.overall) -ForegroundColor $(if($Status.overall -eq 'FAIL'){'Red'}elseif($Status.overall -eq 'PASS'){'Green'}else{'Yellow'})
    Write-Host ('Status JSON: ' + $script:StatusFile) -ForegroundColor DarkGray
}

function Invoke-FrontDoorSelfTest {
    $self = Find-RahFile 'RAH-OS-SELFTEST.ps1'
    if(-not $self){ return 2 }
    & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $self -Quick
    return $LASTEXITCODE
}

function Invoke-CoreRepair {
    Write-CoreAudit 'repair-start' 'Core 7 fixed repair requested.'
    $repair = Find-RahFile 'REPAIR-RAH-OS.cmd'
    if($repair){
        Write-Host 'Running existing RAH OS fixed-allowlist Safe Repair...' -ForegroundColor Yellow
        & $repair
        if($LASTEXITCODE -ne 0){
            Write-CoreAudit 'repair-warning' ('RAH OS repair exit=' + [string]$LASTEXITCODE)
        }
    } else {
        Write-Host 'WARN: REPAIR-RAH-OS.cmd not found. No broad repair was attempted.' -ForegroundColor Yellow
    }

    $registry = Invoke-HardwareRegistryRefresh
    Write-Host ($registry.status + ': ' + $registry.detail) -ForegroundColor $(if($registry.status -eq 'PASS'){'Green'}else{'Yellow'})
    Write-CoreAudit 'repair-finish' $registry.detail

    $status = Get-CoreStatus
    Save-CoreStatus $status
    Write-CoreStatus $status
    if($status.overall -eq 'FAIL'){ return 1 }
    return 0
}

function Start-FixedLocalLauncher {
    param([Parameter(Mandatory=$true)][string]$Name)
    $path = Find-RahFile $Name
    if(-not $path){ throw ('Fixed launcher not found: ' + $Name) }
    Write-CoreAudit 'start-fixed-launcher' $Name
    Start-Process -FilePath $path -WorkingDirectory (Split-Path -Parent $path)
}

function Invoke-CoreStart {
    Write-CoreAudit 'start-begin' 'Canonical START-HER.cmd flow.'
    $pre = Get-CoreStatus
    Save-CoreStatus $pre

    if($pre.overall -eq 'FAIL'){
        Write-Host 'PRECHECK found a required foundation problem.' -ForegroundColor Yellow
        $repairCode = Invoke-CoreRepair
        if($repairCode -ne 0){
            Write-CoreAudit 'start-stop' 'Foundation remained FAIL after safe repair.'
            return 2
        }
    }

    $status = Get-CoreStatus
    if(-not $status.services.ravenCore18765){
        if($status.foundation.aiFabricLauncher){
            Write-Host 'Starting fixed Raven Core / AI Fabric launcher...' -ForegroundColor Yellow
            Start-FixedLocalLauncher 'START-RAH-AI-FABRIC.cmd'
            Start-Sleep -Seconds 2
        }
    }

    $status = Get-CoreStatus
    if($status.foundation.commandCenter){
        try { Start-FixedLocalLauncher 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat' }
        catch { Write-CoreAudit 'command-center-warning' $_.Exception.Message }
    }

    # Node Agent 18766 remains explicit by design. Core 7 never starts it here.
    Start-Sleep -Milliseconds 700
    $post = Get-CoreStatus
    Save-CoreStatus $post
    Write-CoreStatus $post

    if($post.foundation.frontDoor){
        try { Start-FixedLocalLauncher 'START-HER-RAH-OS.cmd' }
        catch { Write-CoreAudit 'front-door-warning' $_.Exception.Message }
    }

    Write-CoreAudit 'start-finish' ('overall=' + $post.overall + '; nodeAutoStart=false')
    if($post.overall -eq 'FAIL'){ return 1 }
    return 0
}

function Invoke-CoreDiagnostics {
    Write-CoreAudit 'diagnostics-start' 'Read-only diagnostics plus local hardware refresh.'
    $registry = Invoke-HardwareRegistryRefresh
    $status = Get-CoreStatus
    Save-CoreStatus $status
    Write-CoreStatus $status
    if(-not $JsonOnly){
        Write-Host ''
        Write-Host ('Hardware refresh : ' + $registry.status + ' - ' + $registry.detail)
        Write-Host 'Safety:' -ForegroundColor DarkYellow
        Write-Host ' - no arbitrary command input'
        Write-Host ' - no background network discovery'
        Write-Host ' - no firewall modification'
        Write-Host ' - no Node token persistence'
        Write-Host ' - Node Agent startup remains explicit'
        Write-Host ('Audit log: ' + $script:AuditFile) -ForegroundColor DarkGray
    }
    Write-CoreAudit 'diagnostics-finish' ('overall=' + $status.overall)
    if($status.overall -eq 'FAIL'){ return 1 }
    return 0
}

$exitCode = 0
switch($Mode){
    'Status' {
        $s = Get-CoreStatus
        Save-CoreStatus $s
        Write-CoreStatus $s
        if($s.overall -eq 'FAIL'){ $exitCode = 1 }
    }
    'Precheck' {
        $frontCode = Invoke-FrontDoorSelfTest
        $s = Get-CoreStatus
        Save-CoreStatus $s
        Write-CoreStatus $s
        if($frontCode -ne 0 -or $s.overall -eq 'FAIL'){ $exitCode = 1 }
    }
    'Repair' { $exitCode = Invoke-CoreRepair }
    'Start' { $exitCode = Invoke-CoreStart }
    'Diagnostics' { $exitCode = Invoke-CoreDiagnostics }
}
exit $exitCode

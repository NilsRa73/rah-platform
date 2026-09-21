param(
    [switch]$CollectLocal,
    [string]$ImportProfilePath = '',
    [switch]$Show,
    [switch]$SelfTest,
    [string]$Root = 'C:\RAH\HardwareRegistry'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RegistryEncoding = New-Object Text.UTF8Encoding($false)

function Get-RahProfileHash {
    param($Profile)
    $basis = [ordered]@{
        hostname = $Profile.hostname
        system = $Profile.system
        motherboard = $Profile.motherboard
        bios = $Profile.bios
        os = $Profile.os
        cpu = $Profile.cpu
        memory = $Profile.memory
        gpus = $Profile.gpus
        pcieSlots = $Profile.pcieSlots
        storage = $Profile.storage
        network = $Profile.network
        monitors = $Profile.monitors
        upgradeFacts = $Profile.upgradeFacts
    }
    $raw = $basis | ConvertTo-Json -Depth 20 -Compress
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($raw)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
}

function Get-RahRegistry {
    param([string]$RegistryRoot)
    $path = Join-Path $RegistryRoot 'registry.json'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try {
            $obj = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($obj.schema -eq 'rah-hardware-registry-v1') { return $obj }
        } catch {}
    }
    [pscustomobject][ordered]@{
        schema = 'rah-hardware-registry-v1'
        version = 1
        updatedAt = (Get-Date).ToUniversalTime().ToString('o')
        devices = @()
    }
}

function Write-RahJsonAtomic {
    param([string]$Path,$Value)
    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $tmp = $Path + '.tmp'
    [IO.File]::WriteAllText($tmp, (($Value | ConvertTo-Json -Depth 24) + [Environment]::NewLine), $script:RegistryEncoding)
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Get-RahDeviceSummary {
    param($Profile)
    $cpuName = ''
    if (@($Profile.cpu).Count -gt 0) { $cpuName = [string]@($Profile.cpu)[0].name }
    $gpuNames = @(@($Profile.gpus) | ForEach-Object { [string]$_.name } | Where-Object { $_ })
    [pscustomobject][ordered]@{
        manufacturer = [string]$Profile.system.manufacturer
        model = [string]$Profile.system.model
        motherboard = (([string]$Profile.motherboard.manufacturer + ' ' + [string]$Profile.motherboard.product).Trim())
        cpu = $cpuName
        ramGB = $Profile.memory.totalGB
        memorySlotsTotal = $Profile.memory.slotsTotal
        memorySlotsUsed = $Profile.memory.slotsUsed
        memorySlotsFree = $Profile.memory.slotsFree
        gpus = $gpuNames
        disks = @($Profile.storage.disks).Count
        monitors = @($Profile.monitors).Count
    }
}

function Update-RahHardwareRegistry {
    param(
        [Parameter(Mandatory=$true)]$Profile,
        [string]$Source = 'local',
        [string]$RegistryRoot = 'C:\RAH\HardwareRegistry'
    )

    if ($null -eq $Profile -or [string]$Profile.schema -ne 'rah-hardware-profile-v1') {
        throw 'Unsupported hardware profile schema.'
    }
    $hostname = ([string]$Profile.hostname).Trim()
    if ([string]::IsNullOrWhiteSpace($hostname)) { throw 'Hardware profile hostname missing.' }
    $id = ($hostname.ToLowerInvariant() -replace '[^a-z0-9_-]','-').Trim('-')
    if (-not $id) { throw 'Unable to derive device id.' }

    New-Item -ItemType Directory -Force -Path $RegistryRoot | Out-Null
    $registry = Get-RahRegistry -RegistryRoot $RegistryRoot
    $hash = Get-RahProfileHash -Profile $Profile
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $devices = @($registry.devices)
    $existing = $devices | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1
    $changed = $true
    $firstSeen = $now
    $historyCount = 0
    if ($existing) {
        $firstSeen = [string]$existing.firstSeen
        $historyCount = [int]$existing.historyCount
        $changed = ([string]$existing.profileHash -ne $hash)
        $devices = @($devices | Where-Object { [string]$_.id -ne $id })
    }

    $devicePath = Join-Path (Join-Path $RegistryRoot 'devices') ($id + '.json')
    Write-RahJsonAtomic -Path $devicePath -Value $Profile

    if ($changed) {
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
        $historyPath = Join-Path (Join-Path (Join-Path $RegistryRoot 'history') $id) ($stamp + '-' + $hash.Substring(0,12) + '.json')
        Write-RahJsonAtomic -Path $historyPath -Value $Profile
        $historyCount++
    }

    $record = [pscustomobject][ordered]@{
        id = $id
        hostname = $hostname
        firstSeen = $firstSeen
        lastSeen = $now
        lastSource = $Source
        profileHash = $hash
        changedOnLastScan = $changed
        historyCount = $historyCount
        summary = Get-RahDeviceSummary -Profile $Profile
        profile = $Profile
    }
    $devices += $record
    $registry.devices = @($devices | Sort-Object hostname)
    $registry.updatedAt = $now
    Write-RahJsonAtomic -Path (Join-Path $RegistryRoot 'registry.json') -Value $registry

    [pscustomobject][ordered]@{
        ok = $true
        schema = 'rah-hardware-registry-update-v1'
        deviceId = $id
        hostname = $hostname
        changed = $changed
        profileHash = $hash
        historyCount = $historyCount
        registryPath = Join-Path $RegistryRoot 'registry.json'
        devicePath = $devicePath
    }
}

function Test-RahHardwareRegistry {
    $testRoot = Join-Path $env:TEMP ('rah-hardware-registry-selftest-' + [guid]::NewGuid().ToString('N'))
    try {
        $profile = [pscustomobject][ordered]@{
            schema='rah-hardware-profile-v1';version=1;collectedAt=(Get-Date).ToUniversalTime().ToString('o');hostname='SELFTEST-PC'
            system=[pscustomobject]@{manufacturer='RAH';model='SelfTest';totalRamGB=16}
            motherboard=[pscustomobject]@{manufacturer='RAH';product='Board';version='1'}
            bios=[pscustomobject]@{version='1'}
            os=[pscustomobject]@{caption='Windows';version='11';architecture='64-bit'}
            cpu=@([pscustomobject]@{name='CPU';cores=4;logicalProcessors=8})
            memory=[pscustomobject]@{totalGB=16;slotsTotal=2;slotsUsed=1;slotsFree=1;modules=@([pscustomobject]@{capacityGB=16;partNumber='RAM-123';memoryType='DDR4'})}
            gpus=@([pscustomobject]@{name='GPU'})
            pcieSlots=@([pscustomobject]@{designation='PCIEX16';currentUsage='Available'})
            storage=[pscustomobject]@{disks=@([pscustomobject]@{model='Disk';sizeGB=512});physicalDisks=@();volumes=@()}
            network=@();monitors=@();upgradeFacts=[pscustomobject]@{memorySlotsFree=1;gpuCount=1;diskCount=1;monitorCount=0}
        }
        $a = Update-RahHardwareRegistry -Profile $profile -Source 'selftest' -RegistryRoot $testRoot
        $b = Update-RahHardwareRegistry -Profile $profile -Source 'selftest' -RegistryRoot $testRoot
        if (-not $a.changed -or $b.changed) { throw 'Registry change detection failed.' }
        $reg = Get-Content -LiteralPath (Join-Path $testRoot 'registry.json') -Raw | ConvertFrom-Json
        if (@($reg.devices).Count -ne 1 -or $reg.devices[0].summary.memorySlotsFree -ne 1) { throw 'Registry summary failed.' }
        Write-Host 'PASS: RAH Hardware Registry self-test' -ForegroundColor Green
    } finally {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($SelfTest) {
        Test-RahHardwareRegistry
        exit 0
    }
    if ($CollectLocal) {
        . (Join-Path $PSScriptRoot 'RAH-HARDWARE-INVENTORY.ps1')
        $profile = Get-RahHardwareInventory
        Update-RahHardwareRegistry -Profile $profile -Source 'local-collector' -RegistryRoot $Root | ConvertTo-Json -Depth 8
        exit 0
    }
    if ($ImportProfilePath) {
        $profile = Get-Content -LiteralPath $ImportProfilePath -Raw | ConvertFrom-Json -ErrorAction Stop
        Update-RahHardwareRegistry -Profile $profile -Source 'remote-raven-system-inventory' -RegistryRoot $Root | ConvertTo-Json -Depth 8
        exit 0
    }
    if ($Show) {
        Get-RahRegistry -RegistryRoot $Root | ConvertTo-Json -Depth 24
        exit 0
    }
    Write-Host 'Use -CollectLocal, -ImportProfilePath, -Show or -SelfTest.'
}

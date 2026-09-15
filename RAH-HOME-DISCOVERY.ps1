param(
    [string]$OutputPath = "",
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahDiscoveryVersion = '1.0.0'

function Test-RahPrivateIPv4 {
    param([Parameter(Mandatory)][string]$Ip)

    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($Ip, [ref]$parsed)) { return $false }
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $false }

    $bytes = $parsed.GetAddressBytes()
    return (
        $bytes[0] -eq 10 -or
        ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or
        ($bytes[0] -eq 192 -and $bytes[1] -eq 168)
    )
}

function Get-RahAdapters {
    @(Get-NetAdapter -ErrorAction Stop |
        Where-Object { $_.Status -eq 'Up' } |
        Sort-Object ifIndex |
        ForEach-Object {
            [pscustomobject]@{
                ifIndex              = [int]$_.ifIndex
                name                 = [string]$_.Name
                interfaceDescription = [string]$_.InterfaceDescription
                status               = [string]$_.Status
                macAddress           = [string]$_.MacAddress
                linkSpeed            = [string]$_.LinkSpeed
            }
        })
}

function Get-RahLocalIPv4Addresses {
    $values = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress } |
        ForEach-Object { [string]$_.IPAddress })

    return @($values | Sort-Object -Unique)
}

function Get-RahNeighborCache {
    param(
        [Parameter(Mandatory)][int[]]$AllowedIfIndex,
        [string[]]$LocalIPv4 = @()
    )

    $allowedStates = @('Reachable','Stale','Delay','Probe','Permanent')

    if (-not $AllowedIfIndex -or $AllowedIfIndex.Count -eq 0) { return @() }

    @(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object {
            $ip = [string]$_.IPAddress
            $AllowedIfIndex -contains [int]$_.ifIndex -and
            $allowedStates -contains [string]$_.State -and
            (Test-RahPrivateIPv4 $ip) -and
            $LocalIPv4 -notcontains $ip
        } |
        Sort-Object ifIndex,IPAddress -Unique |
        ForEach-Object {
            [pscustomobject]@{
                ipAddress        = [string]$_.IPAddress
                macAddress       = [string]$_.LinkLayerAddress
                ifIndex          = [int]$_.ifIndex
                state            = [string]$_.State
                source           = 'windows-neighbor-cache'
                passive          = $true
            }
        })
}

function New-RahDiscoveryDocument {
    param(
        [Parameter(Mandatory)][object[]]$Adapters,
        [Parameter(Mandatory)][object[]]$Devices
    )

    [ordered]@{
        schema        = 'rah-home-discovery-cache'
        version       = 1
        scriptVersion = $script:RahDiscoveryVersion
        product       = 'RAH Home Control'
        mode          = 'passive-neighbor-cache'
        passive       = $true
        scope         = 'rfc1918-active-adapters-only'
        generatedAt   = (Get-Date).ToUniversalTime().ToString('o')
        adapters      = @($Adapters)
        devices       = @($Devices)
        note          = 'Passive local discovery only: reads the existing Windows IPv4 neighbor cache on active adapters. It does not ping, probe, resolve names, scan ports, or contact discovered devices.'
    }
}

function Write-RahDiscoveryDocument {
    param(
        [Parameter(Mandatory)]$Document,
        [string]$Path = ''
    )

    $json = $Document | ConvertTo-Json -Depth 7

    if (-not $Path) {
        return $json
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $directory = Split-Path -Parent $fullPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "RAH Home Discovery skrev passiv cache til: $fullPath" -ForegroundColor Green
    Write-Host "Kandidater: $(@($Document.devices).Count) · aktive adaptere: $(@($Document.adapters).Count)"
}

function Invoke-RahHomeDiscovery {
    param([string]$Path = '')

    $adapters = @(Get-RahAdapters)
    $ifIndexes = @($adapters | ForEach-Object { [int]$_.ifIndex })
    $localIPv4 = @(Get-RahLocalIPv4Addresses)
    $devices = @(Get-RahNeighborCache -AllowedIfIndex $ifIndexes -LocalIPv4 $localIPv4)
    $document = New-RahDiscoveryDocument -Adapters $adapters -Devices $devices
    Write-RahDiscoveryDocument -Document $document -Path $Path
}

function Invoke-RahDiscoverySelfTest {
    $cases = @(
        @{ Ip = '10.0.0.1'; Expected = $true },
        @{ Ip = '172.16.0.1'; Expected = $true },
        @{ Ip = '172.31.255.254'; Expected = $true },
        @{ Ip = '192.168.1.1'; Expected = $true },
        @{ Ip = '172.32.0.1'; Expected = $false },
        @{ Ip = '100.64.0.1'; Expected = $false },
        @{ Ip = '127.0.0.1'; Expected = $false },
        @{ Ip = '224.0.0.1'; Expected = $false },
        @{ Ip = 'not-an-ip'; Expected = $false }
    )

    foreach ($case in $cases) {
        $actual = Test-RahPrivateIPv4 $case.Ip
        if ($actual -ne $case.Expected) {
            throw "SelfTest feilet for $($case.Ip): forventet $($case.Expected), fikk $actual."
        }
    }

    $sample = New-RahDiscoveryDocument -Adapters @() -Devices @()
    if ($sample.schema -ne 'rah-home-discovery-cache' -or $sample.version -ne 1 -or -not $sample.passive -or $sample.mode -ne 'passive-neighbor-cache') {
        throw 'SelfTest feilet: discovery-kontrakten er ikke kompatibel med Inbox.'
    }

    Write-Host "RAH Home Discovery $script:RahDiscoveryVersion SelfTest OK" -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($SelfTest) {
            Invoke-RahDiscoverySelfTest
        }
        else {
            Invoke-RahHomeDiscovery -Path $OutputPath
        }
    }
    catch {
        Write-Error "RAH Home Discovery feilet: $($_.Exception.Message)"
        exit 1
    }
}

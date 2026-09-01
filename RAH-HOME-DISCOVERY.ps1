param(
    [string]$OutputPath = ""
)

$ErrorActionPreference = 'Stop'

function Get-RahAdapters {
    Get-NetAdapter -ErrorAction Stop |
        Sort-Object ifIndex |
        ForEach-Object {
            [pscustomobject]@{
                ifIndex              = $_.ifIndex
                name                 = $_.Name
                interfaceDescription = $_.InterfaceDescription
                status               = [string]$_.Status
                macAddress           = [string]$_.MacAddress
                linkSpeed            = [string]$_.LinkSpeed
            }
        }
}

function Get-RahNeighborCache {
    $allowedStates = @('Reachable','Stale','Delay','Probe','Permanent')

    Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object {
            $allowedStates -contains [string]$_.State -and
            $_.IPAddress -and
            $_.IPAddress -notmatch '^0\.' -and
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.IPAddress -notmatch '^224\.' -and
            $_.IPAddress -ne '255.255.255.255'
        } |
        Sort-Object ifIndex,IPAddress -Unique |
        ForEach-Object {
            [pscustomobject]@{
                ipAddress        = [string]$_.IPAddress
                macAddress       = [string]$_.LinkLayerAddress
                ifIndex          = $_.ifIndex
                state            = [string]$_.State
                source           = 'windows-neighbor-cache'
                passive          = $true
            }
        }
}

try {
    $adapters = @(Get-RahAdapters)
    $devices = @(Get-RahNeighborCache)

    $document = [ordered]@{
        schema      = 'rah-home-discovery-cache'
        version     = 1
        product     = 'RAH Home Control'
        mode        = 'passive-neighbor-cache'
        passive     = $true
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        adapters    = $adapters
        devices     = $devices
        note        = 'Passive foundation only: reads the existing Windows IPv4 neighbor cache and does not ping, probe or actively scan the network.'
    }

    $json = $document | ConvertTo-Json -Depth 6

    if ($OutputPath) {
        $fullPath = [System.IO.Path]::GetFullPath($OutputPath)
        $directory = Split-Path -Parent $fullPath
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Host "RAH Home Discovery skrev passiv cache til: $fullPath"
    }
    else {
        $json
    }
}
catch {
    Write-Error "RAH Home Discovery kunne ikke lese lokal nettverkscache: $($_.Exception.Message)"
    exit 1
}

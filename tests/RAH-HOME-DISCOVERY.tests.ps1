Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot 'RAH-HOME-DISCOVERY.ps1'
. $scriptPath

function Assert-Rah {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

Invoke-RahDiscoverySelfTest

# Contract test: keep compatibility with RAH-HOME-DISCOVERY-INBOX.html.
$doc = New-RahDiscoveryDocument -Adapters @() -Devices @()
Assert-Rah ($doc.schema -eq 'rah-home-discovery-cache') 'Wrong schema.'
Assert-Rah ($doc.version -eq 1) 'Wrong schema version.'
Assert-Rah ($doc.product -eq 'RAH Home Control') 'Wrong product.'
Assert-Rah ($doc.mode -eq 'passive-neighbor-cache') 'Wrong mode.'
Assert-Rah ($doc.passive -eq $true) 'Passive flag must be true.'
Assert-Rah ($doc.adapters -is [System.Collections.IEnumerable]) 'Adapters must be enumerable.'
Assert-Rah ($doc.devices -is [System.Collections.IEnumerable]) 'Devices must be enumerable.'

# Filtering test: only private RFC1918 neighbors on allowed active adapter,
# excluding the local machine's own address.
function Get-NetNeighbor {
    param([string]$AddressFamily, [object]$ErrorAction)
    @(
        [pscustomobject]@{ IPAddress='192.168.1.20'; LinkLayerAddress='AA-BB-CC-DD-EE-20'; ifIndex=7; State='Reachable' },
        [pscustomobject]@{ IPAddress='192.168.1.10'; LinkLayerAddress='AA-BB-CC-DD-EE-10'; ifIndex=7; State='Reachable' },
        [pscustomobject]@{ IPAddress='8.8.8.8'; LinkLayerAddress='AA-BB-CC-DD-EE-08'; ifIndex=7; State='Reachable' },
        [pscustomobject]@{ IPAddress='10.0.0.5'; LinkLayerAddress='AA-BB-CC-DD-EE-05'; ifIndex=99; State='Reachable' },
        [pscustomobject]@{ IPAddress='192.168.1.30'; LinkLayerAddress='AA-BB-CC-DD-EE-30'; ifIndex=7; State='Unreachable' }
    )
}

$devices = @(Get-RahNeighborCache -AllowedIfIndex @(7) -LocalIPv4 @('192.168.1.10'))
Assert-Rah ($devices.Count -eq 1) "Expected 1 filtered neighbor, got $($devices.Count)."
Assert-Rah ($devices[0].ipAddress -eq '192.168.1.20') 'Wrong neighbor survived filtering.'
Assert-Rah ($devices[0].passive -eq $true) 'Filtered neighbor must be marked passive.'
Assert-Rah ($devices[0].source -eq 'windows-neighbor-cache') 'Wrong source marker.'

Remove-Item Function:Get-NetNeighbor -ErrorAction SilentlyContinue

# Adapter test: only Up adapters are exported.
function Get-NetAdapter {
    param([object]$ErrorAction)
    @(
        [pscustomobject]@{ ifIndex=3; Name='Ethernet'; InterfaceDescription='Mock Ethernet'; Status='Up'; MacAddress='00-11-22-33-44-55'; LinkSpeed='1 Gbps' },
        [pscustomobject]@{ ifIndex=4; Name='Wi-Fi'; InterfaceDescription='Mock Wi-Fi'; Status='Disconnected'; MacAddress='00-11-22-33-44-66'; LinkSpeed='0 bps' }
    )
}

$adapters = @(Get-RahAdapters)
Assert-Rah ($adapters.Count -eq 1) "Expected 1 active adapter, got $($adapters.Count)."
Assert-Rah ($adapters[0].ifIndex -eq 3) 'Wrong adapter survived filtering.'

Remove-Item Function:Get-NetAdapter -ErrorAction SilentlyContinue

Write-Host 'RAH-HOME-DISCOVERY tests OK' -ForegroundColor Green

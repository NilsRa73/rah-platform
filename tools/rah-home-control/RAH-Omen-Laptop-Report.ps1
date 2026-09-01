[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

function Get-RahPortState {
    param([Parameter(Mandatory)][int]$Port)

    if (Get-NetTCPConnection -LocalPort $Port -State Listen `
        -ErrorAction SilentlyContinue) {
        return 'ONLINE'
    }
    return 'OFFLINE'
}

function Get-RahVBoxManage {
    $command = Get-Command 'VBoxManage.exe' -ErrorAction SilentlyContinue
    $candidates = @(
        $(if ($command) { $command.Source })
        $(if ($env:ProgramFiles) {
            Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
        })
        $(if (${env:ProgramFiles(x86)}) {
            Join-Path ${env:ProgramFiles(x86)} `
                'Oracle\VirtualBox\VBoxManage.exe'
        })
    ) | Where-Object {
        $_ -and (Test-Path -LiteralPath $_ -PathType Leaf)
    } | Select-Object -Unique

    return $candidates | Select-Object -First 1
}

function Get-RahVirtualBoxData {
    $vboxManage = Get-RahVBoxManage
    if (-not $vboxManage) {
        return [PSCustomObject]@{
            Status = 'NOT FOUND'
            Version = 'Not installed or VBoxManage.exe was not found'
            VMs = @()
        }
    }

    $version = (& $vboxManage --version 2>$null | Select-Object -First 1)
    $vmLines = @(& $vboxManage list vms 2>$null)
    $vmData = [Collections.Generic.List[object]]::new()

    foreach ($vmLine in $vmLines) {
        if ($vmLine -notmatch '^"(.+)"\s+\{[0-9A-Fa-f-]+\}$') {
            continue
        }

        $vmName = $Matches[1]
        $machineInfo = @(
            & $vboxManage showvminfo $vmName --machinereadable 2>$null
        )

        $state = 'unknown'
        $stateLine = $machineInfo |
            Where-Object { $_ -match '^VMState=' } |
            Select-Object -First 1
        if ($stateLine -match '^VMState="([^"]+)"') {
            $state = $Matches[1]
        }

        $networkLines = @(
            $machineInfo | Where-Object {
                $_ -match '^(nic|nictype|macaddress|cableconnected|bridgeadapter|hostonlyadapter|hostonlynet|natnet)[1-4]='
            }
        )
        $networkText = if ($networkLines.Count -gt 0) {
            (($networkLines -replace '"', '') -join '; ')
        }
        else {
            'No VM network data found'
        }

        $vmData.Add([PSCustomObject]@{
            Name = $vmName
            State = $state
            Network = $networkText
        })
    }

    return [PSCustomObject]@{
        Status = 'INSTALLED'
        Version = [string]$version
        VMs = @($vmData)
    }
}

$computer = Get-CimInstance Win32_ComputerSystem
$battery = Get-CimInstance Win32_Battery | Select-Object -First 1
$detectedMachine = '{0} {1}' -f $computer.Manufacturer, $computer.Model
$isHp = $computer.Manufacturer -match '(?i)(^HP$|Hewlett|HP Inc)'
$isOmenModel = $computer.Model -match '(?i)OMEN'
$isOmenLaptop = $isHp -and ($isOmenModel -or $null -ne $battery)

if (-not $isOmenLaptop) {
    $stopMessage = @(
        'RAH SAFETY STOP'
        'This script must run on OMEN-LAPTOP in Windows.'
        'Do not run it on HOVED-PC or inside KALI-VM.'
        ('Detected: {0} / Windows name: {1}' -f `
            $detectedMachine, $env:COMPUTERNAME)
        'No system or network settings were changed.'
    ) -join "`r`n"

    Write-Host $stopMessage -ForegroundColor Red
    $stopMessage | Set-Clipboard
    return
}

$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpus = @(
    Get-CimInstance Win32_VideoController |
        Select-Object -ExpandProperty Name
)
$networkRecords = [Collections.Generic.List[string]]::new()

$ipConfigurations = Get-NetIPConfiguration | Where-Object {
    $_.NetAdapter.Status -eq 'Up' -and $_.IPv4Address
}
foreach ($configuration in $ipConfigurations) {
    $adapter = Get-NetAdapter -InterfaceIndex $configuration.InterfaceIndex
    $profile = Get-NetConnectionProfile `
        -InterfaceIndex $configuration.InterfaceIndex |
        Select-Object -First 1
    $ipInterface = Get-NetIPInterface `
        -InterfaceIndex $configuration.InterfaceIndex `
        -AddressFamily IPv4 |
        Select-Object -First 1

    $gateway = if ($configuration.IPv4DefaultGateway) {
        $configuration.IPv4DefaultGateway.NextHop
    }
    else {
        'none'
    }
    $profileName = if ($profile) { $profile.Name } else { 'unknown' }
    $profileType = if ($profile) { $profile.NetworkCategory } else { 'unknown' }
    $metric = if ($ipInterface) { $ipInterface.InterfaceMetric } else { 'unknown' }
    $adapterKind = if ($adapter.InterfaceDescription -match `
        '(?i)(Virtual|VPN|TAP|TUN|WireGuard|ZeroTier|VMware|VirtualBox|Hyper-V|spacedesk)') {
        'VIRTUAL'
    }
    else {
        'PHYSICAL'
    }

    $networkRecords.Add((
        '[{0}] {1} | {2} | IPv4={3} | Gateway={4} | Speed={5} | Metric={6} | Profile={7}/{8}' -f `
            $adapterKind,
            $adapter.Name,
            $adapter.InterfaceDescription,
            ($configuration.IPv4Address.IPAddress -join ','),
            $gateway,
            $adapter.LinkSpeed,
            $metric,
            $profileName,
            $profileType
    ))
}

if ($networkRecords.Count -eq 0) {
    $networkRecords.Add('No active IPv4 adapters found')
}

$virtualBox = Get-RahVirtualBoxData
$vmRecords = [Collections.Generic.List[string]]::new()
if (@($virtualBox.VMs).Count -eq 0) {
    $vmRecords.Add('No registered VirtualBox VMs found')
}
else {
    foreach ($vm in $virtualBox.VMs) {
        $vmRecords.Add((
            'VM={0} | State={1} | {2}' -f `
                $vm.Name, $vm.State, $vm.Network
        ))
    }
}

$batteryText = if ($battery) {
    '{0}% (status code {1})' -f `
        $battery.EstimatedChargeRemaining, $battery.BatteryStatus
}
else {
    'No battery data'
}

$reportLines = [Collections.Generic.List[string]]::new()
$reportLines.Add('============================================================')
$reportLines.Add(' RAH OMEN-LAPTOP / WINDOWS HOST REPORT')
$reportLines.Add('============================================================')
$reportLines.Add(('Time: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
$reportLines.Add('Run target: OMEN-LAPTOP (Windows host)')
$reportLines.Add('RAH role: RAVEN-OMEN / Development + VirtualBox Host')
$reportLines.Add(('Windows name: {0}' -f $env:COMPUTERNAME))
$reportLines.Add(('Hardware: {0}' -f $detectedMachine))
$reportLines.Add(('Windows: {0} / {1}' -f $os.Caption, $os.Version))
$reportLines.Add(('PowerShell: {0}' -f $PSVersionTable.PSVersion))
$reportLines.Add(('CPU: {0}' -f $cpu.Name))
$reportLines.Add(('RAM: {0} GB' -f `
    [Math]::Round($computer.TotalPhysicalMemory / 1GB, 1)))
$reportLines.Add(('GPU: {0}' -f ($gpus -join ' | ')))
$reportLines.Add(('Battery: {0}' -f $batteryText))
$reportLines.Add('')
$reportLines.Add('ACTIVE WINDOWS NETWORKS')
foreach ($record in $networkRecords) {
    $reportLines.Add($record)
}
$reportLines.Add('')
$reportLines.Add('LOCAL RAH SERVICES ON OMEN-LAPTOP')
$reportLines.Add(('RAH Bridge 18765: {0}' -f (Get-RahPortState 18765)))
$reportLines.Add(('Old Bridge 8765: {0}' -f (Get-RahPortState 8765)))
$reportLines.Add(('Ollama 11434: {0}' -f (Get-RahPortState 11434)))
$reportLines.Add('')
$reportLines.Add('VIRTUALBOX + KALI-VM')
$reportLines.Add(('VirtualBox: {0}' -f $virtualBox.Status))
$reportLines.Add(('VirtualBox version: {0}' -f $virtualBox.Version))
foreach ($record in $vmRecords) {
    $reportLines.Add($record)
}
$reportLines.Add('============================================================')

$report = $reportLines -join "`r`n"
$reportRoot = Join-Path $env:USERPROFILE `
    'Documents\RAH Room Control\Reports'
$timestampFile = Join-Path $reportRoot (
    'RAH-OMEN-LAPTOP-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
)
$latestFile = Join-Path $reportRoot 'RAH-OMEN-LAPTOP-LATEST.txt'

New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$report | Set-Content -LiteralPath $timestampFile -Encoding UTF8
$report | Set-Content -LiteralPath $latestFile -Encoding UTF8
$report | Set-Clipboard

Write-Host $report -ForegroundColor Yellow
Write-Host ''
Write-Host 'OMEN-LAPTOP report copied. Return to ChatGPT and press Ctrl+V.' `
    -ForegroundColor Green
Write-Host ('Saved: {0}' -f $latestFile) -ForegroundColor DarkGray

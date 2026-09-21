param(
    [switch]$Json,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RahCim {
    param([string]$ClassName,[string]$Namespace='root/cimv2')
    try { @(Get-CimInstance -Namespace $Namespace -ClassName $ClassName -ErrorAction Stop) }
    catch { @() }
}

function Convert-RahWmiChars {
    param($Value)
    if ($null -eq $Value) { return '' }
    $chars = @($Value | Where-Object { [int]$_ -gt 0 } | ForEach-Object { [char][int]$_ })
    return (-join $chars).Trim()
}

function Get-RahMemoryTypeName {
    param([int]$Code)
    $map = @{
        20='DDR';21='DDR2';22='DDR2 FB-DIMM';24='DDR3';26='DDR4';27='LPDDR'
        28='LPDDR2';29='LPDDR3';30='LPDDR4';34='DDR5';35='LPDDR5'
    }
    if ($map.ContainsKey($Code)) { return $map[$Code] }
    if ($Code -gt 0) { return "SMBIOS-$Code" }
    return 'Unknown'
}

function Get-RahFormFactorName {
    param([int]$Code)
    $map = @{8='DIMM';12='SODIMM';13='SRIMM';15='FB-DIMM'}
    if ($map.ContainsKey($Code)) { return $map[$Code] }
    if ($Code -gt 0) { return "Code-$Code" }
    return 'Unknown'
}

function Convert-RahUsageName {
    param([int]$Code)
    switch ($Code) {
        3 { 'Available' }
        4 { 'InUse' }
        5 { 'Unavailable' }
        2 { 'Unknown' }
        default { 'Other' }
    }
}

function Get-RahHardwareInventory {
    $os = @(Get-RahCim 'Win32_OperatingSystem') | Select-Object -First 1
    $cs = @(Get-RahCim 'Win32_ComputerSystem') | Select-Object -First 1
    $board = @(Get-RahCim 'Win32_BaseBoard') | Select-Object -First 1
    $bios = @(Get-RahCim 'Win32_BIOS') | Select-Object -First 1
    $cpus = @(Get-RahCim 'Win32_Processor')
    $memory = @(Get-RahCim 'Win32_PhysicalMemory')
    $arrays = @(Get-RahCim 'Win32_PhysicalMemoryArray')
    $gpus = @(Get-RahCim 'Win32_VideoController')
    $slots = @(Get-RahCim 'Win32_SystemSlot')
    $disks = @(Get-RahCim 'Win32_DiskDrive')

    $slotCount = 0
    $maxMemoryKB = 0.0
    foreach ($arr in $arrays) {
        if ($null -ne $arr.MemoryDevices) { $slotCount += [int]$arr.MemoryDevices }
        $value = 0.0
        if ($null -ne $arr.PSObject.Properties['MaxCapacityEx'] -and [double]$arr.MaxCapacityEx -gt 0) {
            $value = [double]$arr.MaxCapacityEx
        } elseif ($null -ne $arr.MaxCapacity -and [double]$arr.MaxCapacity -gt 0) {
            $value = [double]$arr.MaxCapacity
        }
        $maxMemoryKB += $value
    }

    $modules = @()
    foreach ($m in $memory) {
        $capacityGB = if ($m.Capacity) { [Math]::Round(([double]$m.Capacity / 1GB),2) } else { $null }
        $modules += [pscustomobject][ordered]@{
            deviceLocator = ([string]$m.DeviceLocator).Trim()
            bankLabel = ([string]$m.BankLabel).Trim()
            capacityGB = $capacityGB
            manufacturer = ([string]$m.Manufacturer).Trim()
            partNumber = ([string]$m.PartNumber).Trim()
            memoryType = Get-RahMemoryTypeName ([int]$m.SMBIOSMemoryType)
            formFactor = Get-RahFormFactorName ([int]$m.FormFactor)
            speedMHz = if ($m.Speed) { [int]$m.Speed } else { $null }
            configuredSpeedMHz = if ($m.ConfiguredClockSpeed) { [int]$m.ConfiguredClockSpeed } else { $null }
            configuredVoltageMv = if ($m.ConfiguredVoltage) { [int]$m.ConfiguredVoltage } else { $null }
        }
    }

    $cpuRows = @()
    foreach ($cpu in $cpus) {
        $cpuRows += [pscustomobject][ordered]@{
            name = ([string]$cpu.Name).Trim()
            manufacturer = ([string]$cpu.Manufacturer).Trim()
            socket = ([string]$cpu.SocketDesignation).Trim()
            cores = if ($cpu.NumberOfCores) { [int]$cpu.NumberOfCores } else { $null }
            logicalProcessors = if ($cpu.NumberOfLogicalProcessors) { [int]$cpu.NumberOfLogicalProcessors } else { $null }
            maxClockMHz = if ($cpu.MaxClockSpeed) { [int]$cpu.MaxClockSpeed } else { $null }
            virtualizationFirmwareEnabled = if ($null -ne $cpu.VirtualizationFirmwareEnabled) { [bool]$cpu.VirtualizationFirmwareEnabled } else { $null }
            secondLevelAddressTranslation = if ($null -ne $cpu.SecondLevelAddressTranslationExtensions) { [bool]$cpu.SecondLevelAddressTranslationExtensions } else { $null }
        }
    }

    $gpuRows = @()
    foreach ($gpu in $gpus) {
        $vramGB = $null
        try {
            if ([uint64]$gpu.AdapterRAM -gt 0) { $vramGB = [Math]::Round(([double][uint64]$gpu.AdapterRAM / 1GB),2) }
        } catch {}
        $gpuRows += [pscustomobject][ordered]@{
            name = ([string]$gpu.Name).Trim()
            videoProcessor = ([string]$gpu.VideoProcessor).Trim()
            adapterRamGBReported = $vramGB
            driverVersion = ([string]$gpu.DriverVersion).Trim()
            pnpDeviceId = ([string]$gpu.PNPDeviceID).Trim()
            currentResolution = if ($gpu.CurrentHorizontalResolution -and $gpu.CurrentVerticalResolution) {
                '{0}x{1}' -f [int]$gpu.CurrentHorizontalResolution,[int]$gpu.CurrentVerticalResolution
            } else { '' }
            status = ([string]$gpu.Status).Trim()
        }
    }

    $slotRows = @()
    foreach ($slot in $slots) {
        $slotRows += [pscustomobject][ordered]@{
            designation = ([string]$slot.SlotDesignation).Trim()
            description = ([string]$slot.Description).Trim()
            purpose = ([string]$slot.Purpose).Trim()
            currentUsage = Convert-RahUsageName ([int]$slot.CurrentUsage)
            maxDataWidthCode = if ($slot.MaxDataWidth) { [int]$slot.MaxDataWidth } else { $null }
            status = ([string]$slot.Status).Trim()
        }
    }

    $diskRows = @()
    foreach ($disk in $disks) {
        $diskRows += [pscustomobject][ordered]@{
            model = ([string]$disk.Model).Trim()
            sizeGB = if ($disk.Size) { [Math]::Round(([double]$disk.Size / 1GB),1) } else { $null }
            interfaceType = ([string]$disk.InterfaceType).Trim()
            mediaType = ([string]$disk.MediaType).Trim()
            firmwareRevision = ([string]$disk.FirmwareRevision).Trim()
            pnpDeviceId = ([string]$disk.PNPDeviceID).Trim()
        }
    }

    $physicalRows = @()
    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        try {
            foreach ($pd in @(Get-PhysicalDisk -ErrorAction Stop)) {
                $physicalRows += [pscustomobject][ordered]@{
                    friendlyName = ([string]$pd.FriendlyName).Trim()
                    mediaType = [string]$pd.MediaType
                    busType = [string]$pd.BusType
                    sizeGB = if ($pd.Size) { [Math]::Round(([double]$pd.Size / 1GB),1) } else { $null }
                    healthStatus = [string]$pd.HealthStatus
                    operationalStatus = (@($pd.OperationalStatus) -join ',')
                }
            }
        } catch {}
    }

    $volumeRows = @()
    if (Get-Command Get-Volume -ErrorAction SilentlyContinue) {
        try {
            foreach ($vol in @(Get-Volume -ErrorAction Stop | Where-Object { $_.Size -gt 0 })) {
                $volumeRows += [pscustomobject][ordered]@{
                    driveLetter = [string]$vol.DriveLetter
                    fileSystem = [string]$vol.FileSystem
                    label = [string]$vol.FileSystemLabel
                    sizeGB = [Math]::Round(([double]$vol.Size / 1GB),1)
                    freeGB = [Math]::Round(([double]$vol.SizeRemaining / 1GB),1)
                    healthStatus = [string]$vol.HealthStatus
                }
            }
        } catch {}
    }

    $networkRows = @()
    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        try {
            foreach ($adapter in @(Get-NetAdapter -Physical -ErrorAction Stop)) {
                $networkRows += [pscustomobject][ordered]@{
                    name = [string]$adapter.Name
                    description = [string]$adapter.InterfaceDescription
                    status = [string]$adapter.Status
                    linkSpeed = [string]$adapter.LinkSpeed
                    mediaType = [string]$adapter.MediaType
                }
            }
        } catch {}
    }

    $monitorRows = @()
    foreach ($mon in @(Get-RahCim 'WmiMonitorID' 'root/wmi')) {
        $name = Convert-RahWmiChars $mon.UserFriendlyName
        $manufacturer = Convert-RahWmiChars $mon.ManufacturerName
        $product = Convert-RahWmiChars $mon.ProductCodeID
        $monitorRows += [pscustomobject][ordered]@{
            name = $name
            manufacturerCode = $manufacturer
            productCode = $product
            active = if ($null -ne $mon.Active) { [bool]$mon.Active } else { $null }
        }
    }

    $secureBoot = $null
    if (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
        try { $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch {}
    }

    $totalRamGB = if ($cs.TotalPhysicalMemory) { [Math]::Round(([double]$cs.TotalPhysicalMemory / 1GB),2) } else {
        [Math]::Round((($modules | Measure-Object capacityGB -Sum).Sum),2)
    }
    $freeSlots = if ($slotCount -gt 0) { [Math]::Max(0,$slotCount - $modules.Count) } else { $null }
    $availablePciSlots = @($slotRows | Where-Object { $_.currentUsage -eq 'Available' }).Count

    [pscustomobject][ordered]@{
        schema = 'rah-hardware-profile-v1'
        version = 1
        collectedAt = (Get-Date).ToUniversalTime().ToString('o')
        hostname = $env:COMPUTERNAME
        system = [pscustomobject][ordered]@{
            manufacturer = ([string]$cs.Manufacturer).Trim()
            model = ([string]$cs.Model).Trim()
            systemType = ([string]$cs.SystemType).Trim()
            totalRamGB = $totalRamGB
            hypervisorPresent = if ($null -ne $cs.HypervisorPresent) { [bool]$cs.HypervisorPresent } else { $null }
        }
        motherboard = [pscustomobject][ordered]@{
            manufacturer = ([string]$board.Manufacturer).Trim()
            product = ([string]$board.Product).Trim()
            version = ([string]$board.Version).Trim()
        }
        bios = [pscustomobject][ordered]@{
            manufacturer = ([string]$bios.Manufacturer).Trim()
            smbiosVersion = ([string]$bios.SMBIOSBIOSVersion).Trim()
            version = ([string]$bios.Version).Trim()
            releaseDate = if ($bios.ReleaseDate) { ([datetime]$bios.ReleaseDate).ToUniversalTime().ToString('o') } else { '' }
            secureBoot = $secureBoot
        }
        os = [pscustomobject][ordered]@{
            caption = ([string]$os.Caption).Trim()
            version = ([string]$os.Version).Trim()
            buildNumber = ([string]$os.BuildNumber).Trim()
            architecture = ([string]$os.OSArchitecture).Trim()
        }
        cpu = $cpuRows
        memory = [pscustomobject][ordered]@{
            totalGB = $totalRamGB
            slotsTotal = if ($slotCount -gt 0) { $slotCount } else { $null }
            slotsUsed = $modules.Count
            slotsFree = $freeSlots
            maxCapacityGB = if ($maxMemoryKB -gt 0) { [Math]::Round(($maxMemoryKB / 1MB),1) } else { $null }
            modules = $modules
        }
        gpus = $gpuRows
        pcieSlots = $slotRows
        storage = [pscustomobject][ordered]@{
            disks = $diskRows
            physicalDisks = $physicalRows
            volumes = $volumeRows
        }
        network = $networkRows
        monitors = $monitorRows
        upgradeFacts = [pscustomobject][ordered]@{
            memorySlotsTotal = if ($slotCount -gt 0) { $slotCount } else { $null }
            memorySlotsUsed = $modules.Count
            memorySlotsFree = $freeSlots
            maxMemoryGBReported = if ($maxMemoryKB -gt 0) { [Math]::Round(($maxMemoryKB / 1MB),1) } else { $null }
            pcieSlotsReported = $slotRows.Count
            pcieSlotsAvailableReported = $availablePciSlots
            gpuCount = $gpuRows.Count
            diskCount = $diskRows.Count
            monitorCount = $monitorRows.Count
        }
        dataQuality = [pscustomobject][ordered]@{
            serialNumbersStored = $false
            psuWattageAvailable = $false
            chassisClearanceAvailable = $false
            note = 'PSU wattage, chassis clearance and exact PCIe generation/lane wiring may require model documentation or physical inspection.'
        }
    }
}

function Test-RahHardwareInventory {
    $profile = Get-RahHardwareInventory
    if ($profile.schema -ne 'rah-hardware-profile-v1') { throw 'Hardware profile schema failed.' }
    if ([string]::IsNullOrWhiteSpace([string]$profile.hostname)) { throw 'Hardware profile hostname missing.' }
    $raw = $profile | ConvertTo-Json -Depth 20
    if ($raw -match '"serialNumber"|"SerialNumber"') { throw 'Hardware profile must not store serial numbers.' }
    Write-Host 'PASS: RAH Hardware Inventory self-test' -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($SelfTest) {
        Test-RahHardwareInventory
        exit 0
    }
    $profile = Get-RahHardwareInventory
    if ($Json) {
        $profile | ConvertTo-Json -Depth 20 -Compress
    } else {
        $profile | ConvertTo-Json -Depth 20
    }
}

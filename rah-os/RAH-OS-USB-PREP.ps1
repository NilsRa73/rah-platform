[CmdletBinding()]
param(
    [string]$IsoPath,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportPath = Join-Path $ScriptDir "RAH-OS-USB-PREP-$Timestamp.txt"
$Report = [System.Collections.Generic.List[string]]::new()

function Add-ReportLine {
    param([string]$Text = '')
    $Report.Add($Text)
    Write-Host $Text
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    return "$Bytes bytes"
}

function Resolve-RahIso {
    param(
        [string]$ExplicitPath,
        [string[]]$SearchRoots
    )

    if ($ExplicitPath) {
        $resolved = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop
        if ([IO.Path]::GetExtension($resolved.Path) -ne '.iso') {
            throw "IsoPath must point to an .iso file: $($resolved.Path)"
        }
        return Get-Item -LiteralPath $resolved.Path
    }

    $candidates = foreach ($root in ($SearchRoots | Where-Object { $_ } | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Filter 'RAH-OS*.iso' -File -ErrorAction SilentlyContinue
        }
    }

    return $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Get-UsbDiskSnapshot {
    try {
        $usb = @(Get-Disk -ErrorAction Stop | Where-Object { $_.BusType -eq 'USB' })
        return $usb
    }
    catch {
        Add-ReportLine "[WARN] Could not query Get-Disk: $($_.Exception.Message)"
        return @()
    }
}

function Get-FlashingToolSnapshot {
    $names = @('rufus.exe', 'balenaEtcher.exe', 'Ventoy2Disk.exe')
    $found = [System.Collections.Generic.List[string]]::new()

    foreach ($name in $names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source) { $found.Add($cmd.Source) }
    }

    $known = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\balena-etcher\balenaEtcher.exe'),
        (Join-Path $env:ProgramFiles 'balenaEtcher\balenaEtcher.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Ventoy\Ventoy2Disk.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($path in $known) {
        if (-not $found.Contains($path)) { $found.Add($path) }
    }

    return @($found)
}

function Save-Report {
    try {
        $Report | Set-Content -LiteralPath $ReportPath -Encoding UTF8
        return $ReportPath
    }
    catch {
        $fallback = Join-Path $env:TEMP "RAH-OS-USB-PREP-$Timestamp.txt"
        $Report | Set-Content -LiteralPath $fallback -Encoding UTF8
        return $fallback
    }
}

function Invoke-SelfTest {
    Add-ReportLine '============================================================'
    Add-ReportLine ' RAH OS USB PREP - SELF TEST'
    Add-ReportLine '============================================================'

    $fixture = Join-Path $env:TEMP ("RAH-OS-selftest-{0}.iso" -f [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText($fixture, 'RAH OS USB prep self-test fixture', [Text.Encoding]::UTF8)
        $item = Resolve-RahIso -ExplicitPath $fixture -SearchRoots @()
        if (-not $item -or $item.Extension -ne '.iso') { throw 'ISO resolver self-test failed.' }

        $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        if ($hash.Length -ne 64) { throw 'SHA-256 self-test failed.' }

        $size = Format-Bytes -Bytes $item.Length
        if (-not $size) { throw 'Size formatter self-test failed.' }

        Add-ReportLine "[PASS] ISO resolution"
        Add-ReportLine "[PASS] SHA-256 hashing"
        Add-ReportLine "[PASS] Report formatting"
        Add-ReportLine "[PASS] Safety mode: this script contains no USB write/format operation"
        Add-ReportLine 'SELFTEST=PASS'
        return 0
    }
    finally {
        Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue
    }
}

try {
    if ($SelfTest) {
        exit (Invoke-SelfTest)
    }

    Add-ReportLine '============================================================'
    Add-ReportLine ' RAH OS RAVEN - WINDOWS USB PREP / DIAGNOSTICS'
    Add-ReportLine '============================================================'
    Add-ReportLine ("Time     : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    Add-ReportLine ("Computer : {0}" -f $env:COMPUTERNAME)
    Add-ReportLine ("User     : {0}" -f $env:USERNAME)
    Add-ReportLine ''
    Add-ReportLine 'SAFETY: Read-only preparation. This tool NEVER formats or writes a USB disk.'
    Add-ReportLine ''

    $roots = @(
        $ScriptDir,
        (Get-Location).Path,
        (Join-Path $ScriptDir 'output'),
        (Join-Path $HOME 'Downloads')
    )
    $iso = Resolve-RahIso -ExplicitPath $IsoPath -SearchRoots $roots

    Add-ReportLine 'ISO'
    Add-ReportLine '------------------------------------------------------------'
    if ($iso) {
        $hash = Get-FileHash -LiteralPath $iso.FullName -Algorithm SHA256
        Add-ReportLine "[PASS] $($iso.FullName)"
        Add-ReportLine "       Size   : $(Format-Bytes $iso.Length)"
        Add-ReportLine "       SHA256 : $($hash.Hash)"

        $sidecar = "$($iso.FullName).sha256"
        if (Test-Path -LiteralPath $sidecar) {
            $expectedLine = (Get-Content -LiteralPath $sidecar -ErrorAction Stop | Select-Object -First 1).Trim()
            $expected = ($expectedLine -split '\s+')[0].ToUpperInvariant()
            if ($expected -eq $hash.Hash.ToUpperInvariant()) {
                Add-ReportLine '[PASS] SHA-256 matches sidecar checksum.'
            }
            else {
                Add-ReportLine '[FAIL] SHA-256 DOES NOT match sidecar checksum. Do not flash this ISO.'
            }
        }
        else {
            Add-ReportLine '[INFO] No .sha256 sidecar found beside ISO; computed hash is recorded above.'
        }
    }
    else {
        Add-ReportLine '[WARN] No RAH-OS*.iso found.'
        Add-ReportLine '       Put the downloaded ISO beside START-HER.cmd or in Downloads, then run again.'
    }

    Add-ReportLine ''
    Add-ReportLine 'USB DISKS (READ-ONLY INVENTORY)'
    Add-ReportLine '------------------------------------------------------------'
    $usb = Get-UsbDiskSnapshot
    if ($usb.Count -eq 0) {
        Add-ReportLine '[INFO] No USB disk detected by Get-Disk.'
    }
    else {
        foreach ($disk in $usb) {
            $danger = if ($disk.IsBoot -or $disk.IsSystem) { ' *** SYSTEM/BOOT - DO NOT USE ***' } else { '' }
            Add-ReportLine ("Disk {0}: {1} | {2} | {3} | {4}{5}" -f $disk.Number, $disk.FriendlyName, (Format-Bytes $disk.Size), $disk.PartitionStyle, $disk.OperationalStatus, $danger)
        }
    }

    Add-ReportLine ''
    Add-ReportLine 'FLASHING TOOLS'
    Add-ReportLine '------------------------------------------------------------'
    $tools = Get-FlashingToolSnapshot
    if ($tools.Count -eq 0) {
        Add-ReportLine '[INFO] Rufus, balenaEtcher or Ventoy was not detected on PATH/common locations.'
    }
    else {
        foreach ($tool in $tools) { Add-ReportLine "[PASS] $tool" }
    }

    Add-ReportLine ''
    Add-ReportLine 'NEXT SAFE STEP'
    Add-ReportLine '------------------------------------------------------------'
    if (-not $iso) {
        Add-ReportLine '1. Download/copy the RAH OS ISO and checksum into this folder.'
        Add-ReportLine '2. Run START-HER.cmd again.'
    }
    else {
        Add-ReportLine '1. Confirm the SHA-256 result above.'
        Add-ReportLine '2. Open Rufus/balenaEtcher/Ventoy yourself and select the RAH OS ISO.'
        Add-ReportLine '3. Double-check the target USB disk before any write operation.'
        Add-ReportLine '4. Boot the Lenovo from USB and run RAH Hardware Check before touching its internal SSD.'
    }

    $saved = Save-Report
    Write-Host ''
    Write-Host "Report: $saved"

    if ($iso) { exit 0 }
    exit 2
}
catch {
    Add-ReportLine ''
    Add-ReportLine "[FAIL] $($_.Exception.Message)"
    $saved = Save-Report
    Write-Host "Report: $saved"
    exit 10
}

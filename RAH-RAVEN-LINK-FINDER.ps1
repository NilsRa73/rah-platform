$ErrorActionPreference = 'SilentlyContinue'
$port = 8765
$storeDir = Join-Path $env:LOCALAPPDATA 'RAH Raven'
$storeFile = Join-Path $storeDir 'link-ip.txt'
New-Item -ItemType Directory -Force -Path $storeDir | Out-Null

Write-Host ''
Write-Host ' RAH RAVEN LINK FINDER v1.0' -ForegroundColor Cyan
Write-Host ' ============================' -ForegroundColor Cyan
Write-Host ' Searching the local network for the main PC...' -ForegroundColor Yellow
Write-Host ''

$config = Get-NetIPConfiguration | Where-Object {
    $_.IPv4DefaultGateway -and $_.IPv4Address.IPAddress -notlike '169.254.*'
} | Select-Object -First 1

if (-not $config) {
    Write-Host 'No active network connection with a default gateway was found.' -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

$ownIp = $config.IPv4Address.IPAddress
$parts = $ownIp.Split('.')
if ($parts.Count -ne 4) {
    Write-Host "Unsupported IPv4 address: $ownIp" -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}
$prefix = "$($parts[0]).$($parts[1]).$($parts[2])"
Write-Host "Omen address: $ownIp"
Write-Host "Network: $prefix.0/24"

$candidates = New-Object System.Collections.Generic.List[string]
$seen = New-Object 'System.Collections.Generic.HashSet[string]'

function Add-Candidate([string]$ip) {
    if ($ip -and $ip -ne $ownIp -and $seen.Add($ip)) {
        $candidates.Add($ip)
    }
}

if (Test-Path $storeFile) {
    Add-Candidate ((Get-Content $storeFile -First 1).Trim())
}

$arpText = arp -a | Out-String
[regex]::Matches($arpText, "\b$([regex]::Escape($prefix))\.(\d{1,3})\b") | ForEach-Object {
    Add-Candidate $_.Value
}

1..254 | ForEach-Object { Add-Candidate "$prefix.$_" }

function Test-RahBridge([string]$ip) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($ip, $port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(140)) { return $false }
        $client.EndConnect($async)
    } catch {
        return $false
    } finally {
        $client.Close()
    }

    try {
        $health = Invoke-RestMethod -Uri "http://$ip`:$port/health" -TimeoutSec 2
        return ($health.ok -eq $true -and $health.name -like 'RAH Raven*')
    } catch {
        return $false
    }
}

$found = $null
$count = 0
foreach ($ip in $candidates) {
    $count++
    if (($count % 20) -eq 0) {
        Write-Host "Checked $count addresses..."
    }
    if (Test-RahBridge $ip) {
        $found = $ip
        break
    }
}

if ($found) {
    Set-Content -Path $storeFile -Value $found -Encoding ASCII
    $url = "http://$found`:$port/link"
    Write-Host ''
    Write-Host "RAH Raven main PC found: $found" -ForegroundColor Green
    Write-Host "Opening $url" -ForegroundColor Green
    Start-Process $url
    Start-Sleep -Seconds 2
    exit 0
}

Write-Host ''
Write-Host 'RAH Raven main PC was not found.' -ForegroundColor Red
Write-Host 'On the main PC, start LM Studio and START-RAH-LINK-LAN.bat.' -ForegroundColor Yellow
Write-Host 'Also allow RAH Link through Windows Firewall on Private networks.' -ForegroundColor Yellow
Read-Host 'Press Enter to close'
exit 1

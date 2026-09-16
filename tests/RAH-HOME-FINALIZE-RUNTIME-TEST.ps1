param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Parse {
    param([Parameter(Mandatory)][string]$Path)
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count -ne 0) { throw "Parser failure in $Path : $($errors[0].Message)" }
}

function Invoke-CheckedPowerShell {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $exe = Join-Path $PSHOME 'powershell.exe'
    & $exe @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "Child PowerShell failed with exit code $code" }
}

function Test-PrivateIPv4 {
    param([string]$Address)
    if ([string]::IsNullOrWhiteSpace($Address)) { return $false }
    $parts = $Address.Split('.')
    if ($parts.Count -ne 4) { return $false }
    $n = @()
    foreach ($part in $parts) {
        if ($part -notmatch '^\d{1,3}$') { return $false }
        $value = [int]$part
        if ($value -lt 0 -or $value -gt 255 -or [string]$value -ne $part) { return $false }
        $n += $value
    }
    return ($n[0] -eq 10 -or ($n[0] -eq 172 -and $n[1] -ge 16 -and $n[1] -le 31) -or ($n[0] -eq 192 -and $n[1] -eq 168))
}

function Get-TestPrivateAddress {
    $withGateway = @()
    $all = @()
    foreach ($cfg in @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter -and $_.NetAdapter.Status -eq 'Up' })) {
        foreach ($a in @($cfg.IPv4Address)) {
            if ($a -and (Test-PrivateIPv4 ([string]$a.IPAddress))) {
                $all += [string]$a.IPAddress
                if (@($cfg.IPv4DefaultGateway).Count -gt 0) { $withGateway += [string]$a.IPAddress }
            }
        }
    }
    $withGateway = @($withGateway | Select-Object -Unique)
    $all = @($all | Select-Object -Unique)
    if ($withGateway.Count -gt 0) { return $withGateway[0] }
    if ($all.Count -gt 0) { return $all[0] }
    throw 'CI runner has no RFC1918 IPv4 address for LAN integration.'
}

$repo = [IO.Path]::GetFullPath($RepoRoot)
$finalizer = Join-Path $repo 'RAH-HOME-FINALIZE.ps1'
Assert-Parse $finalizer
Assert-Parse (Join-Path $repo 'RAH-HOME-ACCEPTANCE.ps1')
Assert-Parse (Join-Path $repo 'RAH-HOME-INSTALL.ps1')

Invoke-CheckedPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$finalizer,'-SelfTest')

$temp = Join-Path $env:TEMP ('rah-home-finalize-v1-' + [Guid]::NewGuid().ToString('N'))
$oldLocalAppData = $env:LOCALAPPDATA
$env:LOCALAPPDATA = Join-Path $temp 'localapp'
$workerRoot = Join-Path $temp 'worker-home'
$workerDesktop = Join-Path $temp 'worker-desktop'
$leaderRoot = Join-Path $temp 'leader-home'
$leaderDesktop = Join-Path $temp 'leader-desktop'
$address = Get-TestPrivateAddress

try {
    New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null

    Write-Host "CI private address: $address" -ForegroundColor Cyan

    Invoke-CheckedPowerShell @(
        '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$finalizer,
        '-Mode','Worker','-InstallRoot',$workerRoot,'-DesktopPath',$workerDesktop,
        '-SourceDirectory',$repo,'-WorkerAddress',$address,'-SkipFirewall','-SkipAutostart'
    )

    $workerReportPath = Join-Path $workerRoot 'reports\rah-home-finalize-latest.json'
    $readyPath = Join-Path $workerRoot 'RAH-HOME-WORKER-READY.txt'
    if (-not (Test-Path -LiteralPath $workerReportPath -PathType Leaf)) { throw 'Worker final report missing.' }
    if (-not (Test-Path -LiteralPath $readyPath -PathType Leaf)) { throw 'Worker ready handoff missing.' }
    $workerReport = Get-Content -Raw -LiteralPath $workerReportPath | ConvertFrom-Json
    if (-not $workerReport.pass -or $workerReport.mode -ne 'Worker') { throw 'Worker finalize report is not PASS.' }
    $ready = Get-Content -Raw -LiteralPath $readyPath
    if ($ready -notmatch 'PAIR CODE\s*:\s*(\d{6})') { throw 'Worker ready file has no six-digit pair code.' }
    $pairCode = $Matches[1]

    Invoke-CheckedPowerShell @(
        '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$finalizer,
        '-Mode','Leader','-InstallRoot',$leaderRoot,'-DesktopPath',$leaderDesktop,
        '-SourceDirectory',$repo,'-WorkerAddress',$address,'-PairCode',$pairCode
    )

    $leaderReportPath = Join-Path $leaderRoot 'reports\rah-home-finalize-latest.json'
    if (-not (Test-Path -LiteralPath $leaderReportPath -PathType Leaf)) { throw 'Leader final report missing.' }
    $leaderReport = Get-Content -Raw -LiteralPath $leaderReportPath | ConvertFrom-Json
    if (-not $leaderReport.pass -or $leaderReport.mode -ne 'Leader' -or [string]$leaderReport.remoteAddress -ne $address) { throw 'Leader finalize report is not full PASS.' }
    $names = @($leaderReport.checks | ForEach-Object { [string]$_.name })
    foreach ($required in @('hoved-pc-local-acceptance','leader-component-selftests','worker-pairing','remote-health','remote-systemInfo','remote-benchmark')) {
        if ($names -notcontains $required) { throw "Leader final report missing check: $required" }
    }
    if (@($leaderReport.checks | Where-Object { -not $_.ok }).Count -ne 0) { throw 'Leader final report contains failed checks.' }

    Write-Host 'PASS: RAH Home Finalize v1 full Worker -> Pair -> Leader -> health/systemInfo/benchmark runtime' -ForegroundColor Green
}
finally {
    foreach ($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -ieq 'powershell.exe' -or $_.Name -ieq 'pwsh.exe') -and $_.CommandLine -and $_.CommandLine.Contains('RAH-HOME-NODE-AGENT.ps1')
    })) {
        try { Stop-Process -Id ([int]$p.ProcessId) -Force -ErrorAction SilentlyContinue } catch { }
    }
    $env:LOCALAPPDATA = $oldLocalAppData
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

param(
    [string]$InstallRoot = 'C:\RAH\Home',
    [string]$Reason = 'manual',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahHomeDiagnosticsVersion = '1.0.0'
$script:RahStablePort = 18766
$script:RahWorkerTaskName = 'RAH Home Worker'
$script:RahFirewallName = 'RAH Home Worker TCP 18766'

function Protect-RahText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    $safe = [string]$Text
    $safe = [regex]::Replace($safe, '(?im)(PAIR\s*CODE\s*[:=]\s*)\d{6}', '$1[REDACTED]')
    $safe = [regex]::Replace($safe, '(?im)("?(?:paircode|pairingcode|token|secret|password|apikey|authorization)"?\s*[:=]\s*"?)([^"\r\n,}\s]+)"?', '$1[REDACTED]')
    $safe = [regex]::Replace($safe, '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+', 'Bearer [REDACTED]')
    return $safe
}

function Test-RahAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Test-RahPrivateIPv4 {
    param([string]$Address)
    if (-not $Address) { return $false }
    $parts = $Address.Split('.')
    if ($parts.Count -ne 4) { return $false }
    $n = @()
    foreach ($part in $parts) {
        if ($part -notmatch '^\d{1,3}$') { return $false }
        $v = [int]$part
        if ($v -lt 0 -or $v -gt 255) { return $false }
        $n += $v
    }
    return ($n[0] -eq 10 -or ($n[0] -eq 172 -and $n[1] -ge 16 -and $n[1] -le 31) -or ($n[0] -eq 192 -and $n[1] -eq 168))
}

function Get-RahCommandVersion {
    param([string]$Name,[string[]]$Arguments)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { return [pscustomobject]@{name=$Name;found=$false;path=$null;version=$null;error=$null} }
    try {
        $raw = & $cmd.Source @Arguments 2>&1 | Out-String
        return [pscustomobject]@{name=$Name;found=$true;path=$cmd.Source;version=(Protect-RahText $raw.Trim());error=$null}
    } catch {
        return [pscustomobject]@{name=$Name;found=$true;path=$cmd.Source;version=$null;error=(Protect-RahText $_.Exception.Message)}
    }
}

function Get-RahFileInventory {
    param([string]$Root)
    $names = @(
        'RAH-HOME-FINALIZE.ps1','RAH-HOME-ACCEPTANCE.ps1','RAH-HOME-INSTALL.ps1',
        'RAH-HOME-NODE-AGENT.ps1','RAH-HOME-NODE-CLIENT.ps1','RAH-HOME-NODE-JOB.ps1',
        'RAH-HOME-CLUSTER-CONTROLLER.ps1','RAH-HOME-CLUSTER-RUN.ps1','RAH-HOME-PAIR-WIZARD.ps1',
        'RAH-HOME-LAN-ACCEPTANCE.ps1','RAH-HOME-DIAGNOSTICS.ps1'
    )
    $items = @()
    foreach ($name in $names) {
        $path = Join-Path $Root $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $items += [pscustomobject]@{name=$name;present=$false;size=$null;sha256=$null;parse=$null}
            continue
        }
        $item = Get-Item -LiteralPath $path
        $parse = 'n/a'
        if ($item.Extension -ieq '.ps1') {
            $tokens=$null; $errors=$null
            [Management.Automation.Language.Parser]::ParseFile($item.FullName,[ref]$tokens,[ref]$errors) | Out-Null
            $parse = if (@($errors).Count -eq 0) { 'ok' } else { Protect-RahText $errors[0].Message }
        }
        $hash = $null
        try { $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash } catch { }
        $items += [pscustomobject]@{name=$name;present=$true;size=[int64]$item.Length;sha256=$hash;parse=$parse}
    }
    return @($items)
}

function Get-RahStateSummary {
    param([string]$Root)
    $path = Join-Path $Root 'rah-home-install-state.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return [pscustomobject]@{present=$false} }
    try {
        $doc = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        return [pscustomobject]@{
            present=$true
            schema=$(if($doc.PSObject.Properties.Name -contains 'schema'){[string]$doc.schema}else{$null})
            version=$(if($doc.PSObject.Properties.Name -contains 'version'){$doc.version}else{$null})
            mode=$(if($doc.PSObject.Properties.Name -contains 'mode'){[string]$doc.mode}else{$null})
            port=$(if($doc.PSObject.Properties.Name -contains 'port'){$doc.port}else{$null})
            workerAddress=$(if($doc.PSObject.Properties.Name -contains 'workerAddress'){[string]$doc.workerAddress}else{$null})
            installRoot=$(if($doc.PSObject.Properties.Name -contains 'installRoot'){[string]$doc.installRoot}else{$null})
        }
    } catch {
        return [pscustomobject]@{present=$true;error=(Protect-RahText $_.Exception.Message)}
    }
}

function Get-RahNetworkSummary {
    $addresses = @()
    if (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue) {
        foreach ($ip in @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue)) {
            $address = [string]$ip.IPAddress
            if (-not (Test-RahPrivateIPv4 $address)) { continue }
            $addresses += [pscustomobject]@{address=$address;alias=[string]$ip.InterfaceAlias;state=[string]$ip.AddressState;prefixLength=$ip.PrefixLength}
        }
    }
    $listeners = @()
    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
        foreach ($c in @(Get-NetTCPConnection -LocalPort $script:RahStablePort -State Listen -ErrorAction SilentlyContinue)) {
            $listeners += [pscustomobject]@{localAddress=[string]$c.LocalAddress;localPort=[int]$c.LocalPort;owningProcess=[int]$c.OwningProcess}
        }
    }
    return [pscustomobject]@{privateIPv4=@($addresses);listeners18766=@($listeners)}
}

function Get-RahFirewallSummary {
    if (-not (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue)) { return [pscustomobject]@{available=$false} }
    try {
        $r = Get-NetFirewallRule -DisplayName $script:RahFirewallName -ErrorAction Stop | Select-Object -First 1
        return [pscustomobject]@{available=$true;present=$true;enabled=[string]$r.Enabled;profile=[string]$r.Profile;direction=[string]$r.Direction;action=[string]$r.Action}
    } catch { return [pscustomobject]@{available=$true;present=$false} }
}

function Get-RahTaskSummary {
    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return [pscustomobject]@{available=$false} }
    try {
        $t = Get-ScheduledTask -TaskName $script:RahWorkerTaskName -ErrorAction Stop
        return [pscustomobject]@{available=$true;present=$true;state=[string]$t.State;taskPath=[string]$t.TaskPath}
    } catch { return [pscustomobject]@{available=$true;present=$false} }
}

function Get-RahProcessSummary {
    $rows = @()
    try {
        foreach ($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
            $line = [string]$p.CommandLine
            if (-not $line -or $line -notmatch '(?i)RAH-HOME|C:\\RAH\\Home') { continue }
            $rows += [pscustomobject]@{pid=[int]$p.ProcessId;name=[string]$p.Name;commandLine=(Protect-RahText $line)}
        }
    } catch { }
    return @($rows)
}

function Copy-RahSafeTextFile {
    param([string]$Source,[string]$Destination)
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return $false }
    try {
        $raw = Get-Content -LiteralPath $Source -Raw -ErrorAction Stop
        $safe = Protect-RahText $raw
        $parent = Split-Path -Parent $Destination
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        [IO.File]::WriteAllText($Destination,$safe,(New-Object Text.UTF8Encoding($false)))
        return $true
    } catch { return $false }
}

function Invoke-RahDiagnosticsSelfTest {
    $sample = "PAIR CODE : 123456`n{`"token`":`"topsecret`"}`nauthorization=abc123`nBearer xyz.123"
    $safe = Protect-RahText $sample
    foreach ($secret in @('123456','topsecret','abc123','xyz.123')) {
        if ($safe.Contains($secret)) { throw "SelfTest: redaction leaked $secret" }
    }
    if (-not $safe.Contains('[REDACTED]')) { throw 'SelfTest: redaction marker missing.' }
    if (-not (Test-RahPrivateIPv4 '192.168.1.10')) { throw 'SelfTest: private IPv4 rejected.' }
    if (Test-RahPrivateIPv4 '8.8.8.8') { throw 'SelfTest: public IPv4 accepted.' }
    Write-Host 'PASS: RAH Home Diagnostics v1 self-test' -ForegroundColor Green
}

if ($SelfTest) { Invoke-RahDiagnosticsSelfTest; exit 0 }

$root = [IO.Path]::GetFullPath($InstallRoot)
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$supportRoot = Join-Path $root 'support'
$bundleDir = Join-Path $supportRoot ("bundle-$stamp")
$filesDir = Join-Path $bundleDir 'files'
New-Item -ItemType Directory -Path $filesDir -Force | Out-Null

$collectionErrors = @()
function Add-RahCollectionError { param([string]$Name,[string]$Message) $script:collectionErrors += [pscustomobject]@{collector=$Name;message=(Protect-RahText $Message)} }

$os = $null
try {
    $o = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $os = [pscustomobject]@{caption=[string]$o.Caption;version=[string]$o.Version;buildNumber=[string]$o.BuildNumber;architecture=[string]$o.OSArchitecture}
} catch { Add-RahCollectionError 'os' $_.Exception.Message }

$computer = $null
try {
    $c = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $computer = [pscustomobject]@{manufacturer=[string]$c.Manufacturer;model=[string]$c.Model;totalPhysicalMemory=[int64]$c.TotalPhysicalMemory}
} catch { Add-RahCollectionError 'computer' $_.Exception.Message }

$network = $null; try { $network = Get-RahNetworkSummary } catch { Add-RahCollectionError 'network' $_.Exception.Message }
$firewall = $null; try { $firewall = Get-RahFirewallSummary } catch { Add-RahCollectionError 'firewall' $_.Exception.Message }
$task = $null; try { $task = Get-RahTaskSummary } catch { Add-RahCollectionError 'task' $_.Exception.Message }
$state = $null; try { $state = Get-RahStateSummary $root } catch { Add-RahCollectionError 'state' $_.Exception.Message }
$inventory = @(); try { $inventory = @(Get-RahFileInventory $root) } catch { Add-RahCollectionError 'files' $_.Exception.Message }
$processes = @(); try { $processes = @(Get-RahProcessSummary) } catch { Add-RahCollectionError 'processes' $_.Exception.Message }

$peerStorePath = Join-Path $env:LOCALAPPDATA 'RAH\home-node-peers.json'
$peerStorePresent = Test-Path -LiteralPath $peerStorePath -PathType Leaf

$python = @(
    (Get-RahCommandVersion 'python' @('--version')),
    (Get-RahCommandVersion 'py' @('-3','--version'))
)

$allowedFiles = @(
    @{Rel='RAH-HOME-FINAL-REPORT.txt';Name='RAH-HOME-FINAL-REPORT.txt'},
    @{Rel='RAH-HOME-ACCEPTANCE.txt';Name='RAH-HOME-ACCEPTANCE.txt'},
    @{Rel='RAH-PYTHON-CONSOLE-GUARD.txt';Name='RAH-PYTHON-CONSOLE-GUARD.txt'},
    @{Rel='reports\rah-home-finalize-latest.json';Name='rah-home-finalize-latest.json'},
    @{Rel='reports\rah-home-acceptance-latest.json';Name='rah-home-acceptance-latest.json'},
    @{Rel='reports\rah-python-console-guard-latest.json';Name='rah-python-console-guard-latest.json'},
    @{Rel='logs\worker-agent.log';Name='worker-agent.log'},
    @{Rel='logs\worker-agent.err.log';Name='worker-agent.err.log'}
)
$copied = @()
foreach ($entry in $allowedFiles) {
    $src = Join-Path $root $entry.Rel
    $dst = Join-Path $filesDir $entry.Name
    if (Copy-RahSafeTextFile $src $dst) { $copied += $entry.Name }
}

$doc = [pscustomobject]@{
    schema='rah-home-diagnostics'
    version=1
    diagnosticsVersion=$script:RahHomeDiagnosticsVersion
    createdAt=(Get-Date).ToUniversalTime().ToString('o')
    reason=(Protect-RahText $Reason)
    computerName=$env:COMPUTERNAME
    installRoot=$root
    administrator=[bool](Test-RahAdministrator)
    powershellVersion=$PSVersionTable.PSVersion.ToString()
    pythonBasicRepl=[string]$env:PYTHON_BASIC_REPL
    os=$os
    computer=$computer
    python=@($python)
    network=$network
    firewall=$firewall
    scheduledTask=$task
    installState=$state
    files=@($inventory)
    rahProcesses=@($processes)
    peerStorePresent=[bool]$peerStorePresent
    peerStoreContentCollected=$false
    sanitizedFiles=@($copied)
    collectionErrors=@($collectionErrors)
}

$jsonPath = Join-Path $bundleDir 'RAH-HOME-DIAGNOSTICS.json'
$txtPath = Join-Path $bundleDir 'RAH-HOME-DIAGNOSTICS.txt'
[IO.File]::WriteAllText($jsonPath,($doc | ConvertTo-Json -Depth 10),(New-Object Text.UTF8Encoding($false)))

$lines = @(
    'RAH HOME BLACK BOX',
    '==================',
    "Computer : $env:COMPUTERNAME",
    "Reason   : $(Protect-RahText $Reason)",
    "Created  : $($doc.createdAt)",
    "Root     : $root",
    "Admin    : $($doc.administrator)",
    "PS       : $($doc.powershellVersion)",
    "PyREPL   : $($doc.pythonBasicRepl)",
    "Peer DB  : present=$peerStorePresent; raw-content-collected=False",
    ''
)
foreach ($p in $python) { $lines += "Python   : $($p.name) found=$($p.found) version=$($p.version)" }
$lines += "Files    : $(@($inventory | Where-Object present).Count) present / $($inventory.Count) checked"
$lines += "Logs     : $($copied -join ', ')"
$lines += "Errors   : $($collectionErrors.Count) collector error(s)"
if ($collectionErrors.Count) { foreach ($e in $collectionErrors) { $lines += "  - $($e.collector): $($e.message)" } }
[IO.File]::WriteAllLines($txtPath,$lines,(New-Object Text.UTF8Encoding($false)))

$zipPath = Join-Path $supportRoot ("RAH-HOME-SUPPORT-$stamp.zip")
if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
    Compress-Archive -Path (Join-Path $bundleDir '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
} else {
    Add-RahCollectionError 'zip' 'Compress-Archive is unavailable.'
    $zipPath = $null
}

$latest = [pscustomobject]@{schema='rah-home-support-latest';version=1;createdAt=$doc.createdAt;bundleDirectory=$bundleDir;zipPath=$zipPath;diagnosticsJson=$jsonPath;diagnosticsText=$txtPath}
$latestPath = Join-Path $supportRoot 'rah-home-support-latest.json'
[IO.File]::WriteAllText($latestPath,($latest | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))

Write-Host '=============================================================' -ForegroundColor Yellow
Write-Host 'RAH HOME BLACK BOX: READY' -ForegroundColor Yellow
Write-Host "TXT : $txtPath"
Write-Host "JSON: $jsonPath"
if ($zipPath) { Write-Host "ZIP : $zipPath" -ForegroundColor Cyan }
Write-Host 'Secrets: PAIR CODE/token/secret/Bearer redaction enabled.' -ForegroundColor Green
Write-Host 'Peer token store: raw content was NOT collected.' -ForegroundColor Green
Write-Host '=============================================================' -ForegroundColor Yellow
exit 0

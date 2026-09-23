param(
    [switch]$JsonOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version = '7.0.0-foundation'
$script:RahRoot = 'C:\RAH'
$script:CoreRoot = 'C:\RAH\RavenCore7'
$script:StateRoot = Join-Path $script:CoreRoot 'state'
$script:AcceptanceFile = Join-Path $script:StateRoot 'acceptance.json'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force -Path $script:CoreRoot,$script:StateRoot | Out-Null
$script:Results = New-Object System.Collections.Generic.List[object]

function Add-AcceptanceResult {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][ValidateSet('PASS','WARN','INFO','FAIL')][string]$Status,
        [Parameter(Mandatory=$true)][string]$Detail
    )
    $script:Results.Add([pscustomobject][ordered]@{
        name = $Name
        status = $Status
        detail = $Detail
    }) | Out-Null
}

function Find-RahFile {
    param([Parameter(Mandatory=$true)][string]$Name)
    foreach($root in @(
        $PSScriptRoot,
        $script:CoreRoot,
        $script:RahRoot,
        'C:\RAH\RavenOS',
        'C:\RAH\rah-platform',
        'C:\RAH\RAH-Platform',
        'C:\RAH\2PCProof',
        'C:\RAH\AI-Fabric'
    )){
        if([string]::IsNullOrWhiteSpace($root)){ continue }
        $candidate = Join-Path $root $Name
        if(Test-Path -LiteralPath $candidate -PathType Leaf){
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    return $null
}

function Test-LocalPort {
    param([int]$Port)
    try {
        $client = New-Object Net.Sockets.TcpClient
        $iar = $client.BeginConnect('127.0.0.1',$Port,$null,$null)
        $ok = $iar.AsyncWaitHandle.WaitOne(500,$false)
        if($ok -and $client.Connected){
            $client.EndConnect($iar)
            $client.Close()
            return $true
        }
        $client.Close()
    } catch {}
    return $false
}

function Test-PowerShellParse {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Name)
    try {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $Path,
            [ref]$tokens,
            [ref]$errors
        ) | Out-Null
        if(@($errors).Count -gt 0){
            $detail = (@($errors) | ForEach-Object {
                ('line ' + $_.Extent.StartLineNumber + ': ' + $_.Message)
            }) -join ' | '
            Add-AcceptanceResult $Name 'FAIL' $detail
        } else {
            Add-AcceptanceResult $Name 'PASS' 'PowerShell parser accepted the file.'
        }
    } catch {
        Add-AcceptanceResult $Name 'FAIL' $_.Exception.Message
    }
}

if($PSVersionTable.PSVersion.Major -ge 5){
    Add-AcceptanceResult 'PowerShell' 'PASS' ('Version ' + $PSVersionTable.PSVersion)
} else {
    Add-AcceptanceResult 'PowerShell' 'FAIL' ('Version ' + $PSVersionTable.PSVersion + ' is too old.')
}

$required = @(
    'RAVEN-CORE-7.ps1',
    'RAVEN-CORE-7-CONFIG.json',
    'START-HER.cmd',
    'DIAGNOSTICS.cmd',
    'REPAIR.cmd'
)
foreach($name in $required){
    $path = Find-RahFile $name
    if($path){ Add-AcceptanceResult ('File: ' + $name) 'PASS' $path }
    else { Add-AcceptanceResult ('File: ' + $name) 'FAIL' 'Required Core 7 file was not found.' }
}

$coreScript = Find-RahFile 'RAVEN-CORE-7.ps1'
if($coreScript){ Test-PowerShellParse -Path $coreScript -Name 'Core 7 PowerShell syntax' }

$selfPath = Find-RahFile 'RAVEN-CORE-7-ACCEPTANCE.ps1'
if($selfPath){ Test-PowerShellParse -Path $selfPath -Name 'Acceptance PowerShell syntax' }

$configPath = Find-RahFile 'RAVEN-CORE-7-CONFIG.json'
if($configPath){
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -ErrorAction Stop
        $policy = $config.policy
        $bad = @()
        foreach($pair in @(
            @('arbitraryShell',$policy.arbitraryShell),
            @('backgroundNetworkDiscovery',$policy.backgroundNetworkDiscovery),
            @('automaticFirewallChanges',$policy.automaticFirewallChanges),
            @('persistNodeTokens',$policy.persistNodeTokens),
            @('automaticRemoteNodeStart',$policy.automaticRemoteNodeStart)
        )){
            if([bool]$pair[1]){ $bad += [string]$pair[0] }
        }
        if($bad.Count -gt 0){
            Add-AcceptanceResult 'Core 7 safety policy' 'FAIL' ('Unsafe policy flags enabled: ' + ($bad -join ', '))
        } else {
            Add-AcceptanceResult 'Core 7 safety policy' 'PASS' 'No arbitrary shell, background discovery, firewall automation, token persistence, or remote Node autostart.'
        }
    } catch {
        Add-AcceptanceResult 'Core 7 safety policy' 'FAIL' $_.Exception.Message
    }
}

$frontTest = Find-RahFile 'RAH-OS-SELFTEST.ps1'
if($frontTest){
    try {
        $raw = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $frontTest -Quick -JsonOnly 2>&1
        $exitCode = $LASTEXITCODE
        if($exitCode -eq 0){
            Add-AcceptanceResult 'RAH OS Front Door contract' 'PASS' 'Front Door quick self-test passed.'
        } else {
            Add-AcceptanceResult 'RAH OS Front Door contract' 'FAIL' ('Front Door self-test exit=' + $exitCode + ': ' + (($raw | Out-String).Trim()))
        }
    } catch {
        Add-AcceptanceResult 'RAH OS Front Door contract' 'FAIL' $_.Exception.Message
    }
} else {
    Add-AcceptanceResult 'RAH OS Front Door contract' 'WARN' 'Front Door self-test is not installed on this machine yet.'
}

$registry = Find-RahFile 'RAH-HARDWARE-REGISTRY.ps1'
if($registry){
    try {
        $raw = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $registry -SelfTest 2>&1
        if($LASTEXITCODE -eq 0){
            Add-AcceptanceResult 'Hardware Registry self-test' 'PASS' (($raw | Out-String).Trim())
        } else {
            Add-AcceptanceResult 'Hardware Registry self-test' 'FAIL' ('Exit=' + $LASTEXITCODE + ': ' + (($raw | Out-String).Trim()))
        }
    } catch {
        Add-AcceptanceResult 'Hardware Registry self-test' 'FAIL' $_.Exception.Message
    }
} else {
    Add-AcceptanceResult 'Hardware Registry self-test' 'WARN' 'Hardware Registry script not found.'
}

$memorySync = Find-RahFile 'SYNC-RAH-PROJECT-MEMORY.ps1'
if($memorySync){
    try {
        $raw = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $memorySync -SelfTest 2>&1
        if($LASTEXITCODE -eq 0){
            Add-AcceptanceResult 'Project Memory snapshot self-test' 'PASS' (($raw | Out-String).Trim())
        } else {
            Add-AcceptanceResult 'Project Memory snapshot self-test' 'FAIL' ('Exit=' + $LASTEXITCODE + ': ' + (($raw | Out-String).Trim()))
        }
    } catch {
        Add-AcceptanceResult 'Project Memory snapshot self-test' 'FAIL' $_.Exception.Message
    }
} else {
    Add-AcceptanceResult 'Project Memory snapshot self-test' 'WARN' 'Project Memory sync script not found.'
}

$coreOnline = Test-LocalPort 18765
$nodeOnline = Test-LocalPort 18766
$lmOnline = Test-LocalPort 1234
$anythingOnline = Test-LocalPort 3001

Add-AcceptanceResult 'Raven Core :18765' $(if($coreOnline){'PASS'}else{'WARN'}) $(if($coreOnline){'ONLINE on loopback.'}else{'Offline. Software contract can pass, but runtime start acceptance remains pending.'})
Add-AcceptanceResult 'Node Agent :18766' 'INFO' $(if($nodeOnline){'ONLINE. Explicit startup remains required by design.'}else{'OFFLINE. Explicit startup remains required by design.'})
Add-AcceptanceResult 'LM Studio :1234' 'INFO' $(if($lmOnline){'ONLINE.'}else{'OFFLINE; optional for the foundation acceptance.'})
Add-AcceptanceResult 'AnythingLLM :3001' 'INFO' $(if($anythingOnline){'ONLINE.'}else{'OFFLINE; optional for the foundation acceptance.'})

$grid = Find-RahFile 'START-HER-RAH-2PC-GRID.cmd'
$gridVerify = Find-RahFile 'VERIFY-RAH-2PC-GRID.cmd'
if($grid -and $gridVerify){
    Add-AcceptanceResult '2-PC Grid software' 'PASS' 'Grid and verification launchers are present.'
} else {
    Add-AcceptanceResult '2-PC Grid software' 'WARN' 'One or more 2-PC Grid launchers are not installed locally.'
}

$workerProofPath = 'C:\RAH\RavenCore7\state\worker-proof.json'
$physicalSecondPc = 'EXPLICITLY_PENDING_UNTIL_REAL_HARDWARE_TEST'
if(Test-Path -LiteralPath $workerProofPath -PathType Leaf){
    try {
        $workerProof = Get-Content -LiteralPath $workerProofPath -Raw | ConvertFrom-Json -ErrorAction Stop
        if([string]$workerProof.schema -ne 'rah-raven-core-7-worker-proof-v1'){ throw 'Unexpected Worker Proof schema.' }
        if($workerProof.accepted -eq $true -and [string]$workerProof.state -eq 'PASS'){
            if($workerProof.safety.tokenStored -ne $false -or $workerProof.safety.tokenRead -ne $false -or
               $workerProof.safety.arbitraryShell -ne $false -or $workerProof.safety.networkDiscovery -ne $false){
                throw 'Worker Proof safety flags failed.'
            }
            $physicalSecondPc = 'PASS'
            Add-AcceptanceResult 'Physical second-PC acceptance' 'PASS' ('Validated Worker Proof for ' + [string]$workerProof.worker.hostname + '.')
        } elseif([string]$workerProof.state -eq 'INVALID'){
            Add-AcceptanceResult 'Physical second-PC acceptance' 'FAIL' 'Worker Proof exists but evidence is invalid.'
        } else {
            Add-AcceptanceResult 'Physical second-PC acceptance' 'INFO' 'Worker Proof exists but real hardware is still pending.'
        }
    } catch {
        Add-AcceptanceResult 'Physical second-PC acceptance' 'FAIL' ('Worker Proof could not be validated: ' + $_.Exception.Message)
    }
} else {
    Add-AcceptanceResult 'Physical second-PC acceptance' 'INFO' 'Not inferred. Requires an explicitly enrolled second PC and a real fixed-capability round trip; this acceptance file does not fake that PASS.'
}

$failCount = @($script:Results | Where-Object status -eq 'FAIL').Count
$warnCount = @($script:Results | Where-Object status -eq 'WARN').Count
$summary = [pscustomobject][ordered]@{
    schema = 'rah-raven-core-7-acceptance-v1'
    version = $script:Version
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    computer = $env:COMPUTERNAME
    result = $(if($failCount -gt 0){'FAIL'}elseif($warnCount -gt 0){'PASS-WITH-WARNINGS'}else{'PASS'})
    failCount = $failCount
    warnCount = $warnCount
    checks = @($script:Results)
    physicalSecondPcAcceptance = $physicalSecondPc
    safety = @(
        'No arbitrary shell',
        'No background network discovery',
        'No automatic firewall changes',
        'No Node token persistence',
        'No automatic remote Node startup'
    )
}

$tmp = $script:AcceptanceFile + '.tmp'
[IO.File]::WriteAllText($tmp,(($summary | ConvertTo-Json -Depth 10) + [Environment]::NewLine),$script:Utf8)
Move-Item -LiteralPath $tmp -Destination $script:AcceptanceFile -Force

if($JsonOnly){
    $summary | ConvertTo-Json -Depth 10
} else {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkYellow
    Write-Host '          RAH RAVEN CORE 7.0 - ACCEPTANCE' -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor DarkYellow
    foreach($r in $script:Results){
        $color = switch($r.status){ 'PASS' {'Green'} 'WARN' {'Yellow'} 'FAIL' {'Red'} default {'Gray'} }
        Write-Host (('{0,-5} {1,-34} {2}' -f $r.status,$r.name,$r.detail)) -ForegroundColor $color
    }
    Write-Host ''
    Write-Host ('RESULT: ' + $summary.result + ' | FAIL=' + $failCount + ' WARN=' + $warnCount) -ForegroundColor $(if($failCount){'Red'}elseif($warnCount){'Yellow'}else{'Green'})
    Write-Host ('Report: ' + $script:AcceptanceFile) -ForegroundColor DarkGray
}

if($failCount -gt 0){ exit 1 }
exit 0

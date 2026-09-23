param(
    [switch]$JsonOnly,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version = '0.6.0-candidate'
$script:RahRoot = 'C:\RAH'
$script:OsRoot = 'C:\RAH\RavenOS'
$script:StateRoot = 'C:\RAH\RavenOS\state'
$script:StateFile = Join-Path $script:StateRoot 'RAH-OS-ACCEPTANCE.json'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

function Test-LocalPort {
    param([int]$Port)
    try {
        $client = New-Object Net.Sockets.TcpClient
        $iar = $client.BeginConnect('127.0.0.1',$Port,$null,$null)
        $ok = $iar.AsyncWaitHandle.WaitOne(400,$false)
        if($ok -and $client.Connected){
            $client.EndConnect($iar)
            $client.Close()
            return $true
        }
        $client.Close()
    } catch {}
    return $false
}

function Read-JsonFile {
    param([string]$Path)
    if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return $null }
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { return $null }
}

function New-Area {
    param(
        [string]$Name,
        [ValidateSet('PASS','PENDING','FAIL')][string]$Status,
        [string]$Detail,
        [object]$Evidence = $null
    )
    [pscustomobject][ordered]@{
        name = $Name
        status = $Status
        detail = $Detail
        evidence = $Evidence
    }
}

function Resolve-Overall {
    param([object[]]$Areas)
    if(@($Areas | Where-Object status -eq 'FAIL').Count -gt 0){ return 'FAIL' }
    if(@($Areas | Where-Object status -ne 'PASS').Count -eq 0){ return 'PASS' }
    return 'PENDING'
}

if($SelfTest){
    $allPass = @(
        (New-Area 'A' 'PASS' 'ok'),
        (New-Area 'B' 'PASS' 'ok')
    )
    $withWarn = @(
        (New-Area 'A' 'PASS' 'ok'),
        (New-Area 'B' 'PENDING' 'pending')
    )
    $withFail = @(
        (New-Area 'A' 'PASS' 'ok'),
        (New-Area 'B' 'FAIL' 'bad')
    )
    if((Resolve-Overall $allPass) -ne 'PASS'){ throw 'PASS resolution self-test failed.' }
    if((Resolve-Overall $withWarn) -ne 'PENDING'){ throw 'PENDING resolution self-test failed.' }
    if((Resolve-Overall $withFail) -ne 'FAIL'){ throw 'FAIL resolution self-test failed.' }
    if($script:Version -ne '0.6.0-candidate'){ throw 'Version self-test failed.' }
    Write-Host 'PASS: RAH OS v0.6 acceptance self-test' -ForegroundColor Green
    exit 0
}

New-Item -ItemType Directory -Force -Path $script:StateRoot | Out-Null
$areas = New-Object System.Collections.Generic.List[object]

# 1) Front Door
$frontDoorRequired = @(
    'START-HER-RAH-OS.cmd',
    'RAH-OS-CONTROL.ps1',
    'RAH-OS-SELFTEST.ps1',
    'REPAIR-RAH-OS.cmd',
    'ACCEPT-RAH-OS-v0.6.cmd',
    'ACCEPT-RAH-OS-v0.6.ps1',
    'RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd',
    'RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1'
)
$missingFrontDoor = @()
foreach($name in $frontDoorRequired){
    if(-not (Test-Path -LiteralPath (Join-Path $script:OsRoot $name) -PathType Leaf)){
        $missingFrontDoor += $name
    }
}
if($missingFrontDoor.Count -eq 0){
    $areas.Add((New-Area 'Front Door' 'PASS' 'Required v0.6 Front Door files are installed.' $frontDoorRequired)) | Out-Null
} else {
    $areas.Add((New-Area 'Front Door' 'FAIL' ('Missing required files: ' + ($missingFrontDoor -join ', ')) $missingFrontDoor)) | Out-Null
}

# 2) Raven Core 7
$coreStatusPath = 'C:\RAH\RavenCore7\state\status.json'
$coreStatus = Read-JsonFile $coreStatusPath
$coreLauncher = Test-Path -LiteralPath 'C:\RAH\START-HER.cmd' -PathType Leaf
$coreOnline = Test-LocalPort 18765
if($coreStatus -and ([string]$coreStatus.overall -eq 'PASS')){
    $areas.Add((New-Area 'Raven Core' 'PASS' 'Core 7 status evidence is PASS.' @{
        statusPath = $coreStatusPath
        ravenPort18765 = $coreOnline
    })) | Out-Null
} elseif($coreOnline){
    $areas.Add((New-Area 'Raven Core' 'PASS' 'Raven Core is online on loopback; Core 7 status evidence is not PASS yet.' @{
        statusPath = $coreStatusPath
        ravenPort18765 = $true
    })) | Out-Null
} elseif($coreLauncher){
    $areas.Add((New-Area 'Raven Core' 'PENDING' 'Core 7 launcher exists, but Raven Core is not currently verified online.' @{
        launcher = 'C:\RAH\START-HER.cmd'
        ravenPort18765 = $false
    })) | Out-Null
} else {
    $areas.Add((New-Area 'Raven Core' 'PENDING' 'Raven Core 7 is not installed or not visible to RAH OS.' $null)) | Out-Null
}

# 3) Local AI
$lmOnline = Test-LocalPort 1234
$ollamaOnline = Test-LocalPort 11434
$aiLatestPath = 'C:\RAH\Status\AI-SELF-CHECK-LATEST.txt'
$aiLatest = if(Test-Path -LiteralPath $aiLatestPath -PathType Leaf){ Get-Content -LiteralPath $aiLatestPath -Raw }else{ '' }
$aiLauncher = Test-Path -LiteralPath 'C:\RAH\RAVEN-AI-SELF-CHECK.cmd' -PathType Leaf
if($aiLatest -match '(?im)^FINAL\s+:\s+PASS\s*$'){
    $areas.Add((New-Area 'Local AI' 'PASS' 'Latest Raven AI Self-Check is PASS.' @{
        lmStudio1234 = $lmOnline
        ollama11434 = $ollamaOnline
        latest = $aiLatestPath
    })) | Out-Null
} elseif($lmOnline -or $ollamaOnline){
    $areas.Add((New-Area 'Local AI' 'PENDING' 'A local AI endpoint is online, but the full Raven AI Self-Check is not PASS yet.' @{
        lmStudio1234 = $lmOnline
        ollama11434 = $ollamaOnline
    })) | Out-Null
} elseif($aiLauncher){
    $areas.Add((New-Area 'Local AI' 'PENDING' 'AI Self-Check launcher is installed; run it to verify inference and Project Memory.' @{
        launcher = 'C:\RAH\RAVEN-AI-SELF-CHECK.cmd'
    })) | Out-Null
} else {
    $areas.Add((New-Area 'Local AI' 'PENDING' 'No verified local AI endpoint or AI Self-Check launcher was found.' $null)) | Out-Null
}

# 4) AnythingLLM approval
$anythingReportPath = 'C:\RAH\AI-Fabric\anythingllm-approval-test.json'
$anythingReport = Read-JsonFile $anythingReportPath
$anythingLauncher = Test-Path -LiteralPath 'C:\RAH\START-HER-ANYTHINGLLM-APPROVAL.cmd' -PathType Leaf
if($anythingReport -and ([string]$anythingReport.overall -eq 'PASS') -and ($anythingReport.secretIncluded -eq $false)){
    $areas.Add((New-Area 'AnythingLLM' 'PASS' 'AnythingLLM approval acceptance report is PASS.' @{
        report = $anythingReportPath
        workspace = [string]$anythingReport.workspace
        approvalSource = [string]$anythingReport.approvalSource
    })) | Out-Null
} elseif($anythingLauncher){
    $areas.Add((New-Area 'AnythingLLM' 'PENDING' 'Approval launcher is installed, but a full PASS report is not present yet.' @{
        launcher = 'C:\RAH\START-HER-ANYTHINGLLM-APPROVAL.cmd'
        report = $anythingReportPath
    })) | Out-Null
} else {
    $areas.Add((New-Area 'AnythingLLM' 'PENDING' 'AnythingLLM approval gate is not installed or not yet configured.' $null)) | Out-Null
}

# 5) Worker Proof
$workerPath = 'C:\RAH\RavenCore7\state\worker-proof.json'
$worker = Read-JsonFile $workerPath
$workerLauncher = Test-Path -LiteralPath 'C:\RAH\WORKER-PROOF.cmd' -PathType Leaf
if($worker -and ([string]$worker.state -eq 'PASS') -and ($worker.accepted -eq $true)){
    $areas.Add((New-Area 'Worker Proof' 'PASS' 'Validated real-hardware Worker Proof is PASS.' @{
        report = $workerPath
        hostname = [string]$worker.worker.hostname
    })) | Out-Null
} elseif($worker -and ([string]$worker.state -in @('FAIL','INVALID'))){
    $areas.Add((New-Area 'Worker Proof' 'FAIL' ('Worker Proof state is ' + [string]$worker.state + ': ' + [string]$worker.detail) @{
        report = $workerPath
    })) | Out-Null
} elseif($workerLauncher){
    $areas.Add((New-Area 'Worker Proof' 'PENDING' 'Worker Proof launcher is installed; physical 2-PC proof is still pending.' @{
        launcher = 'C:\RAH\WORKER-PROOF.cmd'
        report = $workerPath
    })) | Out-Null
} else {
    $areas.Add((New-Area 'Worker Proof' 'PENDING' 'Worker Proof is not installed or no proof has been recorded.' $null)) | Out-Null
}

$overall = Resolve-Overall @($areas)
$doc = [pscustomobject][ordered]@{
    schema = 'rah-os-v0.6-acceptance'
    version = 1
    candidate = $script:Version
    computer = $env:COMPUTERNAME
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    overall = $overall
    areas = @($areas)
    safety = [pscustomobject][ordered]@{
        arbitraryShell = $false
        firewallChanges = $false
        networkDiscovery = $false
        nodeTokenRead = $false
        nodeTokenStored = $false
        remoteActionAdded = $false
        writesLimitedToAcceptanceState = $true
    }
}

$tmp = $script:StateFile + '.tmp'
[IO.File]::WriteAllText($tmp,(($doc | ConvertTo-Json -Depth 12) + [Environment]::NewLine),$script:Utf8)
Move-Item -LiteralPath $tmp -Destination $script:StateFile -Force

if($JsonOnly){
    $doc | ConvertTo-Json -Depth 12
} else {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkYellow
    Write-Host '              RAH OS v0.6 ACCEPTANCE' -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor DarkYellow
    foreach($area in @($areas)){
        $color = switch([string]$area.status){ 'PASS' {'Green'} 'PENDING' {'Yellow'} 'FAIL' {'Red'} default {'Gray'} }
        Write-Host (('{0,-5} {1,-16} {2}' -f $area.status,$area.name,$area.detail)) -ForegroundColor $color
    }
    Write-Host ''
    $overallColor = switch($overall){ 'PASS' {'Green'} 'FAIL' {'Red'} default {'Yellow'} }
    Write-Host ('RAH OS v0.6: ' + $overall) -ForegroundColor $overallColor
    Write-Host ('State file: ' + $script:StateFile) -ForegroundColor DarkGray
}

if($overall -eq 'FAIL'){ exit 1 }
if($overall -eq 'PENDING'){ exit 2 }
exit 0

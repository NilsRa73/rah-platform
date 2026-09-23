param(
    [switch]$Quick,
    [switch]$RepairFrontDoor,
    [switch]$JsonOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RahRoot = 'C:\RAH'
$OsRoot = 'C:\RAH\RavenOS'
$SourceRef = 'main'
$RawBase = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/' + $SourceRef
$FrontDoorFiles = @(
    'START-HER-RAH-OS.cmd',
    'INSTALL-RAH-OS.cmd',
    'REPAIR-RAH-OS.cmd',
    'RAH-OS-CONTROL.ps1',
    'RAH-OS-SELFTEST.ps1',
    'ACCEPT-RAH-OS-v0.6.cmd',
    'ACCEPT-RAH-OS-v0.6.ps1',
    'RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd',
    'RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1',
    'RAH-OS.md'
)

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][ValidateSet('PASS','WARN','INFO','FAIL')][string]$Status,
        [Parameter(Mandatory=$true)][string]$Detail
    )
    $results.Add([pscustomobject][ordered]@{
        name = $Name
        status = $Status
        detail = $Detail
    }) | Out-Null
}

function Find-RahFile {
    param([Parameter(Mandatory=$true)][string]$Name)
    $roots = @(
        $PSScriptRoot,
        $OsRoot,
        'C:\RAH',
        'C:\RAH\RavenCore7',
        'C:\RAH\rah-platform',
        'C:\RAH\RAH-Platform',
        'C:\RAH\2PCProof',
        'C:\RAH\raven-command-core\desktop-bridge',
        'C:\RAH\RavenCommand\desktop-bridge'
    )
    foreach($root in $roots){
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
        $ok = $iar.AsyncWaitHandle.WaitOne(350,$false)
        if($ok -and $client.Connected){
            $client.EndConnect($iar)
            $client.Close()
            return $true
        }
        $client.Close()
    } catch {}
    return $false
}

if($RepairFrontDoor){
    New-Item -ItemType Directory -Force -Path $OsRoot | Out-Null
    foreach($file in $FrontDoorFiles){
        if($file -eq 'RAH-OS-SELFTEST.ps1'){ continue }
        $uri = $RawBase + '/' + $file
        $dst = Join-Path $OsRoot $file
        $tmp = $dst + '.download'
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $tmp
            if((Get-Item -LiteralPath $tmp).Length -lt 20){ throw 'download too small' }
            Move-Item -LiteralPath $tmp -Destination $dst -Force
            Add-Result ('repair:' + $file) 'PASS' ('Refreshed from fixed repository path at ref ' + $SourceRef + '.')
        } catch {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            Add-Result ('repair:' + $file) 'FAIL' $_.Exception.Message
        }
    }
}

if($PSVersionTable.PSVersion.Major -ge 5){
    Add-Result 'PowerShell' 'PASS' ('Version ' + $PSVersionTable.PSVersion)
} else {
    Add-Result 'PowerShell' 'FAIL' ('Version ' + $PSVersionTable.PSVersion + ' is too old.')
}

try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Result 'WPF' 'PASS' 'PresentationFramework loaded.'
} catch {
    Add-Result 'WPF' 'FAIL' $_.Exception.Message
}

$launcher = Find-RahFile 'START-HER-RAH-OS.cmd'
$control = Find-RahFile 'RAH-OS-CONTROL.ps1'
$self = Find-RahFile 'RAH-OS-SELFTEST.ps1'
$repair = Find-RahFile 'REPAIR-RAH-OS.cmd'
$acceptCmd = Find-RahFile 'ACCEPT-RAH-OS-v0.6.cmd'
$acceptPs = Find-RahFile 'ACCEPT-RAH-OS-v0.6.ps1'
$hovedCmd = Find-RahFile 'RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd'
$hovedPs = Find-RahFile 'RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1'

foreach($entry in @(
    @('Front Door launcher',$launcher),
    @('Control panel',$control),
    @('Self-test',$self),
    @('Repair launcher',$repair),
    @('v0.6 acceptance launcher',$acceptCmd),
    @('v0.6 acceptance engine',$acceptPs),
    @('HOVED-PC acceptance launcher',$hovedCmd),
    @('HOVED-PC acceptance engine',$hovedPs)
)){
    if($entry[1]){
        Add-Result $entry[0] 'PASS' $entry[1]
    } else {
        Add-Result $entry[0] 'FAIL' 'Required Front Door file was not found.'
    }
}

if(-not $Quick){
    $core = Test-LocalPort 18765
    $node = Test-LocalPort 18766
    $bridge = Test-LocalPort 47824
    $lmstudio = Test-LocalPort 1234
    $ollama = Test-LocalPort 11434
    Add-Result 'Raven Core :18765' $(if($core){'PASS'}else{'INFO'}) $(if($core){'ONLINE on loopback.'}else{'Offline; Start Local Core when needed.'})
    Add-Result 'Node Agent :18766' 'INFO' $(if($node){'ONLINE. Explicit startup remains required.'}else{'Offline; this is expected until explicitly started.'})
    Add-Result 'Desktop Bridge :47824' $(if($bridge){'PASS'}else{'INFO'}) $(if($bridge){'ONLINE on loopback.'}else{'Offline; Raven Workspace can start it.'})
    Add-Result 'LM Studio :1234' $(if($lmstudio){'PASS'}else{'INFO'}) $(if($lmstudio){'ONLINE on loopback.'}else{'Offline; optional until local AI is needed.'})
    Add-Result 'Ollama :11434' $(if($ollama){'PASS'}else{'INFO'}) $(if($ollama){'ONLINE on loopback.'}else{'Offline; optional.'})

    $workspace = Find-RahFile 'Start RAH Workspace.cmd'
    if($workspace){ Add-Result 'Raven Workspace launcher' 'PASS' $workspace }
    else { Add-Result 'Raven Workspace launcher' 'WARN' 'Start RAH Workspace.cmd not found in known RAH roots.' }

    $core7 = Find-RahFile 'START-HER.cmd'
    $core7Diag = Find-RahFile 'DIAGNOSTICS.cmd'
    $workerProof = Find-RahFile 'WORKER-PROOF.cmd'
    $aiSelfCheck = Find-RahFile 'RAVEN-AI-SELF-CHECK.cmd'
    $anythingApproval = Find-RahFile 'START-HER-ANYTHINGLLM-APPROVAL.cmd'
    if($core7){ Add-Result 'Raven Core 7 launcher' 'PASS' $core7 }
    else { Add-Result 'Raven Core 7 launcher' 'WARN' 'START-HER.cmd not found; Core 7 is not installed yet.' }
    if($core7Diag){ Add-Result 'Raven Core 7 diagnostics' 'PASS' $core7Diag }
    else { Add-Result 'Raven Core 7 diagnostics' 'WARN' 'DIAGNOSTICS.cmd not found.' }
    if($workerProof){ Add-Result 'Raven Core 7 Worker Proof' 'PASS' $workerProof }
    else { Add-Result 'Raven Core 7 Worker Proof' 'INFO' 'WORKER-PROOF.cmd not installed yet.' }
    if($aiSelfCheck){ Add-Result 'Raven AI Self-Check' 'PASS' $aiSelfCheck }
    else { Add-Result 'Raven AI Self-Check' 'WARN' 'RAVEN-AI-SELF-CHECK.cmd not found; repair/update AI Fabric.' }
    if($anythingApproval){ Add-Result 'AnythingLLM approval gate' 'PASS' $anythingApproval }
    else { Add-Result 'AnythingLLM approval gate' 'INFO' 'START-HER-ANYTHINGLLM-APPROVAL.cmd not found; only needed for approval acceptance.' }
    $workerProofState = 'C:\RAH\RavenCore7\state\worker-proof.json'
    if(Test-Path -LiteralPath $workerProofState -PathType Leaf){ Add-Result 'Worker Proof state' 'PASS' $workerProofState }
    else { Add-Result 'Worker Proof state' 'INFO' 'Physical Worker proof has not been recorded yet.' }
    $core7Status = 'C:\RAH\RavenCore7\state\status.json'
    if(Test-Path -LiteralPath $core7Status -PathType Leaf){ Add-Result 'Raven Core 7 status' 'PASS' $core7Status }
    else { Add-Result 'Raven Core 7 status' 'INFO' 'Core 7 status.json will appear after first Core 7 run.' }

    foreach($name in @(
        'START-RAH-AI-FABRIC.cmd',
        'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat',
        'START-HER-RAH-2PC-GRID.cmd',
        'VERIFY-RAH-2PC-GRID.cmd'
    )){
        $path = Find-RahFile $name
        if($path){ Add-Result $name 'PASS' $path }
        else { Add-Result $name 'WARN' 'Not found in known RAH roots.' }
    }

    if(Test-Path -LiteralPath 'C:\RAH\HardwareRegistry\registry.json' -PathType Leaf){
        Add-Result 'Hardware Registry' 'PASS' 'registry.json found.'
    } else {
        Add-Result 'Hardware Registry' 'WARN' 'Not built yet.'
    }

    if(Test-Path -LiteralPath 'C:\RAH\CONFIGURE-RAH-PROJECT-MEMORY.cmd' -PathType Leaf){
        Add-Result 'Project Memory' 'PASS' 'Configuration launcher found.'
    } else {
        Add-Result 'Project Memory' 'WARN' 'Configuration launcher not found.'
    }
}

$failCount = @($results | Where-Object status -eq 'FAIL').Count
$warnCount = @($results | Where-Object status -eq 'WARN').Count
$summary = [pscustomobject][ordered]@{
    schema = 'rah-os-selftest'
    version = 1
    computer = $env:COMPUTERNAME
    timestamp = (Get-Date).ToString('o')
    result = $(if($failCount -gt 0){'FAIL'}elseif($warnCount -gt 0){'PASS-WITH-WARNINGS'}else{'PASS'})
    failCount = $failCount
    warnCount = $warnCount
    checks = @($results)
    safety = @(
        'No arbitrary shell',
        'No background discovery',
        'No firewall changes',
        'No Node token persistence',
        'No automatic remote Node startup'
    )
}

if($JsonOnly){
    $summary | ConvertTo-Json -Depth 5
} else {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkYellow
    Write-Host '              RAH RAVEN OS - SELF TEST' -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor DarkYellow
    foreach($r in $results){
        $color = switch($r.status){ 'PASS' {'Green'} 'WARN' {'Yellow'} 'FAIL' {'Red'} default {'Gray'} }
        Write-Host (('{0,-5} {1,-34} {2}' -f $r.status,$r.name,$r.detail)) -ForegroundColor $color
    }
    Write-Host ''
    Write-Host ('RESULT: ' + $summary.result + ' | FAIL=' + $failCount + ' WARN=' + $warnCount) -ForegroundColor $(if($failCount){'Red'}elseif($warnCount){'Yellow'}else{'Green'})
}

if($failCount -gt 0){ exit 1 }
exit 0

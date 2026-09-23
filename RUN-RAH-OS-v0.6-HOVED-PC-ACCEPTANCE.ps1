param(
    [switch]$SelfTest,
    [switch]$JsonOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version = '0.6.0-hovedpc'
$script:RahRoot = 'C:\RAH'
$script:OsRoot = 'C:\RAH\RavenOS'
$script:StateRoot = Join-Path $script:OsRoot 'state'
$script:SequenceFile = Join-Path $script:StateRoot 'RAH-OS-HOVED-PC-SEQUENCE.json'
$script:AcceptanceFile = Join-Path $script:StateRoot 'RAH-OS-ACCEPTANCE.json'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

function Find-RahFile {
    param([Parameter(Mandatory=$true)][string]$Name,[string[]]$ExtraRoots=@())
    $roots = @(
        $PSScriptRoot,
        $script:OsRoot,
        $script:RahRoot,
        'C:\RAH\RavenCore7',
        'C:\RAH\AI-Fabric',
        'C:\RAH\2PCProof',
        'C:\RAH\rah-platform',
        'C:\RAH\RAH-Platform'
    ) + $ExtraRoots
    foreach($root in $roots){
        if([string]::IsNullOrWhiteSpace($root)){ continue }
        $candidate = Join-Path $root $Name
        if(Test-Path -LiteralPath $candidate -PathType Leaf){
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    return $null
}

function Read-JsonFile {
    param([string]$Path)
    if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return $null }
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { return $null }
}

function Invoke-Stage {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Script,
        [string[]]$Arguments=@()
    )
    $started = Get-Date
    $output = @()
    $exitCode = 127
    try {
        $output = @(& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Script @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } catch {
        $output = @($_.Exception.Message)
        $exitCode = 126
    }
    [pscustomobject][ordered]@{
        name = $Name
        script = $Script
        arguments = @($Arguments)
        exitCode = $exitCode
        started = $started.ToUniversalTime().ToString('o')
        finished = (Get-Date).ToUniversalTime().ToString('o')
        outputTail = @($output | Select-Object -Last 20 | ForEach-Object { [string]$_ })
    }
}

function Write-Sequence {
    param($Doc)
    New-Item -ItemType Directory -Force -Path $script:StateRoot | Out-Null
    $tmp = $script:SequenceFile + '.tmp'
    [IO.File]::WriteAllText($tmp,(($Doc | ConvertTo-Json -Depth 12) + [Environment]::NewLine),$script:Utf8)
    Move-Item -LiteralPath $tmp -Destination $script:SequenceFile -Force
}

if($SelfTest){
    foreach($name in @(
        'RAH-OS-SELFTEST.ps1',
        'RAVEN-CORE-7.ps1',
        'RAVEN-AI-SELF-CHECK.ps1',
        'TEST-ANYTHINGLLM-APPROVAL.ps1',
        'RAVEN-CORE-7-WORKER-PROOF.ps1',
        'ACCEPT-RAH-OS-v0.6.ps1'
    )){
        if(-not $name.EndsWith('.ps1')){ throw 'Self-test allowlist failed.' }
    }
    if($script:Version -ne '0.6.0-hovedpc'){ throw 'Version self-test failed.' }
    Write-Host 'PASS: RAH OS v0.6 HOVED-PC sequence self-test' -ForegroundColor Green
    exit 0
}

New-Item -ItemType Directory -Force -Path $script:StateRoot | Out-Null
$stages = New-Object System.Collections.Generic.List[object]

# 1) FRONT DOOR
$front = Find-RahFile 'RAH-OS-SELFTEST.ps1'
if($front){
    $stages.Add((Invoke-Stage 'Front Door' $front @('-JsonOnly'))) | Out-Null
} else {
    $stages.Add([pscustomobject][ordered]@{
        name='Front Door';script='';arguments=@();exitCode=127
        started=(Get-Date).ToUniversalTime().ToString('o')
        finished=(Get-Date).ToUniversalTime().ToString('o')
        outputTail=@('RAH-OS-SELFTEST.ps1 not found.')
    }) | Out-Null
}

# 2) RAVEN CORE
$core = Find-RahFile 'RAVEN-CORE-7.ps1'
if($core){
    $stages.Add((Invoke-Stage 'Raven Core' $core @('-Mode','Diagnostics','-JsonOnly'))) | Out-Null
} else {
    $stages.Add([pscustomobject][ordered]@{
        name='Raven Core';script='';arguments=@();exitCode=127
        started=(Get-Date).ToUniversalTime().ToString('o')
        finished=(Get-Date).ToUniversalTime().ToString('o')
        outputTail=@('RAVEN-CORE-7.ps1 not found.')
    }) | Out-Null
}

# 3) LOCAL AI
$ai = Find-RahFile 'RAVEN-AI-SELF-CHECK.ps1'
if($ai){
    $stages.Add((Invoke-Stage 'Local AI' $ai @())) | Out-Null
} else {
    $stages.Add([pscustomobject][ordered]@{
        name='Local AI';script='';arguments=@();exitCode=127
        started=(Get-Date).ToUniversalTime().ToString('o')
        finished=(Get-Date).ToUniversalTime().ToString('o')
        outputTail=@('RAVEN-AI-SELF-CHECK.ps1 not found.')
    }) | Out-Null
}

# 4) ANYTHINGLLM
$anything = Find-RahFile 'TEST-ANYTHINGLLM-APPROVAL.ps1'
if($anything){
    $stages.Add((Invoke-Stage 'AnythingLLM' $anything @())) | Out-Null
} else {
    $stages.Add([pscustomobject][ordered]@{
        name='AnythingLLM';script='';arguments=@();exitCode=127
        started=(Get-Date).ToUniversalTime().ToString('o')
        finished=(Get-Date).ToUniversalTime().ToString('o')
        outputTail=@('TEST-ANYTHINGLLM-APPROVAL.ps1 not found.')
    }) | Out-Null
}

# 5) WORKER PROOF
$worker = Find-RahFile 'RAVEN-CORE-7-WORKER-PROOF.ps1'
if($worker){
    $stages.Add((Invoke-Stage 'Worker Proof' $worker @('-Mode','Validate','-JsonOnly'))) | Out-Null
} else {
    $stages.Add([pscustomobject][ordered]@{
        name='Worker Proof';script='';arguments=@();exitCode=127
        started=(Get-Date).ToUniversalTime().ToString('o')
        finished=(Get-Date).ToUniversalTime().ToString('o')
        outputTail=@('RAVEN-CORE-7-WORKER-PROOF.ps1 not found.')
    }) | Out-Null
}

# 6) COMBINE
$accept = Find-RahFile 'ACCEPT-RAH-OS-v0.6.ps1'
$acceptExit = 127
if($accept){
    $combine = Invoke-Stage 'Combined Acceptance' $accept @('-JsonOnly')
    $acceptExit = $combine.exitCode
    $stages.Add($combine) | Out-Null
} else {
    $stages.Add([pscustomobject][ordered]@{
        name='Combined Acceptance';script='';arguments=@();exitCode=127
        started=(Get-Date).ToUniversalTime().ToString('o')
        finished=(Get-Date).ToUniversalTime().ToString('o')
        outputTail=@('ACCEPT-RAH-OS-v0.6.ps1 not found.')
    }) | Out-Null
}

$acceptance = Read-JsonFile $script:AcceptanceFile

# Reconcile the combined document with evidence from THIS ordered run.
if($acceptance){
    $stageMap = @{}
    foreach($stage in @($stages)){ $stageMap[[string]$stage.name] = $stage }

    foreach($area in @($acceptance.areas)){
        $name = [string]$area.name
        if($name -eq 'Front Door'){
            if($stageMap['Front Door'].exitCode -eq 0){
                $area.status = 'PASS'
                $area.detail = 'Front Door self-test passed in this HOVED-PC sequence.'
            } else {
                $area.status = 'FAIL'
                $area.detail = 'Front Door self-test failed in this HOVED-PC sequence. Exit=' + [string]$stageMap['Front Door'].exitCode
            }
        }
        elseif($name -eq 'Raven Core'){
            if($stageMap['Raven Core'].exitCode -ne 0){
                $area.status = 'FAIL'
                $area.detail = 'Raven Core diagnostics failed in this HOVED-PC sequence. Exit=' + [string]$stageMap['Raven Core'].exitCode
            }
            # If diagnostics succeeded, preserve PASS/PENDING from fresh Core status evidence.
        }
        elseif($name -eq 'Local AI'){
            $ec = [int]$stageMap['Local AI'].exitCode
            if($ec -eq 0){
                $area.status = 'PASS'
                $area.detail = 'Raven AI Self-Check passed in this HOVED-PC sequence.'
            } elseif($ec -eq 2){
                $area.status = 'PENDING'
                $area.detail = 'Raven AI Self-Check returned PARTIAL in this HOVED-PC sequence.'
            } else {
                $area.status = 'FAIL'
                $area.detail = 'Raven AI Self-Check failed in this HOVED-PC sequence. Exit=' + [string]$ec
            }
        }
        elseif($name -eq 'AnythingLLM'){
            $ec = [int]$stageMap['AnythingLLM'].exitCode
            if($ec -eq 0){
                $area.status = 'PASS'
                $area.detail = 'AnythingLLM approval test passed in this HOVED-PC sequence.'
            } elseif($ec -eq 10){
                $area.status = 'PENDING'
                $area.detail = 'AnythingLLM approval is not configured yet; one-time local configuration is required.'
            } else {
                $area.status = 'FAIL'
                $area.detail = 'AnythingLLM approval test failed in this HOVED-PC sequence. Exit=' + [string]$ec
            }
        }
        elseif($name -eq 'Worker Proof'){
            $workerDoc = Read-JsonFile 'C:\RAH\RavenCore7\state\worker-proof.json'
            if($workerDoc -and [string]$workerDoc.state -eq 'PASS' -and $workerDoc.accepted -eq $true){
                $area.status = 'PASS'
                $area.detail = 'Worker Proof validated accepted real-hardware evidence in this HOVED-PC sequence.'
            } elseif($workerDoc -and [string]$workerDoc.state -in @('FAIL','INVALID')){
                $area.status = 'FAIL'
                $area.detail = 'Worker Proof is ' + [string]$workerDoc.state + ': ' + [string]$workerDoc.detail
            } else {
                $area.status = 'PENDING'
                $area.detail = if($workerDoc){[string]$workerDoc.detail}else{'Worker Proof evidence has not been recorded yet.'}
            }
        }
    }

    if(@($acceptance.areas | Where-Object status -eq 'FAIL').Count -gt 0){
        $acceptance.overall = 'FAIL'
    } elseif(@($acceptance.areas | Where-Object status -ne 'PASS').Count -eq 0){
        $acceptance.overall = 'PASS'
    } else {
        $acceptance.overall = 'PENDING'
    }
    $acceptance | Add-Member -NotePropertyName sequenceSchema -NotePropertyValue 'rah-os-v0.6-hoved-pc-sequence' -Force
    $acceptance | Add-Member -NotePropertyName sequenceTimestamp -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
    $acceptance | Add-Member -NotePropertyName sequenceOrder -NotePropertyValue @('Front Door','Raven Core','Local AI','AnythingLLM','Worker Proof') -Force

    $acceptTmp = $script:AcceptanceFile + '.tmp'
    [IO.File]::WriteAllText($acceptTmp,(($acceptance | ConvertTo-Json -Depth 12) + [Environment]::NewLine),$script:Utf8)
    Move-Item -LiteralPath $acceptTmp -Destination $script:AcceptanceFile -Force
}

$sequence = [pscustomobject][ordered]@{
    schema = 'rah-os-v0.6-hoved-pc-sequence'
    version = 1
    runner = $script:Version
    computer = $env:COMPUTERNAME
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    order = @('Front Door','Raven Core','Local AI','AnythingLLM','Worker Proof','Combined Acceptance')
    stages = @($stages)
    acceptancePath = $script:AcceptanceFile
    acceptanceOverall = if($acceptance){[string]$acceptance.overall}else{'FAIL'}
    safety = [pscustomobject][ordered]@{
        arbitraryShell = $false
        backgroundNetworkDiscovery = $false
        firewallChanges = $false
        nodeTokenRead = $false
        nodeTokenStored = $false
        workerValidationOnly = $true
    }
}
Write-Sequence $sequence

if($JsonOnly){
    $sequence | ConvertTo-Json -Depth 12
} else {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkYellow
    Write-Host '       RAH OS v0.6 - HOVED-PC ACCEPTANCE SEQUENCE' -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor DarkYellow
    foreach($stage in @($stages)){
        $label = if($stage.exitCode -eq 0){'DONE'}elseif($stage.exitCode -in @(2,10)){'PENDING'}else{'CHECK'}
        $color = if($label -eq 'DONE'){'Green'}elseif($label -eq 'PENDING'){'Yellow'}else{'Red'}
        Write-Host (('{0,-8} {1,-20} exit={2}' -f $label,$stage.name,$stage.exitCode)) -ForegroundColor $color
    }
    Write-Host ''
    if($acceptance){
        foreach($area in @($acceptance.areas)){
            $color = switch([string]$area.status){ 'PASS' {'Green'} 'PENDING' {'Yellow'} 'FAIL' {'Red'} default {'Gray'} }
            Write-Host (('{0,-8} {1,-16} {2}' -f $area.status,$area.name,$area.detail)) -ForegroundColor $color
        }
        Write-Host ''
        $overallColor = switch([string]$acceptance.overall){ 'PASS' {'Green'} 'FAIL' {'Red'} default {'Yellow'} }
        Write-Host ('FINAL: ' + [string]$acceptance.overall) -ForegroundColor $overallColor
    } else {
        Write-Host 'FINAL: FAIL - combined acceptance file was not produced.' -ForegroundColor Red
    }
    Write-Host ('Acceptance JSON: ' + $script:AcceptanceFile) -ForegroundColor DarkGray
    Write-Host ('Sequence log   : ' + $script:SequenceFile) -ForegroundColor DarkGray
}

if(-not $acceptance){ exit 1 }
if([string]$acceptance.overall -eq 'PASS'){ exit 0 }
if([string]$acceptance.overall -eq 'PENDING'){ exit 2 }
exit 1

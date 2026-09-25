param(
    [ValidateSet('Status','Precheck','Validate','Prepare')]
    [string]$Mode = 'Prepare',
    [switch]$JsonOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version = '7.0.0-worker-proof'
$script:RahRoot = 'C:\RAH'
$script:CoreRoot = 'C:\RAH\RavenCore7'
$script:StateRoot = Join-Path $script:CoreRoot 'state'
$script:ProofFile = Join-Path $script:StateRoot 'worker-proof.json'
$script:GridRoot = 'C:\RAH\2PCProof'
$script:InventoryPath = Join-Path $script:GridRoot 'results\last-inventory.json'
$script:AcceptancePath = Join-Path $script:GridRoot 'results\REAL-HARDWARE-ACCEPTANCE.json'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force -Path $script:CoreRoot,$script:StateRoot | Out-Null

function Find-RahFile {
    param([Parameter(Mandatory=$true)][string]$Name)
    foreach($root in @(
        $PSScriptRoot,
        $script:CoreRoot,
        $script:RahRoot,
        $script:GridRoot,
        'C:\RAH\RavenOS',
        'C:\RAH\rah-platform',
        'C:\RAH\RAH-Platform'
    )){
        if([string]::IsNullOrWhiteSpace($root)){ continue }
        $candidate = Join-Path $root $Name
        if(Test-Path -LiteralPath $candidate -PathType Leaf){
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    return $null
}

function Write-Proof {
    param($Value)
    $tmp = $script:ProofFile + '.tmp'
    [IO.File]::WriteAllText($tmp,(($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine),$script:Utf8)
    Move-Item -LiteralPath $tmp -Destination $script:ProofFile -Force
}

function New-ProofDocument {
    param(
        [string]$State,
        [bool]$Accepted,
        [string]$Detail,
        $Evidence = $null,
        [object[]]$Checks = @()
    )
    [pscustomobject][ordered]@{
        schema = 'rah-raven-core-7-worker-proof-v1'
        version = $script:Version
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        state = $State
        accepted = $Accepted
        detail = $Detail
        worker = if($Evidence){[pscustomobject][ordered]@{
            hostname = [string]$Evidence.hostname
            targetPort = 18766
            ravenPort = 18765
            readOnly = $true
            arbitraryCommands = $false
            callerArguments = $false
            tokenPersisted = $false
            localRavenHopOnly = $true
        }}else{$null}
        evidence = if($Evidence){[pscustomobject][ordered]@{
            acceptancePath = $script:AcceptancePath
            acceptanceSha256 = [string]$Evidence.acceptanceSha256
            inventoryPath = $script:InventoryPath
            inventorySha256 = [string]$Evidence.inventorySha256
            createdAt = [string]$Evidence.createdAt
        }}else{$null}
        checks = @($Checks)
        safety = [pscustomobject][ordered]@{
            tokenRead = $false
            tokenStored = $false
            arbitraryShell = $false
            networkDiscovery = $false
            firewallChanges = $false
            remoteActionAdded = $false
        }
    }
}

function Test-GridSelfTests {
    $checks = New-Object System.Collections.Generic.List[object]
    foreach($item in @(
        @('RAH-2PC-CLIENT.ps1','-SelfTest','2-PC HMAC client'),
        @('RAH-2PC-ACCEPTANCE.ps1','-SelfTest','2-PC acceptance validator')
    )){
        $path = Find-RahFile ([string]$item[0])
        if(-not $path){
            $checks.Add([pscustomobject]@{name=$item[2];status='WARN';detail=([string]$item[0] + ' not found.')}) | Out-Null
            continue
        }
        try {
            $raw = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $path ([string]$item[1]) 2>&1
            if($LASTEXITCODE -eq 0){
                $checks.Add([pscustomobject]@{name=$item[2];status='PASS';detail=(($raw | Out-String).Trim())}) | Out-Null
            } else {
                $checks.Add([pscustomobject]@{name=$item[2];status='FAIL';detail=('Exit=' + $LASTEXITCODE + ': ' + (($raw | Out-String).Trim()))}) | Out-Null
            }
        } catch {
            $checks.Add([pscustomobject]@{name=$item[2];status='FAIL';detail=$_.Exception.Message}) | Out-Null
        }
    }
    # Windows PowerShell 5.1 can fail when @() wraps Generic.List[object].
    # Materialize through the pipeline before returning.
    $checkItems = @($checks | ForEach-Object { $_ })
    return $checkItems
}

function Test-ExistingEvidence {
    if(-not (Test-Path -LiteralPath $script:AcceptancePath -PathType Leaf)){
        return [pscustomobject]@{ok=$false;state='PENDING';detail='Real-hardware acceptance evidence is not present yet.';evidence=$null}
    }
    if(-not (Test-Path -LiteralPath $script:InventoryPath -PathType Leaf)){
        return [pscustomobject]@{ok=$false;state='INVALID';detail='Acceptance exists but source inventory is missing.';evidence=$null}
    }

    try {
        $doc = Get-Content -LiteralPath $script:AcceptancePath -Raw | ConvertFrom-Json -ErrorAction Stop
        if([string]$doc.schema -ne 'rah-2pc-real-hardware-acceptance-v1'){ throw 'Unexpected acceptance schema.' }
        if([string]$doc.overall -ne 'PASS'){ throw 'Acceptance report is not PASS.' }
        if($null -eq $doc.evidence -or $null -eq $doc.gates -or $null -eq $doc.source){ throw 'Acceptance report is incomplete.' }

        foreach($name in @(
            'inventoryPass','expectedLenovoHost','privateLanOnly','nodePort18766',
            'ravenLocalHop18765','readOnly','noArbitraryCommands','noCallerArguments','tokenNotPersisted'
        )){
            $prop = $doc.gates.PSObject.Properties[$name]
            if($null -eq $prop -or $prop.Value -ne $true){ throw ('Acceptance gate is not true: ' + $name) }
        }

        if([int]$doc.evidence.targetPort -ne 18766){ throw 'Worker target port is not 18766.' }
        if([int]$doc.evidence.ravenPort -ne 18765){ throw 'Worker Raven hop is not 18765.' }
        if($doc.evidence.readOnly -ne $true -or $doc.evidence.arbitraryCommands -ne $false -or
           $doc.evidence.callerArguments -ne $false -or $doc.evidence.tokenPersisted -ne $false -or
           $doc.evidence.localRavenHopOnly -ne $true){
            throw 'Worker evidence safety contract failed.'
        }

        $actualInventoryHash = (Get-FileHash -LiteralPath $script:InventoryPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedInventoryHash = ([string]$doc.source.sha256).ToLowerInvariant()
        if($actualInventoryHash -ne $expectedInventoryHash){ throw 'Inventory SHA-256 no longer matches acceptance evidence.' }

        $acceptanceHash = (Get-FileHash -LiteralPath $script:AcceptancePath -Algorithm SHA256).Hash.ToLowerInvariant()
        return [pscustomobject]@{
            ok=$true
            state='PASS'
            detail='Validated immutable 2-PC real-hardware evidence.'
            evidence=[pscustomobject]@{
                hostname=[string]$doc.evidence.hostname
                createdAt=[string]$doc.createdAt
                inventorySha256=$actualInventoryHash
                acceptanceSha256=$acceptanceHash
            }
        }
    } catch {
        return [pscustomobject]@{ok=$false;state='INVALID';detail=$_.Exception.Message;evidence=$null}
    }
}

function Show-Proof {
    param($Proof)
    if($JsonOnly){
        $Proof | ConvertTo-Json -Depth 12
        return
    }
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkYellow
    Write-Host '         RAH RAVEN CORE 7.0 - WORKER PROOF' -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor DarkYellow
    foreach($check in @($Proof.checks)){
        $color = switch([string]$check.status){ 'PASS' {'Green'} 'WARN' {'Yellow'} 'FAIL' {'Red'} default {'Gray'} }
        Write-Host (('{0,-5} {1,-28} {2}' -f $check.status,$check.name,$check.detail)) -ForegroundColor $color
    }
    Write-Host ''
    Write-Host ('WORKER STATE: ' + $Proof.state) -ForegroundColor $(if($Proof.accepted){'Green'}elseif($Proof.state -eq 'INVALID'){'Red'}else{'Yellow'})
    Write-Host $Proof.detail
    if($Proof.worker){
        Write-Host ('Accepted worker: ' + $Proof.worker.hostname) -ForegroundColor Green
        Write-Host ('Authority: read-only fixed capability / ports 18766 -> 18765')
    }
    Write-Host ('State file: ' + $script:ProofFile) -ForegroundColor DarkGray
}

$checks = Test-GridSelfTests
$failedSelfTest = @($checks | Where-Object status -eq 'FAIL').Count -gt 0
$evidenceResult = Test-ExistingEvidence

if($failedSelfTest){
    $proof = New-ProofDocument -State 'FAIL' -Accepted $false -Detail 'One or more 2-PC software self-tests failed.' -Checks $checks
    Write-Proof $proof
    Show-Proof $proof
    exit 1
}

if($evidenceResult.ok){
    $proof = New-ProofDocument -State 'PASS' -Accepted $true -Detail $evidenceResult.detail -Evidence $evidenceResult.evidence -Checks $checks
    Write-Proof $proof
    Show-Proof $proof
    exit 0
}

$proof = New-ProofDocument -State $evidenceResult.state -Accepted $false -Detail $evidenceResult.detail -Checks $checks
Write-Proof $proof
Show-Proof $proof

if($Mode -eq 'Prepare' -and $evidenceResult.state -eq 'PENDING'){
    $grid = Find-RahFile 'START-HER-RAH-2PC-GRID.cmd'
    if($grid){
        if(-not $JsonOnly){
            Write-Host ''
            Write-Host 'Opening the existing fixed 2-PC Grid for the physical proof step.' -ForegroundColor Yellow
            Write-Host 'The fresh Node token stays in the existing GUI flow; Core 7 never reads or stores it.' -ForegroundColor DarkGray
        }
        Start-Process -FilePath $grid -WorkingDirectory (Split-Path -Parent $grid)
    } elseif(-not $JsonOnly){
        Write-Host '2-PC Grid launcher is not installed. Run INSTALL-RAH-2PC-GRID.cmd first.' -ForegroundColor Yellow
    }
}

if($evidenceResult.state -eq 'INVALID'){ exit 2 }
exit 0

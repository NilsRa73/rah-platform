[CmdletBinding()]
param(
    [string]$TargetRoot = 'C:\RAH',
    [string]$SnapshotPath = '',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RollbackVersion='1.0.0'
$script:Utf8=New-Object Text.UTF8Encoding($false)

function Get-RahHash([string]$Path){
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Resolve-RahSnapshot([string]$Root,[string]$Requested){
    if($Requested){
        return [IO.Path]::GetFullPath($Requested)
    }
    $latest=Join-Path $Root '_STABLE_CANDIDATES\RAVEN-AGENT-EFFECT-PACK-V1\LATEST.txt'
    if(-not(Test-Path -LiteralPath $latest -PathType Leaf)){throw 'No frozen Raven v1 Candidate snapshot found.'}
    return [IO.Path]::GetFullPath((Get-Content -LiteralPath $latest -Raw).Trim())
}

function Test-RahSnapshot([string]$Snapshot){
    $manifestPath=Join-Path $Snapshot 'RAVEN-CANDIDATE-MANIFEST.json'
    if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'Candidate manifest missing.'}
    $doc=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if($doc.state -ne 'FROZEN_CANDIDATE'){throw 'Snapshot is not a frozen Candidate.'}
    foreach($entry in @($doc.files)){
        $path=Join-Path $Snapshot ([string]$entry.path).Replace('/','\')
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Snapshot file missing: '+$entry.path)}
        $actual=Get-RahHash $path
        if($actual -ne [string]$entry.sha256){throw ('SHA256 mismatch: '+$entry.path)}
    }
    return $doc
}

function Copy-RahSnapshot([string]$Root,[string]$Snapshot,[object]$Manifest){
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup=Join-Path $Root ('_ARCHIVE\RAVEN-BEFORE-ROLLBACK-'+$stamp)
    New-Item -ItemType Directory -Path $backup -Force | Out-Null

    foreach($entry in @($Manifest.files)){
        $rel=([string]$entry.path).Replace('/','\')
        $current=Join-Path $Root $rel
        if(Test-Path -LiteralPath $current -PathType Leaf){
            $safe=Join-Path $backup $rel
            New-Item -ItemType Directory -Path (Split-Path -Parent $safe) -Force | Out-Null
            Copy-Item -LiteralPath $current -Destination $safe -Force
        }
    }

    foreach($entry in @($Manifest.files)){
        $rel=([string]$entry.path).Replace('/','\')
        $src=Join-Path $Snapshot $rel
        $dst=Join-Path $Root $rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }

    $receipt=[pscustomobject]@{
        schema='rah-raven-overlay-rollback'
        version=1
        rollbackVersion=$script:RollbackVersion
        createdAt=(Get-Date).ToUniversalTime().ToString('o')
        snapshot=$Snapshot
        backup=$backup
        restoredFiles=@($Manifest.files).Count
        deletePerformed=$false
        overlayOnly=$true
    }
    $receiptPath=Join-Path $Root 'Logs\RAVEN-V1-ROLLBACK-LATEST.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $receiptPath) -Force | Out-Null
    [IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 5),$script:Utf8)
    return $receipt
}

function Invoke-RahSelfTest {
    $tmp=Join-Path $env:TEMP ('rah-rollback-selftest-'+[guid]::NewGuid().ToString('N'))
    try{
        $root=Join-Path $tmp 'root'
        $snap=Join-Path $tmp 'snap'
        New-Item -ItemType Directory -Path $root,$snap -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $snap 'x.txt'),'known-good',$script:Utf8)
        $manifest=[pscustomobject]@{
            state='FROZEN_CANDIDATE'
            files=@([pscustomobject]@{path='x.txt';sha256=Get-RahHash (Join-Path $snap 'x.txt');bytes=10})
        }
        [IO.File]::WriteAllText((Join-Path $snap 'RAVEN-CANDIDATE-MANIFEST.json'),($manifest|ConvertTo-Json -Depth 5),$script:Utf8)
        [IO.File]::WriteAllText((Join-Path $root 'x.txt'),'newer',$script:Utf8)
        $doc=Test-RahSnapshot $snap
        $receipt=Copy-RahSnapshot $root $snap $doc
        if((Get-Content -LiteralPath (Join-Path $root 'x.txt') -Raw) -ne 'known-good'){throw 'rollback copy failed'}
        if($receipt.deletePerformed -ne $false){throw 'rollback became destructive'}
        Write-Host 'RAH RAVEN OVERLAY ROLLBACK SELFTEST: PASS'
    }
    finally{
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if($SelfTest){Invoke-RahSelfTest;exit 0}

$root=[IO.Path]::GetFullPath($TargetRoot)
$snapshot=Resolve-RahSnapshot $root $SnapshotPath
$manifest=Test-RahSnapshot $snapshot
$receipt=Copy-RahSnapshot $root $snapshot $manifest
Write-Host ('ROLLBACK PASS: '+$receipt.restoredFiles+' known-good files restored.') -ForegroundColor Green
Write-Host ('Pre-rollback backup: '+$receipt.backup)
Write-Host 'No files were deleted; rollback is a verified overlay.'

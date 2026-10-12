[CmdletBinding()]
param(
    [string]$SourceRoot = 'C:\RAH',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:FreezeVersion = '1.0.0'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

function Get-RahRelativePath {
    param([string]$Root,[string]$Path)
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
    $pathFull=[IO.Path]::GetFullPath($Path)
    if(-not $pathFull.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase)){
        throw "Path outside source root: $Path"
    }
    return $pathFull.Substring($rootFull.Length)
}

function Get-RahHash {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Copy-RahFile {
    param([string]$SourceRoot,[string]$SnapshotRoot,[string]$Relative)
    $src=Join-Path $SourceRoot $Relative
    if(-not(Test-Path -LiteralPath $src -PathType Leaf)){ return $false }
    $dst=Join-Path $SnapshotRoot $Relative
    $parent=Split-Path -Parent $dst
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
    return $true
}

function Copy-RahTree {
    param([string]$SourceRoot,[string]$SnapshotRoot,[string]$Relative,[string[]]$ExcludedDirs)
    $src=Join-Path $SourceRoot $Relative
    if(-not(Test-Path -LiteralPath $src -PathType Container)){ return }
    $rootFull=[IO.Path]::GetFullPath($SourceRoot)
    Get-ChildItem -LiteralPath $src -File -Recurse -Force | ForEach-Object {
        $full=$_.FullName
        $skip=$false
        foreach($name in $ExcludedDirs){
            if($full -match ('[\\/]' + [regex]::Escape($name) + '([\\/]|$)')){
                $skip=$true
                break
            }
        }
        if(-not $skip){
            $rel=Get-RahRelativePath $rootFull $full
            $dst=Join-Path $SnapshotRoot $rel
            New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
            Copy-Item -LiteralPath $full -Destination $dst -Force
        }
    }
}

function Write-RahFreeze {
    param([string]$Root,[string]$SnapshotBase)
    $rootFull=[IO.Path]::GetFullPath($Root)
    if(-not(Test-Path -LiteralPath $rootFull -PathType Container)){throw "Source root missing: $rootFull"}

    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $snapshot=Join-Path $SnapshotBase $stamp
    New-Item -ItemType Directory -Path $snapshot -Force | Out-Null

    $rootFiles=@(
        'START-RAVEN.cmd',
        'START-RAVEN-V1-ACCEPTANCE.cmd',
        'RAH-AGENT-TEAM-LIVE-TEST.ps1',
        'RAH-LM-STUDIO-RECOVERY.cmd',
        'RAH-LM-STUDIO-RECOVERY.ps1',
        'project-registry.js',
        'index.html'
    )
    foreach($item in $rootFiles){ $null=Copy-RahFile $rootFull $snapshot $item }

    Copy-RahTree $rootFull $snapshot 'raven' @('__pycache__','.pytest_cache','logs')
    Copy-RahTree $rootFull $snapshot 'desktop-bridge' @('.venv','__pycache__','.pytest_cache','logs')

    $files=@()
    Get-ChildItem -LiteralPath $snapshot -File -Recurse | Where-Object {$_.Name -ne 'RAVEN-CANDIDATE-MANIFEST.json'} | ForEach-Object {
        $files += [pscustomobject]@{
            path=(Get-RahRelativePath $snapshot $_.FullName).Replace('\','/')
            sha256=Get-RahHash $_.FullName
            bytes=[int64]$_.Length
        }
    }
    if($files.Count -lt 5){throw 'Freeze captured too few files.'}

    $acceptance=Join-Path $rootFull 'Logs\RAVEN-V1-ACCEPTANCE-LATEST.json'
    $acceptanceHash=''
    if(Test-Path -LiteralPath $acceptance -PathType Leaf){$acceptanceHash=Get-RahHash $acceptance}

    $manifest=[pscustomobject]@{
        schema='rah-raven-candidate-freeze'
        version=1
        freezeVersion=$script:FreezeVersion
        name='Raven Agent Effect Pack v1'
        state='FROZEN_CANDIDATE'
        createdAt=(Get-Date).ToUniversalTime().ToString('o')
        computer=$env:COMPUTERNAME
        sourceRoot=$rootFull
        snapshotRoot=$snapshot
        acceptanceReport=$acceptance
        acceptanceSha256=$acceptanceHash
        stablePromoted=$false
        merged=$false
        destructiveDelete=$false
        files=@($files | Sort-Object path)
    }
    $manifestPath=Join-Path $snapshot 'RAVEN-CANDIDATE-MANIFEST.json'
    [IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 8),$script:Utf8)
    New-Item -ItemType Directory -Path $SnapshotBase -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $SnapshotBase 'LATEST.txt'),$snapshot+[Environment]::NewLine,$script:Utf8)

    return [pscustomobject]@{
        snapshot=$snapshot
        manifest=$manifestPath
        fileCount=$files.Count
    }
}

function Invoke-RahSelfTest {
    $tmp=Join-Path $env:TEMP ('rah-freeze-selftest-'+[guid]::NewGuid().ToString('N'))
    try{
        $root=Join-Path $tmp 'root'
        $base=Join-Path $tmp 'snapshots'
        New-Item -ItemType Directory -Path (Join-Path $root 'raven') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root 'desktop-bridge') -Force | Out-Null
        foreach($pair in @(
            @('START-RAVEN.cmd','a'),
            @('START-RAVEN-V1-ACCEPTANCE.cmd','b'),
            @('RAH-AGENT-TEAM-LIVE-TEST.ps1','c'),
            @('raven\projects.json','{}'),
            @('raven\agents.json','{}'),
            @('desktop-bridge\raven_bridge.py','print("ok")')
        )){
            $p=Join-Path $root $pair[0]
            New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
            [IO.File]::WriteAllText($p,$pair[1],$script:Utf8)
        }
        $result=Write-RahFreeze $root $base
        if(-not(Test-Path -LiteralPath $result.manifest -PathType Leaf)){throw 'manifest missing'}
        $doc=Get-Content -LiteralPath $result.manifest -Raw | ConvertFrom-Json
        if($doc.state -ne 'FROZEN_CANDIDATE'){throw 'freeze state mismatch'}
        if($doc.stablePromoted -ne $false){throw 'self-test unexpectedly promoted stable'}
        if(@($doc.files).Count -lt 5){throw 'self-test captured too few files'}
        Write-Host 'RAH RAVEN CANDIDATE FREEZE SELFTEST: PASS'
    }
    finally{
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if($SelfTest){
    Invoke-RahSelfTest
    exit 0
}

$root=[IO.Path]::GetFullPath($SourceRoot)
$acceptance=Join-Path $root 'Logs\RAVEN-V1-ACCEPTANCE-LATEST.json'
if(-not(Test-Path -LiteralPath $acceptance -PathType Leaf)){
    throw 'Final acceptance report is missing. Run START-RAVEN-V1-ACCEPTANCE.cmd first.'
}
$accept=Get-Content -LiteralPath $acceptance -Raw | ConvertFrom-Json
if([string]$accept.overall -ne 'PASS'){
    throw 'Candidate freeze blocked: final acceptance is not PASS.'
}

$base=Join-Path $root '_STABLE_CANDIDATES\RAVEN-AGENT-EFFECT-PACK-V1'
$result=Write-RahFreeze $root $base
Write-Host ('FROZEN CANDIDATE: '+$result.snapshot) -ForegroundColor Green
Write-Host ('Manifest: '+$result.manifest)
Write-Host ('Files: '+$result.fileCount)

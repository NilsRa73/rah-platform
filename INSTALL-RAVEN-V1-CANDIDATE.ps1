[CmdletBinding()]
param(
    [string]$TargetRoot = 'C:\RAH',
    [string]$SourceBase = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/raven-agent-effect-pack-v1-20260927',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$script:RahRavenV1InstallerVersion='1.0.0'
$script:Utf8=New-Object Text.UTF8Encoding($false)

$script:Files=@(
    'START-RAVEN.cmd',
    'START-RAVEN-V1-ACCEPTANCE.cmd',
    'FREEZE-RAVEN-V1-CANDIDATE.cmd',
    'ROLLBACK-RAVEN-V1.cmd',
    'RAH-AGENT-TEAM-LIVE-TEST.ps1',
    'RAH-LM-STUDIO-RECOVERY.cmd',
    'RAH-LM-STUDIO-RECOVERY.ps1',
    'project-registry.js',
    'index.html',
    'raven\agents.json',
    'raven\projects.json',
    'raven\raven_registry.py',
    'raven\windows\PREPARE-RAVEN-BRIDGE.cmd',
    'raven\windows\RAH-RAVEN-V1-ACCEPTANCE.ps1',
    'raven\windows\FREEZE-RAVEN-V1-CANDIDATE.ps1',
    'raven\windows\ROLLBACK-RAVEN-V1.ps1',
    'raven\releases\agent-effect-pack-v1-candidate.json',
    'raven\releases\agent-effect-pack-v1-RELEASE-NOTES.md',
    'desktop-bridge\raven_ai_fabric.py'
)

function Test-RahRelativePath([string]$Relative){
    if([string]::IsNullOrWhiteSpace($Relative)){return $false}
    if([IO.Path]::IsPathRooted($Relative)){return $false}
    if($Relative -match '(^|[\\/])\.\.([\\/]|$)'){return $false}
    return $true
}

function Invoke-RahSelfTest {
    if($script:RahRavenV1InstallerVersion -ne '1.0.0'){throw 'installer version mismatch'}
    if($script:Files.Count -lt 15){throw 'installer file set unexpectedly small'}
    if(@($script:Files | Select-Object -Unique).Count -ne $script:Files.Count){throw 'duplicate installer path'}
    foreach($rel in $script:Files){
        if(-not(Test-RahRelativePath $rel)){throw ('unsafe relative path: '+$rel)}
    }
    foreach($required in @(
        'START-RAVEN-V1-ACCEPTANCE.cmd',
        'FREEZE-RAVEN-V1-CANDIDATE.cmd',
        'ROLLBACK-RAVEN-V1.cmd',
        'raven\windows\RAH-RAVEN-V1-ACCEPTANCE.ps1'
    )){
        if($required -notin $script:Files){throw ('required installer item missing: '+$required)}
    }
    Write-Host 'RAH RAVEN V1 INSTALLER SELFTEST: PASS'
}

if($SelfTest){Invoke-RahSelfTest;exit 0}

$root=[IO.Path]::GetFullPath($TargetRoot)
if(-not(Test-Path -LiteralPath (Join-Path $root 'desktop-bridge\raven_bridge.py') -PathType Leaf)){
    throw ('Existing Raven root not found: '+$root)
}
if(-not(Test-Path -LiteralPath (Join-Path $root 'desktop-bridge\doctor.py') -PathType Leaf)){
    throw 'Existing Raven doctor.py is missing.'
}

$tmp=Join-Path $env:TEMP ('RAH-RAVEN-V1-INSTALL-'+[guid]::NewGuid().ToString('N'))
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$backup=Join-Path $root ('_ARCHIVE\RAVEN-V1-BEFORE-INSTALL-'+$stamp)
$receiptPath=Join-Path $root 'Logs\RAVEN-V1-INSTALL-LATEST.json'
New-Item -ItemType Directory -Path $tmp,$backup,(Split-Path -Parent $receiptPath) -Force | Out-Null

$downloaded=@()
$backedUp=@()
try{
    foreach($rel in $script:Files){
        if(-not(Test-RahRelativePath $rel)){throw ('Unsafe installer path: '+$rel)}
        $slash=$rel.Replace('\','/')
        $uri=$SourceBase.TrimEnd('/')+'/'+$slash
        $dst=Join-Path $tmp $rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
        Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $dst -TimeoutSec 60
        if((Get-Item -LiteralPath $dst).Length -le 0){throw ('Downloaded empty file: '+$rel)}
        $downloaded += $rel
    }

    $markers=@{
        'START-RAVEN-V1-ACCEPTANCE.cmd'='RAH RAVEN V1 - FINAL ACCEPTANCE'
        'raven\windows\RAH-RAVEN-V1-ACCEPTANCE.ps1'="AcceptanceVersion = '1.0.0'"
        'raven\windows\FREEZE-RAVEN-V1-CANDIDATE.ps1'="FreezeVersion = '1.0.0'"
        'raven\windows\ROLLBACK-RAVEN-V1.ps1'="RollbackVersion='1.0.0'"
        'raven\releases\agent-effect-pack-v1-candidate.json'='"state": "candidate"'
    }
    foreach($key in $markers.Keys){
        $raw=Get-Content -LiteralPath (Join-Path $tmp $key) -Raw
        if(-not $raw.Contains($markers[$key])){throw ('Candidate marker missing: '+$key)}
    }

    foreach($rel in $script:Files){
        $current=Join-Path $root $rel
        if(Test-Path -LiteralPath $current -PathType Leaf){
            $safe=Join-Path $backup $rel
            New-Item -ItemType Directory -Path (Split-Path -Parent $safe) -Force | Out-Null
            Copy-Item -LiteralPath $current -Destination $safe -Force
            $backedUp += $rel
        }
    }

    foreach($rel in $script:Files){
        $src=Join-Path $tmp $rel
        $dst=Join-Path $root $rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }

    $receipt=[pscustomobject]@{
        schema='rah-raven-v1-candidate-install'
        version=1
        installerVersion=$script:RahRavenV1InstallerVersion
        createdAt=(Get-Date).ToUniversalTime().ToString('o')
        targetRoot=$root
        sourceBase=$SourceBase
        backup=$backup
        files=@($downloaded)
        backedUp=@($backedUp)
        deletedFiles=$false
        stablePromoted=$false
        merged=$false
    }
    [IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 6),$script:Utf8)

    Write-Host ('[PASS] Candidate installed: '+$downloaded.Count+' files') -ForegroundColor Green
    Write-Host ('[PASS] Previous files backed up: '+$backup)
    Write-Host '[RAH] Starting final acceptance ...'

    $accept=Join-Path $root 'START-RAVEN-V1-ACCEPTANCE.cmd'
    $p=Start-Process -FilePath $accept -WorkingDirectory $root -Wait -PassThru
    exit [int]$p.ExitCode
}
finally{
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

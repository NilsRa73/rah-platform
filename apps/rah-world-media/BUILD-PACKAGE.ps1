param(
    [string]$OutDir = (Join-Path $PSScriptRoot 'dist')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Version = '14.0'
$FolderName = 'RAH_WORLD_MEDIA_v14_RAVEN_WORLD_GRID'
$StageRoot = Join-Path ([IO.Path]::GetTempPath()) ('rah-world-media-build-' + [guid]::NewGuid().ToString('N'))
$Stage = Join-Path $StageRoot $FolderName

$Files = @(
    'START-HER.cmd',
    'START-RAH-WORLD-MEDIA.cmd',
    'INSTALL.cmd',
    'RAH_INSTALL.ps1',
    'REPAIR.cmd',
    'SELFTEST.cmd',
    'SELF-IMPROVE.cmd',
    'DIAGNOSTICS.cmd',
    'RAH_WORLD_MEDIA.py',
    'UNINSTALL.cmd',
    'RAH_BOOTSTRAP.ps1',
    'RUN-CHECKLIST.txt',
    'CHANGELOG_v14.txt',
    'world_countries_simplified.json',
    'README.txt'
)

try {
    New-Item -ItemType Directory -Force -Path $Stage,$OutDir | Out-Null

    foreach($name in $Files){
        $src = Join-Path $PSScriptRoot $name
        if(-not (Test-Path -LiteralPath $src -PathType Leaf)){
            throw "Required World Media source file missing: $name"
        }
        Copy-Item -LiteralPath $src -Destination (Join-Path $Stage $name) -Force
    }

    $manifestLines = foreach($name in $Files){
        $path = Join-Path $Stage $name
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $name"
    }
    [IO.File]::WriteAllLines((Join-Path $Stage 'MANIFEST.sha256'),[string[]]$manifestLines,[Text.UTF8Encoding]::new($false))

    $zip = Join-Path $OutDir ($FolderName + '.zip')
    if(Test-Path -LiteralPath $zip){ Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -LiteralPath $Stage -DestinationPath $zip -CompressionLevel Optimal

    if(-not (Test-Path -LiteralPath $zip -PathType Leaf)){ throw 'ZIP was not created.' }
    $zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()

    Write-Host ''
    Write-Host 'RAH WORLD MEDIA PACKAGE: PASS' -ForegroundColor Green
    Write-Host ('Version : ' + $Version)
    Write-Host ('ZIP     : ' + $zip)
    Write-Host ('SHA256  : ' + $zipHash)
}
finally {
    Remove-Item -LiteralPath $StageRoot -Recurse -Force -ErrorAction SilentlyContinue
}

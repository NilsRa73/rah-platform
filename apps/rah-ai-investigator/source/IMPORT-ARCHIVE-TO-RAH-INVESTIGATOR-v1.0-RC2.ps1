param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference='Stop'
$Stable=Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'IMPORT-ARCHIVE-TO-RAH-INVESTIGATOR-v1.0.ps1'
if(-not(Test-Path -LiteralPath $Stable -PathType Leaf)){throw 'Stable Investigator import helper is missing'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Stable -InputPath $InputPath -OutputPath $OutputPath
exit $LASTEXITCODE

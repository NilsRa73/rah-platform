param(
  [switch]$NoStart,
  [Alias('NoCommandCenterSync')][switch]$SkipCommandCenterSync
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$V2=Join-Path $Root 'UPDATE-RAH-RAVEN-V2.ps1'
$ReleasePath=Join-Path $Root 'RAH-RAVEN-UPDATER-V2-STABLE-RELEASE.json'
$LegacyPath=Join-Path $Root 'UPDATE-RAH-RAVEN-V1-LEGACY.ps1'

function Get-GitBlobSha1{
  param([string]$Path)
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Fil mangler: $Path"}
  $bytes=[IO.File]::ReadAllBytes($Path)
  $prefix=[Text.Encoding]::UTF8.GetBytes(('blob {0}' -f $bytes.Length)+[char]0)
  $combined=New-Object byte[] ($prefix.Length+$bytes.Length)
  [Array]::Copy($prefix,0,$combined,0,$prefix.Length)
  [Array]::Copy($bytes,0,$combined,$prefix.Length,$bytes.Length)
  $sha=[Security.Cryptography.SHA1]::Create()
  try{return (($sha.ComputeHash($combined)|ForEach-Object{$_.ToString('x2')}) -join '')}
  finally{$sha.Dispose()}
}

try{
  if(-not(Test-Path -LiteralPath $ReleasePath -PathType Leaf)){throw 'Raven Updater v2 Stable release-manifest mangler. Ingen legacy fallback kjøres automatisk.'}
  if(-not(Test-Path -LiteralPath $V2 -PathType Leaf)){throw 'UPDATE-RAH-RAVEN-V2.ps1 mangler. Ingen legacy fallback kjøres automatisk.'}
  $release=Get-Content -LiteralPath $ReleasePath -Raw -Encoding UTF8|ConvertFrom-Json
  if($release.product-ne'RAH Raven Updater'-or $release.version-ne'2.0.0'-or $release.stage-ne'stable-release'-or $release.active_from_root_wrapper-ne$true){throw 'Updater v2 Stable release-kontrakten er ugyldig.'}
  if($release.runtime.path-ne'UPDATE-RAH-RAVEN-V2.ps1'){throw 'Updater v2 Stable release peker på uventet runtime.'}
  $actual=Get-GitBlobSha1 -Path $V2
  if($actual-ne[string]$release.runtime.gitBlobSha){throw 'Lokal Updater v2 matcher ikke Stable release-pinnen. Kjør ikke uverifisert updater.'}
  $invoke=@{}
  if($NoStart){$invoke.NoStart=$true}
  if($SkipCommandCenterSync){$invoke.SkipCommandCenterSync=$true}
  $global:LASTEXITCODE=0
  & $V2 @invoke
  if($LASTEXITCODE-ne0){exit $LASTEXITCODE}
}catch{
  Write-Host "RAH Raven updater stoppet trygt: $($_.Exception.Message)" -ForegroundColor Red
  if(Test-Path -LiteralPath $LegacyPath -PathType Leaf){Write-Host 'Legacy updater er bevart som UPDATE-RAH-RAVEN-V1-LEGACY.ps1 for eksplisitt recovery, men startes aldri automatisk.' -ForegroundColor Yellow}
  exit 1
}

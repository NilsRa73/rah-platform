param(
  [switch]$NoStart,
  [Alias('NoCommandCenterSync')][switch]$SkipCommandCenterSync
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

$UpdaterVersion='2.0.0'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoOwner='NilsRa73';$RepoName='rah-platform';$RepoBranch='main'
$ApiBase="https://api.github.com/repos/$RepoOwner/$RepoName"
$ManifestName='RAH-RAVEN-VERSION.json'
$ExpectedRavenVersion='2.0.32'
$CriticalFiles=@(
  'UPDATE-RAH-RAVEN.ps1',
  'UPDATE-RAH-RAVEN-V2.ps1',
  'RAH-RAVEN-UPDATER-V2-VERSION.json',
  'UPDATE-RAH-COMMAND-CENTER.ps1',
  'RAH-COMMAND-CENTER-VERSION.json',
  'RAH-COMMAND-CENTER-V1.7.html',
  'rah-command-center-core-v1.7.js',
  'rah-node-agent-v1.3.py',
  'RAH-CC17-NODE13-STABLE-RELEASE.json'
)
$Stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir=Join-Path (Join-Path $Root '.rah-backups') ("raven-v2-"+$Stamp)
$LogFile=Join-Path $Root 'rah-raven-update.log'
$ManifestTemp=$null;$StageRoot=$null
$Installed=New-Object 'System.Collections.Generic.List[string]'
$Existed=@{}

function Write-RavenLog{
  param([string]$Message)
  $line='[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Message
  Write-Host $line
  Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}
function Resolve-VerifiedRepositoryCommit{
  $headers=@{Accept='application/vnd.github+json';'User-Agent'='RAH-Raven-Updater-V2'}
  $commitInfo=Invoke-RestMethod -Headers $headers -Uri "$ApiBase/commits/$RepoBranch"
  $sha=[string]$commitInfo.sha
  if($sha -notmatch '^[0-9a-fA-F]{40}$'){throw 'GitHub returnerte ikke en gyldig Raven commit-SHA.'}
  if(-not $commitInfo.commit.verification.verified){throw 'Siste Raven commit er ikke GitHub-verifisert. Oppdateringen stoppes.'}
  return $sha.ToLowerInvariant()
}
function Get-SafeTargetPath{
  param([string]$RelativePath,[string]$Base=$Root)
  if([string]::IsNullOrWhiteSpace($RelativePath)){throw 'Tom filsti i Raven-manifestet.'}
  if([IO.Path]::IsPathRooted($RelativePath)-or $RelativePath.Contains('..')){throw "Utrygg Raven-fil: $RelativePath"}
  if($RelativePath -notmatch '^[A-Za-z0-9_. /\\-]+$'){throw "Raven-fil har ugyldige tegn: $RelativePath"}
  $normal=$RelativePath.Replace('/',[IO.Path]::DirectorySeparatorChar)
  $target=[IO.Path]::GetFullPath((Join-Path $Base $normal))
  $baseFull=[IO.Path]::GetFullPath($Base+[IO.Path]::DirectorySeparatorChar)
  if(-not $target.StartsWith($baseFull,[StringComparison]::OrdinalIgnoreCase)){throw "Raven-fil peker utenfor tillatt mappe: $RelativePath"}
  return $target
}
function Assert-RavenManifestContract{
  param($Manifest)
  if($Manifest.product-ne'RAH Raven'){throw 'Manifestet tilhører ikke RAH Raven.'}
  if([string]$Manifest.version-ne$ExpectedRavenVersion){throw "Uventet Raven-versjon: $($Manifest.version)"}
  $files=@($Manifest.files|ForEach-Object{[string]$_})
  if($files.Count-lt 1-or $files.Count-gt 500){throw 'Raven-manifestet har uventet filantall.'}
  if(($files|Select-Object -Unique).Count-ne$files.Count){throw 'Raven-manifestet inneholder duplikate filer.'}
  foreach($critical in $CriticalFiles){if($files -notcontains $critical){throw "Raven-manifestet mangler bootstrap-kritisk fil: $critical"}}
  $stable=$Manifest.release_gate.stable_components
  $expected=[ordered]@{raven_vision='0.6';raven_council='0.3';agent_runner='0.3';memory_sync='0.2';mission_control='2.9';project_focus='2.4';raven_core='1.12';raven_now='2.17';raven_studio='2.8'}
  foreach($key in $expected.Keys){if([string]$stable.$key-ne[string]$expected[$key]){throw "Raven Stable core mismatch: $key"}}
  foreach($relative in $files){[void](Get-SafeTargetPath -RelativePath $relative)}
  return $files
}
function Assert-StagedCanonicalCommandCenter{
  param([string]$Stage)
  $ccManifestPath=Get-SafeTargetPath -RelativePath 'RAH-COMMAND-CENTER-VERSION.json' -Base $Stage
  $ccReleasePath=Get-SafeTargetPath -RelativePath 'RAH-CC17-NODE13-STABLE-RELEASE.json' -Base $Stage
  if(-not(Test-Path -LiteralPath $ccManifestPath -PathType Leaf)){throw 'Staged canonical Command Center manifest mangler.'}
  if(-not(Test-Path -LiteralPath $ccReleasePath -PathType Leaf)){throw 'Staged CC v1.7 Stable release-manifest mangler.'}
  $cc=Get-Content -LiteralPath $ccManifestPath -Raw -Encoding UTF8|ConvertFrom-Json
  $release=Get-Content -LiteralPath $ccReleasePath -Raw -Encoding UTF8|ConvertFrom-Json
  if($cc.version-ne'1.7.0'-or $cc.stage-ne'stable'-or $cc.release_gate.status-ne'passed'-or -not $cc.release_gate.runtime_files_frozen){throw 'Staged canonical Command Center er ikke frozen v1.7 Stable.'}
  if($cc.stable_release_manifest-ne'RAH-CC17-NODE13-STABLE-RELEASE.json'){throw 'Staged CC manifest peker paa uventet Stable release.'}
  if($release.commandCenterVersion-ne'1.7.0'-or $release.nodeAgentVersion-ne'1.3.0'-or $release.nodeActionsProtocol-ne'rah-node-actions-v7'-or $release.authProtocol-ne'rah-node-auth-v2'-or $release.policyId-ne'rah-capability-allowlist-v1'){throw 'Staged CC Stable release har uventet identitet/protokoll.'}
  if(($release.authoritySurface.capabilities -join ',')-ne'compute,storage,display,remote-desktop'){throw 'Staged CC capability authority mismatch.'}
  if(($release.authoritySurface.actions -join ',')-ne'storage-summary.read,rustdesk.launch,rustdesk.connect'){throw 'Staged CC action authority mismatch.'}
  if(($release.authoritySurface.businessRoutes -join ',')-ne'/health,/actions,/storage,/launch/rustdesk,/handoff/rustdesk'){throw 'Staged CC route authority mismatch.'}
}
function Restore-OnFailure{
  if($Installed.Count-eq 0){return}
  Write-RavenLog 'Starter rollback av filer installert i denne kjøringen.'
  for($i=$Installed.Count-1;$i-ge0;$i--){
    $relative=$Installed[$i];$target=Get-SafeTargetPath -RelativePath $relative
    try{
      $backup=Get-SafeTargetPath -RelativePath $relative -Base $BackupDir
      if($Existed[$relative]-and(Test-Path -LiteralPath $backup -PathType Leaf)){
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
        Copy-Item -LiteralPath $backup -Destination $target -Force
      }elseif(-not $Existed[$relative]){Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue}
    }catch{Write-RavenLog "Rollback-advarsel for ${relative}: $($_.Exception.Message)"}
  }
}

try{
  Write-RavenLog "Starter eksplisitt RAH Raven Updater v$UpdaterVersion."
  $ResolvedCommit=Resolve-VerifiedRepositoryCommit
  $RawBase="https://raw.githubusercontent.com/$RepoOwner/$RepoName/$ResolvedCommit"
  Write-RavenLog "Låst til GitHub-verifisert immutable commit: $ResolvedCommit"
  $ManifestTemp=Join-Path ([IO.Path]::GetTempPath()) ("rah-raven-manifest-{0}.json" -f [Guid]::NewGuid())
  Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$ManifestName" -OutFile $ManifestTemp
  $manifest=Get-Content -LiteralPath $ManifestTemp -Raw -Encoding UTF8|ConvertFrom-Json
  $files=Assert-RavenManifestContract -Manifest $manifest
  $StageRoot=Join-Path ([IO.Path]::GetTempPath()) ("rah-raven-stage-{0}" -f [Guid]::NewGuid())
  New-Item -ItemType Directory -Path $StageRoot -Force|Out-Null
  foreach($relative in $files){
    $stageTarget=Get-SafeTargetPath -RelativePath $relative -Base $StageRoot
    New-Item -ItemType Directory -Path (Split-Path -Parent $stageTarget) -Force|Out-Null
    $encoded=($relative -split '/'|ForEach-Object{[Uri]::EscapeDataString($_)}) -join '/'
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$encoded" -OutFile $stageTarget
    if(-not(Test-Path -LiteralPath $stageTarget -PathType Leaf)-or(Get-Item -LiteralPath $stageTarget).Length-lt 1){throw "Tom eller manglende staged Raven-fil: $relative"}
  }
  Assert-StagedCanonicalCommandCenter -Stage $StageRoot
  New-Item -ItemType Directory -Path $BackupDir -Force|Out-Null
  foreach($relative in $files){
    $target=Get-SafeTargetPath -RelativePath $relative
    $stageTarget=Get-SafeTargetPath -RelativePath $relative -Base $StageRoot
    $exists=Test-Path -LiteralPath $target -PathType Leaf;$Existed[$relative]=[bool]$exists
    if($exists){$backup=Get-SafeTargetPath -RelativePath $relative -Base $BackupDir;New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force|Out-Null;Copy-Item -LiteralPath $target -Destination $backup -Force}
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
    $installTemp="$target.rah-v2-install"
    Copy-Item -LiteralPath $stageTarget -Destination $installTemp -Force
    Move-Item -LiteralPath $installTemp -Destination $target -Force
    $Installed.Add($relative)
  }
  $manifestTarget=Get-SafeTargetPath -RelativePath $ManifestName
  if(Test-Path -LiteralPath $manifestTarget -PathType Leaf){$manifestBackup=Join-Path $BackupDir $ManifestName;Copy-Item -LiteralPath $manifestTarget -Destination $manifestBackup -Force}
  Copy-Item -LiteralPath $ManifestTemp -Destination "$manifestTarget.rah-v2-install" -Force
  Move-Item -LiteralPath "$manifestTarget.rah-v2-install" -Destination $manifestTarget -Force
  Write-RavenLog "Raven $ExpectedRavenVersion installert fra immutable commit $ResolvedCommit. Filer: $($files.Count)."
  if(-not $SkipCommandCenterSync){
    $ccUpdater=Get-SafeTargetPath -RelativePath 'UPDATE-RAH-COMMAND-CENTER.ps1'
    if(-not(Test-Path -LiteralPath $ccUpdater -PathType Leaf)){throw 'Canonical Command Center updater mangler etter Raven install.'}
    Write-RavenLog 'Kjører canonical Command Center-sync fra den nettopp installerte immutable Raven-pakken.'
    & $ccUpdater -NoStart
    if($LASTEXITCODE-ne0){throw "Command Center-sync feilet med kode $LASTEXITCODE"}
  }
  Write-Host "RAH Raven Updater v$UpdaterVersion fullført fra $ResolvedCommit." -ForegroundColor Green
  Write-Host 'Fremtidige V2-kjøringer bruker én verifisert commit-SHA; mutable raw main brukes ikke.' -ForegroundColor Yellow
  if(-not $NoStart){
    $launcher=Get-SafeTargetPath -RelativePath 'START-RAH-RAVEN-V2.bat'
    if(Test-Path -LiteralPath $launcher -PathType Leaf){Start-Process -FilePath $launcher -WorkingDirectory $Root}
  }
}catch{
  Write-RavenLog "FEIL: $($_.Exception.Message)"
  Restore-OnFailure
  Write-Host 'RAH Raven Updater v2 stoppet trygt.' -ForegroundColor Red
  exit 1
}finally{
  if($ManifestTemp){Remove-Item -LiteralPath $ManifestTemp -Force -ErrorAction SilentlyContinue}
  if($StageRoot){Remove-Item -LiteralPath $StageRoot -Recurse -Force -ErrorAction SilentlyContinue}
}

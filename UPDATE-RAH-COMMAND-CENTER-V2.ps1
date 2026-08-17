param([switch]$NoStart)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

$UpdaterVersion='2.0.0'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoOwner='NilsRa73';$RepoName='rah-platform';$RepoBranch='main'
$ApiBase="https://api.github.com/repos/$RepoOwner/$RepoName"
$ManifestName='RAH-COMMAND-CENTER-VERSION.json'
$IntegrityManifestName='RAH-CC17-PACKAGE-INTEGRITY.json'
$StableReleaseName='RAH-CC17-NODE13-STABLE-RELEASE.json'
$ExpectedCcVersion='1.7.0';$ExpectedRavenVersion='2.0.32'
$AllowedPackageFiles=@(
  'RAH-COMMAND-CENTER-V1.7.html','RAH-COMMAND-CENTER-V1.7-CANDIDATE.html','RAH-COMMAND-CENTER-V1.2.html',
  'rah-command-center-core.js','rah-command-center-core-v1.3.js','rah-command-center-core-v1.4.js','rah-command-center-core-v1.5-candidate.js','rah-command-center-core-v1.5.js','rah-command-center-core-v1.6-candidate.js','rah-command-center-core-v1.6.js','rah-command-center-core-v1.7-candidate.js','rah-command-center-core-v1.7.js',
  'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat',
  'rah-node-agent.py','rah-node-agent-v0.9.py','rah-node-agent-v1.0-candidate.py','rah-node-agent-v1.0.py','rah-node-agent-v1.1-candidate.py','rah-node-agent-v1.1.py','rah-node-agent-v1.2-candidate.py','rah-node-agent-v1.3-candidate.py','rah-node-agent-v1.3.py',
  'START-RAH-NODE-AGENT.bat','START-RAH-NODE-AGENT.sh','RAH-CC17-NODE13-STABLE-RELEASE.json',$IntegrityManifestName
)
$Stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir=Join-Path (Join-Path $Root '.rah-backups') ("command-center-v2-"+$Stamp)
$LogFile=Join-Path $Root 'rah-command-center-update.log'
$ManifestTemp=$null;$IntegrityTemp=$null;$ReleaseTemp=$null;$StageRoot=$null
$Installed=New-Object 'System.Collections.Generic.List[string]';$Existed=@{}

function Write-CcLog{param([string]$Message)$line='[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Message;Write-Host $line;Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8}
function Resolve-VerifiedRepositoryCommit{
  $headers=@{Accept='application/vnd.github+json';'User-Agent'='RAH-Command-Center-Updater-V2'}
  $commitInfo=Invoke-RestMethod -Headers $headers -Uri "$ApiBase/commits/$RepoBranch"
  $sha=[string]$commitInfo.sha
  if($sha -notmatch '^[0-9a-fA-F]{40}$'){throw 'GitHub returnerte ikke en gyldig Command Center commit-SHA.'}
  if(-not $commitInfo.commit.verification.verified){throw 'Siste repository-commit er ikke GitHub-verifisert. CC-oppdateringen stoppes.'}
  return $sha.ToLowerInvariant()
}
function Get-SafeTargetPath{
  param([string]$RelativePath,[string]$Base=$Root)
  if([string]::IsNullOrWhiteSpace($RelativePath)){throw 'Tom filsti i Command Center-manifestet.'}
  if([IO.Path]::IsPathRooted($RelativePath)-or $RelativePath.Contains('..')){throw "Utrygg Command Center-fil: $RelativePath"}
  if($RelativePath -notmatch '^[A-Za-z0-9_. /\\-]+$'){throw "Command Center-fil har ugyldige tegn: $RelativePath"}
  $normal=$RelativePath.Replace('/',[IO.Path]::DirectorySeparatorChar);$target=[IO.Path]::GetFullPath((Join-Path $Base $normal));$baseFull=[IO.Path]::GetFullPath($Base+[IO.Path]::DirectorySeparatorChar)
  if(-not $target.StartsWith($baseFull,[StringComparison]::OrdinalIgnoreCase)){throw "Command Center-fil peker utenfor tillatt mappe: $RelativePath"}
  return $target
}
function Get-GitBlobSha1{
  param([string]$Path)
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Fil mangler for blob-hash: $Path"}
  $bytes=[IO.File]::ReadAllBytes($Path);$prefix=[Text.Encoding]::UTF8.GetBytes(('blob {0}' -f $bytes.Length)+[char]0);$combined=New-Object byte[] ($prefix.Length+$bytes.Length);[Array]::Copy($prefix,0,$combined,0,$prefix.Length);[Array]::Copy($bytes,0,$combined,$prefix.Length,$bytes.Length);$sha=[Security.Cryptography.SHA1]::Create();try{return (($sha.ComputeHash($combined)|ForEach-Object{$_.ToString('x2')}) -join '')}finally{$sha.Dispose()}
}
function Assert-FixedPackageContract{
  param($Manifest)
  $remote=@($Manifest.package_files|ForEach-Object{[string]$_})
  if($remote.Count-ne$AllowedPackageFiles.Count){throw 'Command Center-pakken har uventet antall filer.'}
  if(($remote|Select-Object -Unique).Count-ne$remote.Count){throw 'Command Center-pakken har duplikate filer.'}
  foreach($required in $AllowedPackageFiles){if($remote -notcontains $required){throw "Command Center-pakken mangler tillatt fil: $required"}}
  foreach($candidate in $remote){if($AllowedPackageFiles -notcontains $candidate){throw "Command Center-manifestet forsøker å legge til ikke-tillatt fil: $candidate"};[void](Get-SafeTargetPath -RelativePath $candidate)}
}
function Assert-CanonicalManifest{
  param($Manifest)
  if($Manifest.product-ne'RAH Raven Command Center'-or $Manifest.version-ne$ExpectedCcVersion-or $Manifest.stage-ne'stable'){throw 'Canonical Command Center manifest har uventet identitet/stage.'}
  if($Manifest.raven_contract-ne$ExpectedRavenVersion-or $Manifest.release_gate.status-ne'passed'-or -not $Manifest.release_gate.runtime_files_frozen){throw 'Canonical Command Center manifest er ikke frozen Stable.'}
  if($Manifest.entry-ne'RAH-COMMAND-CENTER-V1.7.html'-or $Manifest.runtime-ne'rah-command-center-core-v1.7.js'){throw 'Canonical Command Center entry/runtime mismatch.'}
  if($Manifest.stable_release_manifest-ne$StableReleaseName){throw 'Canonical Command Center Stable release-manifest mismatch.'}
  if($Manifest.package_integrity_manifest-ne$IntegrityManifestName){throw 'Canonical Command Center integritetsmanifest mismatch.'}
  Assert-FixedPackageContract -Manifest $Manifest
}
function Assert-StableReleaseContract{
  param($Release)
  if($Release.stage-ne'stable-release'-or $Release.commandCenterVersion-ne'1.7.0'-or $Release.nodeAgentVersion-ne'1.3.0'){throw 'CC Stable release identity mismatch.'}
  if($Release.nodeActionsProtocol-ne'rah-node-actions-v7'-or $Release.authProtocol-ne'rah-node-auth-v2'-or $Release.policyId-ne'rah-capability-allowlist-v1'){throw 'CC Stable release protocol/policy mismatch.'}
  if(($Release.authoritySurface.capabilities -join ',')-ne'compute,storage,display,remote-desktop'){throw 'CC capability authority mismatch.'}
  if(($Release.authoritySurface.actions -join ',')-ne'storage-summary.read,rustdesk.launch,rustdesk.connect'){throw 'CC action authority mismatch.'}
  if(($Release.authoritySurface.businessRoutes -join ',')-ne'/health,/actions,/storage,/launch/rustdesk,/handoff/rustdesk'){throw 'CC route authority mismatch.'}
}
function Assert-IntegrityManifest{
  param($Integrity)
  if($Integrity.product-ne'RAH Raven Command Center Package Integrity'-or $Integrity.schemaVersion-ne1-or $Integrity.canonical_version-ne$ExpectedCcVersion-or $Integrity.algorithm-ne'git-blob-sha1'){throw 'CC package-integritetsmanifest har uventet kontrakt.'}
  if($Integrity.self_path-ne$IntegrityManifestName-or $Integrity.self_hashed-ne$false){throw 'CC package-integritetsmanifest har ugyldig self-kontrakt.'}
  $rows=@($Integrity.hashed_files);$expected=@($AllowedPackageFiles|Where-Object{$_-ne$IntegrityManifestName})
  if($rows.Count-ne$expected.Count){throw 'CC integritetsmanifest har uventet antall hash-rader.'}
  $seen=@{};foreach($row in $rows){$path=[string]$row.path;$sha=[string]$row.gitBlobSha;if($expected -notcontains $path){throw "Integritetsmanifest har ikke-tillatt fil: $path"};if($seen.ContainsKey($path)){throw "Integritetsmanifest har duplikat: $path"};if($sha -notmatch '^[0-9a-f]{40}$'){throw "Integritetsmanifest har ugyldig Git blob SHA: $path"};$seen[$path]=$sha}
  foreach($path in $expected){if(-not $seen.ContainsKey($path)){throw "Integritetsmanifest mangler hash: $path"}}
  return $seen
}
function Restore-OnFailure{
  if($Installed.Count-eq0){return};Write-CcLog 'Starter rollback av CC-filer installert i denne kjøringen.'
  for($i=$Installed.Count-1;$i-ge0;$i--){$relative=$Installed[$i];$target=Get-SafeTargetPath -RelativePath $relative;try{$backup=Get-SafeTargetPath -RelativePath $relative -Base $BackupDir;if($Existed[$relative]-and(Test-Path -LiteralPath $backup -PathType Leaf)){Copy-Item -LiteralPath $backup -Destination $target -Force}elseif(-not $Existed[$relative]){Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue}}catch{Write-CcLog "Rollback-advarsel for ${relative}: $($_.Exception.Message)"}}
}
function Install-CommandCenterShortcut{param([string]$EntryPath)$desktop=[Environment]::GetFolderPath('Desktop');$shortcutPath=Join-Path $desktop 'RAH Command Center.lnk';$launcher=Join-Path $Root 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat';$target=if(Test-Path -LiteralPath $launcher -PathType Leaf){$launcher}else{$EntryPath};$shell=New-Object -ComObject WScript.Shell;$shortcut=$shell.CreateShortcut($shortcutPath);$shortcut.TargetPath=$target;$shortcut.WorkingDirectory=$Root;$shortcut.Description='Start RAH Raven Command Center v1.7 Stable';$shortcut.WindowStyle=1;$shortcut.Save();Write-CcLog "Skrivebordssnarvei klar: $shortcutPath"}

try{
  Write-CcLog "Starter eksplisitt RAH Command Center Updater v$UpdaterVersion."
  $ResolvedCommit=Resolve-VerifiedRepositoryCommit;$RawBase="https://raw.githubusercontent.com/$RepoOwner/$RepoName/$ResolvedCommit";Write-CcLog "Låst til GitHub-verifisert immutable commit: $ResolvedCommit"
  $ManifestTemp=Join-Path ([IO.Path]::GetTempPath()) ("rah-cc-manifest-{0}.json" -f [Guid]::NewGuid());Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$ManifestName" -OutFile $ManifestTemp;$manifest=Get-Content -LiteralPath $ManifestTemp -Raw -Encoding UTF8|ConvertFrom-Json;Assert-CanonicalManifest -Manifest $manifest
  $ReleaseTemp=Join-Path ([IO.Path]::GetTempPath()) ("rah-cc-release-{0}.json" -f [Guid]::NewGuid());Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$StableReleaseName" -OutFile $ReleaseTemp;$release=Get-Content -LiteralPath $ReleaseTemp -Raw -Encoding UTF8|ConvertFrom-Json;Assert-StableReleaseContract -Release $release
  $IntegrityTemp=Join-Path ([IO.Path]::GetTempPath()) ("rah-cc-integrity-{0}.json" -f [Guid]::NewGuid());Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$IntegrityManifestName" -OutFile $IntegrityTemp;$integrity=Get-Content -LiteralPath $IntegrityTemp -Raw -Encoding UTF8|ConvertFrom-Json;$expectedHashes=Assert-IntegrityManifest -Integrity $integrity
  $StageRoot=Join-Path ([IO.Path]::GetTempPath()) ("rah-cc-stage-{0}" -f [Guid]::NewGuid());New-Item -ItemType Directory -Path $StageRoot -Force|Out-Null
  foreach($relative in $manifest.package_files){$relative=[string]$relative;$stageTarget=Get-SafeTargetPath -RelativePath $relative -Base $StageRoot;New-Item -ItemType Directory -Path (Split-Path -Parent $stageTarget) -Force|Out-Null;if($relative-eq$IntegrityManifestName){Copy-Item -LiteralPath $IntegrityTemp -Destination $stageTarget -Force}else{$encoded=($relative -split '/'|ForEach-Object{[Uri]::EscapeDataString($_)}) -join '/';Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$encoded" -OutFile $stageTarget;$actual=Get-GitBlobSha1 -Path $stageTarget;if($actual-ne[string]$expectedHashes[$relative]){throw "Git blob-integritet feilet for $relative"}};if(-not(Test-Path -LiteralPath $stageTarget -PathType Leaf)-or(Get-Item -LiteralPath $stageTarget).Length-lt1){throw "Tom eller manglende staged CC-fil: $relative"}}
  Write-CcLog "Alle $($manifest.package_files.Count) packagefiler er staged; 25 Git blob-pins er verifisert før installasjon."
  New-Item -ItemType Directory -Path $BackupDir -Force|Out-Null
  foreach($relative in $manifest.package_files){$relative=[string]$relative;$target=Get-SafeTargetPath -RelativePath $relative;$stageTarget=Get-SafeTargetPath -RelativePath $relative -Base $StageRoot;$exists=Test-Path -LiteralPath $target -PathType Leaf;$Existed[$relative]=[bool]$exists;if($exists){$backup=Get-SafeTargetPath -RelativePath $relative -Base $BackupDir;New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force|Out-Null;Copy-Item -LiteralPath $target -Destination $backup -Force};New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null;$installTemp="$target.rah-v2-install";Copy-Item -LiteralPath $stageTarget -Destination $installTemp -Force;Move-Item -LiteralPath $installTemp -Destination $target -Force;$Installed.Add($relative)}
  $manifestTarget=Get-SafeTargetPath -RelativePath $ManifestName;if(Test-Path -LiteralPath $manifestTarget -PathType Leaf){Copy-Item -LiteralPath $manifestTarget -Destination (Join-Path $BackupDir $ManifestName) -Force};Copy-Item -LiteralPath $ManifestTemp -Destination "$manifestTarget.rah-v2-install" -Force;Move-Item -LiteralPath "$manifestTarget.rah-v2-install" -Destination $manifestTarget -Force
  $entryPath=Get-SafeTargetPath -RelativePath ([string]$manifest.entry);if(-not(Test-Path -LiteralPath $entryPath -PathType Leaf)){throw 'CC entry mangler etter installasjon.'};Install-CommandCenterShortcut -EntryPath $entryPath
  Write-CcLog "Command Center v1.7 Stable package installert fra immutable commit $ResolvedCommit med full pre-install integrity gate."
  if(-not $NoStart){Start-Process -FilePath $entryPath -WorkingDirectory $Root}
}catch{Write-CcLog "FEIL: $($_.Exception.Message)";Restore-OnFailure;Write-Host 'Command Center Updater v2 stoppet trygt.' -ForegroundColor Red;exit 1}
finally{if($ManifestTemp){Remove-Item -LiteralPath $ManifestTemp -Force -ErrorAction SilentlyContinue};if($ReleaseTemp){Remove-Item -LiteralPath $ReleaseTemp -Force -ErrorAction SilentlyContinue};if($IntegrityTemp){Remove-Item -LiteralPath $IntegrityTemp -Force -ErrorAction SilentlyContinue};if($StageRoot){Remove-Item -LiteralPath $StageRoot -Recurse -Force -ErrorAction SilentlyContinue}}

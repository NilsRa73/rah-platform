param([switch]$NoStart)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoOwner="NilsRa73";$RepoName="rah-platform";$ReleaseCommit="a6b77f93dca5f774cdb76deb707edc71f86638a1"
$ApiBase="https://api.github.com/repos/$RepoOwner/$RepoName"
$ManifestName="RAH-COMMAND-CENTER-VERSION.json"
$AllowedPackageFiles=@(
  "RAH-COMMAND-CENTER-V2.1.html",
  "RAH-COMMAND-CENTER-V2.1-CANDIDATE.html",
  "rah-command-center-core-v2.1-candidate.js",
  "rah-command-center-core-v2.1.js",
  "RAH-CC21-FLEET-SNAPSHOT-CANDIDATE.json",
  "RAH-CC21-NODE13-STABLE-RELEASE.json",
  "RAH-COMMAND-CENTER-V2.0.html",
  "RAH-COMMAND-CENTER-V2.0-CANDIDATE.html",
  "rah-command-center-core-v2.0-candidate.js",
  "rah-command-center-core-v2.0.js",
  "RAH-CC20-PRECOMMITTED-REQUESTER-CONTEXT-CANDIDATE.json",
  "RAH-CC20-NODE13-STABLE-RELEASE.json",
  "RAH-COMMAND-CENTER-V1.9.html",
  "RAH-COMMAND-CENTER-V1.9-CANDIDATE.html",
  "rah-command-center-core-v1.9-candidate.js",
  "rah-command-center-core-v1.9.js",
  "RAH-CC19-IMMUTABLE-MUTATING-INTENT-CANDIDATE.json",
  "RAH-CC19-NODE13-STABLE-RELEASE.json",
  "RAH-COMMAND-CENTER-V1.8.html",
  "RAH-COMMAND-CENTER-V1.8-CANDIDATE.html",
  "RAH-COMMAND-CENTER-V1.7.html",
  "RAH-COMMAND-CENTER-V1.7-CANDIDATE.html",
  "RAH-COMMAND-CENTER-V1.2.html",
  "rah-command-center-core.js",
  "rah-command-center-core-v1.3.js",
  "rah-command-center-core-v1.4.js",
  "rah-command-center-core-v1.5-candidate.js",
  "rah-command-center-core-v1.5.js",
  "rah-command-center-core-v1.6-candidate.js",
  "rah-command-center-core-v1.6.js",
  "rah-command-center-core-v1.7-candidate.js",
  "rah-command-center-core-v1.7.js",
  "rah-command-center-core-v1.8-candidate.js",
  "rah-command-center-core-v1.8.js",
  "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat",
  "rah-node-agent.py",
  "rah-node-agent-v0.9.py",
  "rah-node-agent-v1.0-candidate.py",
  "rah-node-agent-v1.0.py",
  "rah-node-agent-v1.1-candidate.py",
  "rah-node-agent-v1.1.py",
  "rah-node-agent-v1.2-candidate.py",
  "rah-node-agent-v1.3-candidate.py",
  "rah-node-agent-v1.3.py",
  "START-RAH-NODE-AGENT.bat",
  "START-RAH-NODE-AGENT.sh",
  "RAH-CC17-NODE13-STABLE-RELEASE.json",
  "RAH-CC18-ONE-SHOT-MUTATING-APPROVAL-CANDIDATE.json",
  "RAH-CC18-NODE13-STABLE-RELEASE.json"
)
$RequiredTreeFiles=@($ManifestName)+$AllowedPackageFiles
$Stamp=(Get-Date -Format "yyyyMMdd-HHmmss")+"-"+[Guid]::NewGuid().ToString("N")
$BackupDir=Join-Path (Join-Path $Root ".rah-backups") ("command-center-"+$Stamp)
$StagingDir=Join-Path (Join-Path $Root ".rah-staging") ("command-center-"+$Stamp)
$LogFile=Join-Path $Root "rah-command-center-update.log"
$StageVerificationComplete=$false
$ActivationStarted=$false
$ActivationCommitted=$false
$TransactionFiles=$null
$OriginalState=$null

function Write-CcLog{param([string]$Message)$line="[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Message;Write-Host $line;Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8}
function Resolve-VerifiedRepositoryCommit{
  $headers=@{Accept="application/vnd.github+json";"User-Agent"="RAH-Raven-Command-Center-Updater"}
  $commitInfo=Invoke-RestMethod -Headers $headers -Uri "$ApiBase/commits/$ReleaseCommit"
  $sha=[string]$commitInfo.sha;$treeSha=[string]$commitInfo.commit.tree.sha
  if($sha -notmatch '^[0-9a-fA-F]{40}$'){throw "GitHub returnerte ikke en gyldig commit-SHA for Command Center."}
  if($sha.ToLowerInvariant()-ne$ReleaseCommit.ToLowerInvariant()){throw "GitHub returnerte en annen commit enn den pinnede CC 2.1-releasen."}
  if(-not $commitInfo.commit.verification.verified){throw "Pinnet Command Center-release er ikke GitHub-verifisert. Oppdateringen stoppes."}
  if($treeSha -notmatch '^[0-9a-fA-F]{40}$'){throw "Pinnet Command Center-release mangler en gyldig Git tree-SHA."}
  return [PSCustomObject]@{Sha=$sha.ToLowerInvariant();TreeSha=$treeSha.ToLowerInvariant()}
}
function Resolve-PackageBlobMap{
  param([string]$TreeSha)
  if($TreeSha -notmatch '^[0-9a-fA-F]{40}$'){throw "Ugyldig Git tree-SHA for Command Center-pakken."}
  $headers=@{Accept="application/vnd.github+json";"User-Agent"="RAH-Raven-Command-Center-Updater"}
  $treeInfo=Invoke-RestMethod -Headers $headers -Uri "${ApiBase}/git/trees/${TreeSha}?recursive=1"
  if($treeInfo.truncated){throw "GitHub returnerte et trunkert Git tree for Command Center-releasen."}
  $map=@{}
  foreach($item in @($treeInfo.tree)){
    $path=[string]$item.path
    if($RequiredTreeFiles -notcontains $path){continue}
    if(([string]$item.type)-ne"blob"){throw "Command Center release-tree har ikke blob-type for: $path"}
    if(([string]$item.mode)-ne"100644"){throw "Command Center release-tree har uventet Git mode for: $path"}
    $objectSha=[string]$item.sha
    if($objectSha -notmatch '^[0-9a-fA-F]{40}$'){throw "Command Center release-tree har ugyldig blob-SHA for: $path"}
    if($map.ContainsKey($path)){throw "Command Center release-tree har duplikat pakkesti: $path"}
    $map[$path]=$objectSha.ToLowerInvariant()
  }
  if($map.Count-ne$RequiredTreeFiles.Count){throw "Command Center release-tree mangler forventede manifest-/pakkefiler."}
  foreach($required in $RequiredTreeFiles){if(-not $map.ContainsKey($required)){throw "Command Center release-tree mangler forventet fil: $required"}}
  return $map
}
function Get-GitBlobSha{
  param([string]$Path)
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Kan ikke verifisere manglende fil: $Path"}
  $bytes=[IO.File]::ReadAllBytes($Path);$header=[Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
  $payload=New-Object byte[] ($header.Length+$bytes.Length)
  [Buffer]::BlockCopy($header,0,$payload,0,$header.Length);[Buffer]::BlockCopy($bytes,0,$payload,$header.Length,$bytes.Length)
  $sha1=[Security.Cryptography.SHA1]::Create()
  try{$digest=$sha1.ComputeHash($payload);return([BitConverter]::ToString($digest)).Replace("-","").ToLowerInvariant()}finally{$sha1.Dispose()}
}
function Get-SafeChildPath{
  param([string]$Base,[string]$RelativePath)
  if([string]::IsNullOrWhiteSpace($RelativePath)){throw "Tom filsti i Command Center-transaksjonen."}
  if([IO.Path]::IsPathRooted($RelativePath)-or $RelativePath.Contains("..")){throw "Utrygg Command Center-fil: $RelativePath"}
  $normal=$RelativePath.Replace("/",[IO.Path]::DirectorySeparatorChar)
  $baseFull=[IO.Path]::GetFullPath($Base+[IO.Path]::DirectorySeparatorChar);$target=[IO.Path]::GetFullPath((Join-Path $Base $normal))
  if(-not $target.StartsWith($baseFull,[StringComparison]::OrdinalIgnoreCase)){throw "Command Center-fil peker utenfor transaksjonsmappen: $RelativePath"}
  return $target
}
function Get-SafeTargetPath{param([string]$RelativePath)return Get-SafeChildPath -Base $Root -RelativePath $RelativePath}
function Get-FileHashSafe{param([string]$Path)if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};return(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-FixedPackageContract{param($Manifest)$remote=@($Manifest.package_files|ForEach-Object{[string]$_});if($remote.Count-ne$AllowedPackageFiles.Count){throw "Command Center-pakken har uventet antall filer."};foreach($required in $AllowedPackageFiles){if($remote -notcontains $required){throw "Command Center-pakken mangler tillatt fil: $required"}};foreach($candidate in $remote){if($AllowedPackageFiles -notcontains $candidate){throw "Command Center-manifestet forsøker å legge til en ikke-tillatt fil: $candidate"}}}
function Assert-StableReleaseContract{param($Release)if($Release.stage-ne"stable-release"){throw "Stable release-manifest har feil stage."};if($Release.commandCenterVersion-ne"2.1.0"-or $Release.nodeAgentVersion-ne"1.3.0"){throw "Stable release-manifest har uventet CC/Node-versjon."};if($Release.nodeActionsProtocol-ne"rah-node-actions-v7"-or $Release.authProtocol-ne"rah-node-auth-v2"-or $Release.policyId-ne"rah-capability-allowlist-v1"){throw "Stable release-manifest har uventet protokoll/policy."};$caps=@($Release.authoritySurface.capabilities);$actions=@($Release.authoritySurface.actions);$routes=@($Release.authoritySurface.businessRoutes);if(($caps -join ",")-ne"compute,storage,display,remote-desktop"){throw "Stable release har uventet capability authority."};if(($actions -join ",")-ne"storage-summary.read,rustdesk.launch,rustdesk.connect"){throw "Stable release har uventet action authority."};if(($routes -join ",")-ne"/health,/actions,/storage,/launch/rustdesk,/handoff/rustdesk"){throw "Stable release har uventet route authority."};if($Release.fleetSnapshot.version-ne"rah-cc-fleet-snapshot-v1"-or $Release.fleetSnapshot.scope-ne"already-enrolled-devices-only"-or -not $Release.fleetSnapshot.freshNodeTokenRequiredPerRefreshClick-or -not $Release.fleetSnapshot.tokenProofAuthenticationRequired-or -not $Release.fleetSnapshot.sessionMatchRequired-or $Release.fleetSnapshot.tokenPersistence-or $Release.fleetSnapshot.snapshotPersistence-or $Release.fleetSnapshot.backgroundPolling-or $Release.fleetSnapshot.networkDiscovery-or $Release.fleetSnapshot.automaticRemoteControl){throw "Stable release har uventet Fleet Snapshot boundary."}}
function Download-StagedFile{
  param([string]$RelativePath,[string]$RawBase,$BlobMap)
  $staged=Get-SafeChildPath -Base $StagingDir -RelativePath $RelativePath;New-Item -ItemType Directory -Path (Split-Path -Parent $staged) -Force|Out-Null
  $encodedPath=($RelativePath -split "/"|ForEach-Object{[Uri]::EscapeDataString($_)}) -join "/"
  Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$encodedPath" -OutFile $staged
  if(-not(Test-Path -LiteralPath $staged -PathType Leaf)-or(Get-Item -LiteralPath $staged).Length-lt1){throw "Tom eller manglende staged fil: $RelativePath"}
  $stagedBlob=Get-GitBlobSha -Path $staged;$expectedBlob=[string]$BlobMap[$RelativePath]
  if([string]::IsNullOrWhiteSpace($expectedBlob)-or $stagedBlob-ne$expectedBlob){throw "Staged fil matcher ikke Git blob i verifisert release-tree: $RelativePath"}
  return $staged
}
function Backup-Transaction{
  param([string[]]$Files)
  $state=@{};New-Item -ItemType Directory -Path $BackupDir -Force|Out-Null
  foreach($relative in $Files){
    $target=Get-SafeTargetPath -RelativePath $relative
    if((Test-Path -LiteralPath $target)-and -not(Test-Path -LiteralPath $target -PathType Leaf)){throw "Transaksjonsmål er ikke en vanlig fil: $relative"}
    if(Test-Path -LiteralPath $target -PathType Leaf){
      $originalHash=Get-FileHashSafe -Path $target;$backup=Get-SafeChildPath -Base $BackupDir -RelativePath $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force|Out-Null;Copy-Item -LiteralPath $target -Destination $backup -Force
      if((Get-FileHashSafe -Path $backup)-ne$originalHash){throw "Backup-verifisering feilet: $relative"}
      $state[$relative]=[PSCustomObject]@{Existed=$true;Sha256=$originalHash}
    }else{$state[$relative]=[PSCustomObject]@{Existed=$false;Sha256=$null}}
  }
  return $state
}
function Restore-Transaction{
  param([string[]]$Files,$OriginalState)
  $errors=@()
  foreach($relative in $Files){
    try{
      $target=Get-SafeTargetPath -RelativePath $relative;$state=$OriginalState[$relative]
      if($null-eq$state){throw "Mangler original state"}
      if($state.Existed){
        $backup=Get-SafeChildPath -Base $BackupDir -RelativePath $relative
        if(-not(Test-Path -LiteralPath $backup -PathType Leaf)){throw "Mangler backup"}
        if((Get-FileHashSafe -Path $backup)-ne$state.Sha256){throw "Backup hash mismatch"}
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null;$restoreTemp="$target.rah-restore-$Stamp"
        try{Copy-Item -LiteralPath $backup -Destination $restoreTemp -Force;if((Get-FileHashSafe -Path $restoreTemp)-ne$state.Sha256){throw "Restore temp hash mismatch"};Move-Item -LiteralPath $restoreTemp -Destination $target -Force}finally{Remove-Item -LiteralPath $restoreTemp -Force -ErrorAction SilentlyContinue}
      }elseif(Test-Path -LiteralPath $target){if(-not(Test-Path -LiteralPath $target -PathType Leaf)){throw "Kan ikke fjerne ikke-fil under rollback"};Remove-Item -LiteralPath $target -Force}
    }catch{$errors+=($relative+": "+$_.Exception.Message)}
  }
  if($errors.Count-gt0){throw("Rollback failed: "+($errors-join" | "))}
}
function Activate-Transaction{
  param([string[]]$Files,$BlobMap)
  $updated=0;$unchanged=0
  foreach($relative in $Files){
    $staged=Get-SafeChildPath -Base $StagingDir -RelativePath $relative;$target=Get-SafeTargetPath -RelativePath $relative
    if(-not(Test-Path -LiteralPath $staged -PathType Leaf)){throw "Mangler staged aktiveringsfil: $relative"}
    if((Test-Path -LiteralPath $target)-and -not(Test-Path -LiteralPath $target -PathType Leaf)){throw "Aktiveringsmål er ikke en vanlig fil: $relative"}
    $stagedHash=Get-FileHashSafe -Path $staged;$currentHash=Get-FileHashSafe -Path $target
    if($currentHash-and $currentHash-eq$stagedHash){$unchanged++;continue}
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null;$activateTemp="$target.rah-activate-$Stamp"
    try{
      Copy-Item -LiteralPath $staged -Destination $activateTemp -Force
      $activationBlob=Get-GitBlobSha -Path $activateTemp;$expectedBlob=[string]$BlobMap[$relative]
      if($activationBlob-ne$expectedBlob){throw "Activation temp Git blob mismatch: $relative"}
      Move-Item -LiteralPath $activateTemp -Destination $target -Force;$updated++
    }finally{Remove-Item -LiteralPath $activateTemp -Force -ErrorAction SilentlyContinue}
  }
  foreach($relative in $Files){$target=Get-SafeTargetPath -RelativePath $relative;if((Get-GitBlobSha -Path $target)-ne([string]$BlobMap[$relative])){throw "Post-activation Git blob mismatch: $relative"}}
  return [PSCustomObject]@{Updated=$updated;Unchanged=$unchanged}
}
function Install-CommandCenterShortcut{param([string]$EntryPath)$desktop=[Environment]::GetFolderPath("Desktop");$shortcutPath=Join-Path $desktop "RAH Command Center.lnk";$launcher=Join-Path $Root "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat";$target=if(Test-Path -LiteralPath $launcher -PathType Leaf){$launcher}else{$EntryPath};$shell=New-Object -ComObject WScript.Shell;$shortcut=$shell.CreateShortcut($shortcutPath);$shortcut.TargetPath=$target;$shortcut.WorkingDirectory=$Root;$shortcut.Description="Start RAH Raven Command Center v2.1 Stable";$shortcut.WindowStyle=1;$shortcut.Save();Write-CcLog "Skrivebordssnarvei klar: $shortcutPath"}

try{
  Write-CcLog "Starter RAH Command Center v2.1 transactional package update."
  $releaseIdentity=Resolve-VerifiedRepositoryCommit;$ResolvedCommit=[string]$releaseIdentity.Sha;$ResolvedTree=[string]$releaseIdentity.TreeSha
  $PackageBlobMap=Resolve-PackageBlobMap -TreeSha $ResolvedTree;$RawBase="https://raw.githubusercontent.com/$RepoOwner/$RepoName/$ResolvedCommit"
  New-Item -ItemType Directory -Path $StagingDir -Force|Out-Null
  $stagedManifest=Download-StagedFile -RelativePath $ManifestName -RawBase $RawBase -BlobMap $PackageBlobMap
  $manifest=Get-Content -LiteralPath $stagedManifest -Raw -Encoding UTF8|ConvertFrom-Json
  if($manifest.product-ne"RAH Raven Command Center"){throw "Manifestet tilhører ikke RAH Raven Command Center."}
  if($manifest.version-ne"2.1.0"-or $manifest.stage-ne"stable"){throw "Pinnet Command Center-release er ikke canonical v2.1 Stable."}
  if($manifest.release_gate.status-ne"passed"-or -not$manifest.release_gate.runtime_files_frozen){throw "Command Center har ikke bestått frozen Stable release gate."}
  if($manifest.raven_contract-ne"2.0.32"){throw "Command Center-manifestet peker på en uventet Raven-kontrakt."}
  if([string]$manifest.entry-ne"RAH-COMMAND-CENTER-V2.1.html"-or[string]$manifest.runtime-ne"rah-command-center-core-v2.1.js"){throw "Canonical entry/runtime er uventet."}
  Assert-FixedPackageContract -Manifest $manifest
  foreach($relativePath in $manifest.package_files){$null=Download-StagedFile -RelativePath ([string]$relativePath) -RawBase $RawBase -BlobMap $PackageBlobMap}
  $releasePath=[string]$manifest.stable_release_manifest;if($releasePath-ne"RAH-CC21-NODE13-STABLE-RELEASE.json"){throw "Canonical manifest peker ikke paa forventet Stable release."}
  $stagedRelease=Get-SafeChildPath -Base $StagingDir -RelativePath $releasePath
  $release=Get-Content -LiteralPath $stagedRelease -Raw -Encoding UTF8|ConvertFrom-Json;Assert-StableReleaseContract -Release $release
  $TransactionFiles=@($manifest.package_files|ForEach-Object{[string]$_})+@($ManifestName)
  if($TransactionFiles.Count-ne50-or@($TransactionFiles|Select-Object -Unique).Count-ne50){throw "Command Center transaction set er ikke eksakt 50 unike filer."}
  foreach($relative in $TransactionFiles){$staged=Get-SafeChildPath -Base $StagingDir -RelativePath $relative;if((Get-GitBlobSha -Path $staged)-ne([string]$PackageBlobMap[$relative])){throw "Final staged Git blob verification failed: $relative"}}
  $StageVerificationComplete=$true
  if(-not$StageVerificationComplete){throw "Staging verification er ikke komplett."}
  $OriginalState=Backup-Transaction -Files $TransactionFiles
  try{
    $ActivationStarted=$true;$result=Activate-Transaction -Files $TransactionFiles -BlobMap $PackageBlobMap;$ActivationCommitted=$true
  }catch{
    $activationMessage=$_.Exception.Message
    try{Restore-Transaction -Files $TransactionFiles -OriginalState $OriginalState}catch{throw("Activation failed: "+$activationMessage+". Rollback also failed: "+$_.Exception.Message)}
    throw("Activation failed and original package was restored: "+$activationMessage)
  }
  $entryPath=Get-SafeTargetPath -RelativePath ([string]$manifest.entry);Install-CommandCenterShortcut -EntryPath $entryPath
  Write-CcLog "Command Center v2.1 transactional update committed fra $ResolvedCommit. Oppdatert: $($result.Updated). Uendret: $($result.Unchanged). Backup: $BackupDir"
  Write-Host "RAH Command Center v2.1 Stable er klar." -ForegroundColor Green
  Write-Host "Release-integritet: full staging + Git tree/blob-verifisering + verifisert backup/rollback. Fast authority 4 capabilities / 3 actions / 5 routes." -ForegroundColor Yellow
  if(-not$NoStart){Start-Process -FilePath $entryPath -WorkingDirectory $Root}
}catch{Write-CcLog "FEIL: $($_.Exception.Message)";Write-Host "Command Center-oppdateringen stoppet trygt. Se logg og beholdt backup for detaljer." -ForegroundColor Red;exit 1}
finally{
  if(Test-Path -LiteralPath $StagingDir){Remove-Item -LiteralPath $StagingDir -Recurse -Force -ErrorAction SilentlyContinue}
}

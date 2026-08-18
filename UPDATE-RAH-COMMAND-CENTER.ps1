param([switch]$NoStart)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoOwner="NilsRa73";$RepoName="rah-platform";$ReleaseCommit="1f5339841958bf0c2b4e737a5307f00029f8cf68"
$ApiBase="https://api.github.com/repos/$RepoOwner/$RepoName"
$ManifestName="RAH-COMMAND-CENTER-VERSION.json"
$AllowedPackageFiles=@(
  "RAH-COMMAND-CENTER-V2.3.html",
  "RAH-COMMAND-CENTER-V2.3-CANDIDATE.html",
  "rah-command-center-core-v2.3-candidate.js",
  "rah-command-center-core-v2.3.js",
  "RAH-CC23-FLEET-SNAPSHOT-REGISTRY-BINDING-CANDIDATE.json",
  "RAH-CC23-NODE13-STABLE-RELEASE.json",
  "RAH-COMMAND-CENTER-V2.2.html",
  "RAH-COMMAND-CENTER-V2.2-CANDIDATE.html",
  "rah-command-center-core-v2.2-candidate.js",
  "rah-command-center-core-v2.2.js",
  "RAH-CC22-FLEET-SNAPSHOT-INVALIDATION-CANDIDATE.json",
  "RAH-CC22-NODE13-STABLE-RELEASE.json",
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
$CanonicalTransactionFiles=@($AllowedPackageFiles)+@($ManifestName)
$TransactionRoot=Join-Path $Root ".rah-transactions"
$LockPath=Join-Path $TransactionRoot "command-center.lock"
$JournalPath=Join-Path $TransactionRoot "command-center-active.json"
$JournalTempPath=Join-Path $TransactionRoot "command-center-active.json.tmp"
$JournalMaxBytes=131072
$JournalProduct="RAH Raven Command Center"
$JournalReadinessId="rah-cc23-crash-recovery-journal-readiness-v1"
$JournalSchemaVersion=1
$TransactionId=(Get-Date -Format "yyyyMMdd-HHmmss")+"-"+[Guid]::NewGuid().ToString("N")
$Stamp=$TransactionId
$BackupDir=Join-Path (Join-Path $Root ".rah-backups") ("command-center-"+$TransactionId)
$StagingDir=Join-Path (Join-Path $Root ".rah-staging") ("command-center-"+$TransactionId)
$LogFile=Join-Path $Root "rah-command-center-update.log"
$StageVerificationComplete=$false
$ActivationStarted=$false
$ActivationCommitted=$false
$TransactionFiles=$null
$OriginalState=$null
$ActiveJournal=$null
$LockHandle=$null

function Write-CcLog{param([string]$Message)$line="[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Message;Write-Host $line;Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8}
function Acquire-UpdaterLock{
  New-Item -ItemType Directory -Path $TransactionRoot -Force|Out-Null
  try{return [IO.File]::Open($LockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw "En annen RAH Command Center-oppdatering holder den eksklusive updater-locken. Oppdateringen stoppes."}
}
function Resolve-VerifiedRepositoryCommit{
  $headers=@{Accept="application/vnd.github+json";"User-Agent"="RAH-Raven-Command-Center-Updater"}
  $commitInfo=Invoke-RestMethod -Headers $headers -Uri "$ApiBase/commits/$ReleaseCommit"
  $sha=[string]$commitInfo.sha;$treeSha=[string]$commitInfo.commit.tree.sha
  if($sha -notmatch '^[0-9a-fA-F]{40}$'){throw "GitHub returnerte ikke en gyldig commit-SHA for Command Center."}
  if($sha.ToLowerInvariant()-ne$ReleaseCommit.ToLowerInvariant()){throw "GitHub returnerte en annen commit enn den pinnede CC 2.3-releasen."}
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
function Get-TransactionBackupDir{param([string]$Id)if($Id-notmatch'^[0-9]{8}-[0-9]{6}-[0-9a-f]{32}$'){throw "Ugyldig transactionId."};return Join-Path (Join-Path $Root ".rah-backups") ("command-center-"+$Id)}
function Get-TransactionStagingDir{param([string]$Id)if($Id-notmatch'^[0-9]{8}-[0-9]{6}-[0-9a-f]{32}$'){throw "Ugyldig transactionId."};return Join-Path (Join-Path $Root ".rah-staging") ("command-center-"+$Id)}
function Assert-FixedPackageContract{param($Manifest)$remote=@($Manifest.package_files|ForEach-Object{[string]$_});if($remote.Count-ne$AllowedPackageFiles.Count){throw "Command Center-pakken har uventet antall filer."};foreach($required in $AllowedPackageFiles){if($remote -notcontains $required){throw "Command Center-pakken mangler tillatt fil: $required"}};foreach($candidate in $remote){if($AllowedPackageFiles -notcontains $candidate){throw "Command Center-manifestet forsøker å legge til en ikke-tillatt fil: $candidate"}}}
function Assert-StableReleaseContract{param($Release)if($Release.stage-ne"stable-release"){throw "Stable release-manifest har feil stage."};if($Release.commandCenterVersion-ne"2.3.0"-or $Release.nodeAgentVersion-ne"1.3.0"){throw "Stable release-manifest har uventet CC/Node-versjon."};if($Release.nodeActionsProtocol-ne"rah-node-actions-v7"-or $Release.authProtocol-ne"rah-node-auth-v2"-or $Release.policyId-ne"rah-capability-allowlist-v1"){throw "Stable release-manifest har uventet protokoll/policy."};$caps=@($Release.authoritySurface.capabilities);$actions=@($Release.authoritySurface.actions);$routes=@($Release.authoritySurface.businessRoutes);if(($caps -join ",")-ne"compute,storage,display,remote-desktop"){throw "Stable release har uventet capability authority."};if(($actions -join ",")-ne"storage-summary.read,rustdesk.launch,rustdesk.connect"){throw "Stable release har uventet action authority."};if(($routes -join ",")-ne"/health,/actions,/storage,/launch/rustdesk,/handoff/rustdesk"){throw "Stable release har uventet route authority."};$r=$Release.registryBinding;if($r.version-ne"rah-cc-fleet-snapshot-registry-binding-v1"-or$r.policy-ne"prune-row-on-registry-identity-drift"-or($r.identityFields -join ",")-ne"deviceId,endpointIp,sessionId"-or-not$r.pruneRemovedDevice-or-not$r.pruneEndpointChange-or-not$r.pruneNodeSessionChange-or$r.samePageSignal-ne"device-grid-mutation-observer"-or$r.crossTabSignal-ne"storage-event-exact-device-registry-key"-or-not$r.snapshotMemoryOnly-or$r.snapshotPersistence-or$r.tokenPersistence-or$r.timers-or$r.backgroundPolling-or$r.networkDiscovery-or$r.automaticRemoteControl-or$r.nodeRuntimeChange){throw "Stable release har uventet registry-bound Fleet Snapshot boundary."};if($Release.retainedCc22.failurePolicy-ne"invalidate-selected-row-on-refresh-failure"-or-not$Release.retainedCc22.selectedRowInvalidatedBeforeFailureRender){throw "Stable release har mistet CC2.2 failed-refresh boundary."}}
function Assert-ExactPropertySet{
  param($Value,[string[]]$Allowed,[string]$Label)
  if($null-eq$Value){throw "$Label mangler."}
  $names=@($Value.PSObject.Properties.Name)
  if($names.Count-ne$Allowed.Count){throw "$Label har uventet felttall."}
  foreach($name in $names){if($Allowed-notcontains$name){throw "$Label har ikke-tillatt felt: $name"}}
  foreach($required in $Allowed){if($names-notcontains$required){throw "$Label mangler felt: $required"}}
}
function Assert-Journal{
  param($Journal)
  $top=@("schemaVersion","product","readinessId","transactionId","releaseCommit","phase","files")
  $fileFields=@("path","expectedBlob","existed","originalSha256")
  Assert-ExactPropertySet -Value $Journal -Allowed $top -Label "Journal"
  if([int]$Journal.schemaVersion-ne$JournalSchemaVersion-or[string]$Journal.product-ne$JournalProduct-or[string]$Journal.readinessId-ne$JournalReadinessId){throw "Journal identity mismatch."}
  $id=[string]$Journal.transactionId;if($id-notmatch'^[0-9]{8}-[0-9]{6}-[0-9a-f]{32}$'){throw "Journal har ugyldig transactionId."}
  if(([string]$Journal.releaseCommit).ToLowerInvariant()-ne$ReleaseCommit){throw "Journal peker på feil release commit."}
  $phase=[string]$Journal.phase;$allowedPhases=@("staged","backup-complete","activation-started","committed","rollback-started");if($allowedPhases-notcontains$phase){throw "Journal har ukjent phase."}
  $files=@($Journal.files);if($files.Count-ne62){throw "Journal har feil filantall."}
  $seen=@{}
  for($i=0;$i-lt62;$i++){
    $record=$files[$i];Assert-ExactPropertySet -Value $record -Allowed $fileFields -Label "Journalfil[$i]"
    $path=[string]$record.path;if($path-ne$CanonicalTransactionFiles[$i]){throw "Journal filrekkefølge/path mismatch ved index $i."}
    $null=Get-SafeTargetPath -RelativePath $path
    if($seen.ContainsKey($path)){throw "Journal har duplikat path: $path"};$seen[$path]=$true
    $blob=[string]$record.expectedBlob;if($blob-notmatch'^[0-9a-f]{40}$'){throw "Journal har ugyldig expectedBlob: $path"}
    if($phase-eq"staged"){
      if($null-ne$record.existed-or$null-ne$record.originalSha256){throw "Staged journal kan ikke inneholde original state."}
    }else{
      if($record.existed-isnot[bool]){throw "Journal mangler boolean existed: $path"}
      if([bool]$record.existed){if(([string]$record.originalSha256)-notmatch'^[0-9A-F]{64}$'){throw "Journal har ugyldig original SHA-256: $path"}}
      elseif($null-ne$record.originalSha256){throw "Journal absent target må ha null originalSha256: $path"}
    }
  }
  return $Journal
}
function Read-ActiveJournal{
  $hasActive=Test-Path -LiteralPath $JournalPath -PathType Leaf;$hasTemp=Test-Path -LiteralPath $JournalTempPath -PathType Leaf
  if($hasActive-and$hasTemp){throw "Både aktiv journal og temp-journal finnes. Recovery stopper fail-closed."}
  if(-not$hasActive-and$hasTemp){throw "Orphan temp-journal finnes uten aktiv journal. Recovery stopper fail-closed."}
  if(-not$hasActive){return $null}
  $length=(Get-Item -LiteralPath $JournalPath).Length;if($length-lt2-or$length-gt$JournalMaxBytes){throw "Aktiv journal har ugyldig størrelse."}
  try{$raw=[IO.File]::ReadAllText($JournalPath,[Text.Encoding]::UTF8);$journal=$raw|ConvertFrom-Json}catch{throw "Aktiv journal er malformed JSON. Recovery stopper fail-closed."}
  return Assert-Journal -Journal $journal
}
function Write-JournalDurable{
  param($Journal)
  $null=Assert-Journal -Journal $Journal
  if(Test-Path -LiteralPath $JournalTempPath){throw "Temp-journal finnes allerede. Durable write stopper fail-closed."}
  $json=$Journal|ConvertTo-Json -Depth 8 -Compress;$encoding=New-Object Text.UTF8Encoding($false);$bytes=$encoding.GetBytes($json)
  if($bytes.Length-lt2-or$bytes.Length-gt$JournalMaxBytes){throw "Journal overstiger tillatt størrelse."}
  $stream=$null
  try{
    $stream=New-Object IO.FileStream($JournalTempPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,4096,[IO.FileOptions]::WriteThrough)
    $stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)
  }finally{if($null-ne$stream){$stream.Dispose()}}
  if(Test-Path -LiteralPath $JournalPath -PathType Leaf){[IO.File]::Replace($JournalTempPath,$JournalPath,$null)}else{[IO.File]::Move($JournalTempPath,$JournalPath)}
}
function Copy-Journal{param($Journal)return (($Journal|ConvertTo-Json -Depth 8 -Compress)|ConvertFrom-Json)}
function Set-JournalPhase{
  param($Journal,[string]$NextPhase)
  $current=[string]$Journal.phase
  $allowed=@{staged=@("backup-complete");"backup-complete"=@("activation-started");"activation-started"=@("committed","rollback-started");committed=@("rollback-started");"rollback-started"=@()}
  if(-not$allowed.ContainsKey($current)-or$allowed[$current]-notcontains$NextPhase){throw "Ugyldig journal phase transition: $current -> $NextPhase"}
  $next=Copy-Journal -Journal $Journal;$next.phase=$NextPhase;Write-JournalDurable -Journal $next;return $next
}
function New-TransactionJournal{
  param([string[]]$Files,$BlobMap)
  if($Files.Count-ne62){throw "Kan ikke opprette journal for annet enn 62 filer."}
  $records=@();foreach($relative in $Files){$expected=[string]$BlobMap[$relative];if($expected-notmatch'^[0-9a-f]{40}$'){throw "Mangler canonical expected blob for journal: $relative"};$records+=[PSCustomObject]@{path=$relative;expectedBlob=$expected;existed=$null;originalSha256=$null}}
  $journal=[PSCustomObject]@{schemaVersion=$JournalSchemaVersion;product=$JournalProduct;readinessId=$JournalReadinessId;transactionId=$TransactionId;releaseCommit=$ReleaseCommit;phase="staged";files=$records}
  $null=Assert-Journal -Journal $journal;return $journal
}
function Add-OriginalStateToJournal{
  param($Journal,$State)
  if(([string]$Journal.phase)-ne"staged"){throw "Original state kan bare bindes fra staged journal."}
  $next=Copy-Journal -Journal $Journal
  foreach($record in @($next.files)){$stateItem=$State[[string]$record.path];if($null-eq$stateItem){throw "Mangler original state for journalfil."};$record.existed=[bool]$stateItem.Existed;$record.originalSha256=if($stateItem.Existed){[string]$stateItem.Sha256}else{$null}}
  $next.phase="backup-complete";Write-JournalDurable -Journal $next;return $next
}
function Get-JournalOriginalState{
  param($Journal)
  $state=@{};foreach($record in @($Journal.files)){$state[[string]$record.path]=[PSCustomObject]@{Existed=[bool]$record.existed;Sha256=if([bool]$record.existed){[string]$record.originalSha256}else{$null}}};return $state
}
function Retire-Journal{if(Test-Path -LiteralPath $JournalTempPath){throw "Kan ikke retire journal mens temp-journal finnes."};if(Test-Path -LiteralPath $JournalPath -PathType Leaf){Remove-Item -LiteralPath $JournalPath -Force}}
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
function Assert-BackupSet{
  param([string[]]$Files,$OriginalState,[string]$BackupBase)
  foreach($relative in $Files){$state=$OriginalState[$relative];if($null-eq$state){throw "Mangler original state: $relative"};if($state.Existed){$backup=Get-SafeChildPath -Base $BackupBase -RelativePath $relative;if(-not(Test-Path -LiteralPath $backup -PathType Leaf)){throw "Mangler backup: $relative"};if((Get-FileHashSafe -Path $backup)-ne$state.Sha256){throw "Backup hash mismatch: $relative"}}}
}
function Restore-Transaction{
  param([string[]]$Files,$OriginalState,[string]$BackupBase=$BackupDir,[string]$RestoreStamp=$Stamp)
  $errors=@()
  foreach($relative in $Files){
    try{
      $target=Get-SafeTargetPath -RelativePath $relative;$state=$OriginalState[$relative]
      if($null-eq$state){throw "Mangler original state"}
      if($state.Existed){
        $backup=Get-SafeChildPath -Base $BackupBase -RelativePath $relative
        if(-not(Test-Path -LiteralPath $backup -PathType Leaf)){throw "Mangler backup"}
        if((Get-FileHashSafe -Path $backup)-ne$state.Sha256){throw "Backup hash mismatch"}
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null;$restoreTemp="$target.rah-restore-$RestoreStamp"
        try{Copy-Item -LiteralPath $backup -Destination $restoreTemp -Force;if((Get-FileHashSafe -Path $restoreTemp)-ne$state.Sha256){throw "Restore temp hash mismatch"};Move-Item -LiteralPath $restoreTemp -Destination $target -Force}finally{Remove-Item -LiteralPath $restoreTemp -Force -ErrorAction SilentlyContinue}
      }elseif(Test-Path -LiteralPath $target){if(-not(Test-Path -LiteralPath $target -PathType Leaf)){throw "Kan ikke fjerne ikke-fil under rollback"};Remove-Item -LiteralPath $target -Force}
    }catch{$errors+=($relative+": "+$_.Exception.Message)}
  }
  if($errors.Count-gt0){throw("Rollback failed: "+($errors-join" | "))}
}
function Assert-OriginalStateRestored{
  param([string[]]$Files,$OriginalState)
  foreach($relative in $Files){$target=Get-SafeTargetPath -RelativePath $relative;$state=$OriginalState[$relative];if($null-eq$state){throw "Mangler state ved recovery verification: $relative"};if($state.Existed){if(-not(Test-Path -LiteralPath $target -PathType Leaf)-or(Get-FileHashSafe -Path $target)-ne$state.Sha256){throw "Recovered original state mismatch: $relative"}}elseif(Test-Path -LiteralPath $target){throw "Originally absent target finnes etter recovery: $relative"}}
}
function Test-JournalInstalledBlobs{
  param($Journal)
  foreach($record in @($Journal.files)){try{$target=Get-SafeTargetPath -RelativePath ([string]$record.path);if(-not(Test-Path -LiteralPath $target -PathType Leaf)){return $false};if((Get-GitBlobSha -Path $target)-ne([string]$record.expectedBlob)){return $false}}catch{return $false}}
  return $true
}
function Resolve-PendingRecovery{
  $journal=Read-ActiveJournal;if($null-eq$journal){return}
  $files=@($journal.files|ForEach-Object{[string]$_.path});$id=[string]$journal.transactionId;$recoveryBackup=Get-TransactionBackupDir -Id $id;$recoveryStaging=Get-TransactionStagingDir -Id $id;$phase=[string]$journal.phase
  Write-CcLog "Fant pending Command Center transaction $id i phase $phase. Recovery kjøres før nettverk."
  switch($phase){
    "staged"{Retire-Journal;if(Test-Path -LiteralPath $recoveryStaging){Remove-Item -LiteralPath $recoveryStaging -Recurse -Force -ErrorAction SilentlyContinue};Write-CcLog "Retired staged transaction uten target-mutasjon.";return}
    "backup-complete"{$state=Get-JournalOriginalState -Journal $journal;Assert-BackupSet -Files $files -OriginalState $state -BackupBase $recoveryBackup;Retire-Journal;if(Test-Path -LiteralPath $recoveryStaging){Remove-Item -LiteralPath $recoveryStaging -Recurse -Force -ErrorAction SilentlyContinue};Write-CcLog "Retired backup-complete transaction uten target-mutasjon.";return}
    "activation-started"{$state=Get-JournalOriginalState -Journal $journal;Assert-BackupSet -Files $files -OriginalState $state -BackupBase $recoveryBackup;$journal=Set-JournalPhase -Journal $journal -NextPhase "rollback-started";Restore-Transaction -Files $files -OriginalState $state -BackupBase $recoveryBackup -RestoreStamp $id;Assert-OriginalStateRestored -Files $files -OriginalState $state;Retire-Journal;if(Test-Path -LiteralPath $recoveryStaging){Remove-Item -LiteralPath $recoveryStaging -Recurse -Force -ErrorAction SilentlyContinue};Write-CcLog "Recovered activation-started transaction til verifisert pre-transaction state.";return}
    "rollback-started"{$state=Get-JournalOriginalState -Journal $journal;Assert-BackupSet -Files $files -OriginalState $state -BackupBase $recoveryBackup;Restore-Transaction -Files $files -OriginalState $state -BackupBase $recoveryBackup -RestoreStamp $id;Assert-OriginalStateRestored -Files $files -OriginalState $state;Retire-Journal;if(Test-Path -LiteralPath $recoveryStaging){Remove-Item -LiteralPath $recoveryStaging -Recurse -Force -ErrorAction SilentlyContinue};Write-CcLog "Completed idempotent rollback-started recovery.";return}
    "committed"{$state=Get-JournalOriginalState -Journal $journal;Assert-BackupSet -Files $files -OriginalState $state -BackupBase $recoveryBackup;if(Test-JournalInstalledBlobs -Journal $journal){Retire-Journal;if(Test-Path -LiteralPath $recoveryStaging){Remove-Item -LiteralPath $recoveryStaging -Recurse -Force -ErrorAction SilentlyContinue};Write-CcLog "Verified committed transaction og retired journal.";return};$journal=Set-JournalPhase -Journal $journal -NextPhase "rollback-started";Restore-Transaction -Files $files -OriginalState $state -BackupBase $recoveryBackup -RestoreStamp $id;Assert-OriginalStateRestored -Files $files -OriginalState $state;Retire-Journal;if(Test-Path -LiteralPath $recoveryStaging){Remove-Item -LiteralPath $recoveryStaging -Recurse -Force -ErrorAction SilentlyContinue};Write-CcLog "Committed package mismatch recovered til pre-transaction state.";return}
    default{throw "Ukjent recovery phase."}
  }
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
function Install-CommandCenterShortcut{param([string]$EntryPath)$desktop=[Environment]::GetFolderPath("Desktop");$shortcutPath=Join-Path $desktop "RAH Command Center.lnk";$launcher=Join-Path $Root "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat";$target=if(Test-Path -LiteralPath $launcher -PathType Leaf){$launcher}else{$EntryPath};$shell=New-Object -ComObject WScript.Shell;$shortcut=$shell.CreateShortcut($shortcutPath);$shortcut.TargetPath=$target;$shortcut.WorkingDirectory=$Root;$shortcut.Description="Start RAH Raven Command Center v2.3 Stable";$shortcut.WindowStyle=1;$shortcut.Save();Write-CcLog "Skrivebordssnarvei klar: $shortcutPath"}

try{
  $LockHandle=Acquire-UpdaterLock
  Write-CcLog "Starter RAH Command Center v2.3 crash-recoverable transactional update."
  Resolve-PendingRecovery
  Write-CcLog "Recovery gate er resolved før nettverk."
  $releaseIdentity=Resolve-VerifiedRepositoryCommit;$ResolvedCommit=[string]$releaseIdentity.Sha;$ResolvedTree=[string]$releaseIdentity.TreeSha
  $PackageBlobMap=Resolve-PackageBlobMap -TreeSha $ResolvedTree;$RawBase="https://raw.githubusercontent.com/$RepoOwner/$RepoName/$ResolvedCommit"
  New-Item -ItemType Directory -Path $StagingDir -Force|Out-Null
  $stagedManifest=Download-StagedFile -RelativePath $ManifestName -RawBase $RawBase -BlobMap $PackageBlobMap
  $manifest=Get-Content -LiteralPath $stagedManifest -Raw -Encoding UTF8|ConvertFrom-Json
  if($manifest.product-ne"RAH Raven Command Center"){throw "Manifestet tilhører ikke RAH Raven Command Center."}
  if($manifest.version-ne"2.3.0"-or $manifest.stage-ne"stable"){throw "Pinnet Command Center-release er ikke canonical v2.3 Stable."}
  if($manifest.release_gate.status-ne"passed"-or -not$manifest.release_gate.runtime_files_frozen){throw "Command Center har ikke bestått frozen Stable release gate."}
  if($manifest.raven_contract-ne"2.0.32"){throw "Command Center-manifestet peker på en uventet Raven-kontrakt."}
  if([string]$manifest.entry-ne"RAH-COMMAND-CENTER-V2.3.html"-or[string]$manifest.runtime-ne"rah-command-center-core-v2.3.js"){throw "Canonical entry/runtime er uventet."}
  Assert-FixedPackageContract -Manifest $manifest
  foreach($relativePath in $manifest.package_files){$null=Download-StagedFile -RelativePath ([string]$relativePath) -RawBase $RawBase -BlobMap $PackageBlobMap}
  $releasePath=[string]$manifest.stable_release_manifest;if($releasePath-ne"RAH-CC23-NODE13-STABLE-RELEASE.json"){throw "Canonical manifest peker ikke paa forventet Stable release."}
  $stagedRelease=Get-SafeChildPath -Base $StagingDir -RelativePath $releasePath
  $release=Get-Content -LiteralPath $stagedRelease -Raw -Encoding UTF8|ConvertFrom-Json;Assert-StableReleaseContract -Release $release
  $TransactionFiles=@($manifest.package_files|ForEach-Object{[string]$_})+@($ManifestName)
  if($TransactionFiles.Count-ne62-or@($TransactionFiles|Select-Object -Unique).Count-ne62){throw "Command Center transaction set er ikke eksakt 62 unike filer."}
  for($i=0;$i-lt62;$i++){if($TransactionFiles[$i]-ne$CanonicalTransactionFiles[$i]){throw "Command Center transaction order avviker fra fixed recovery set."}}
  foreach($relative in $TransactionFiles){$staged=Get-SafeChildPath -Base $StagingDir -RelativePath $relative;if((Get-GitBlobSha -Path $staged)-ne([string]$PackageBlobMap[$relative])){throw "Final staged Git blob verification failed: $relative"}}
  $StageVerificationComplete=$true
  if(-not$StageVerificationComplete){throw "Staging verification er ikke komplett."}
  $ActiveJournal=New-TransactionJournal -Files $TransactionFiles -BlobMap $PackageBlobMap;Write-JournalDurable -Journal $ActiveJournal
  $OriginalState=Backup-Transaction -Files $TransactionFiles
  $ActiveJournal=Add-OriginalStateToJournal -Journal $ActiveJournal -State $OriginalState
  try{
    $ActivationStarted=$true;$ActiveJournal=Set-JournalPhase -Journal $ActiveJournal -NextPhase "activation-started"
    $result=Activate-Transaction -Files $TransactionFiles -BlobMap $PackageBlobMap;$ActivationCommitted=$true
    $ActiveJournal=Set-JournalPhase -Journal $ActiveJournal -NextPhase "committed"
    if(-not(Test-JournalInstalledBlobs -Journal $ActiveJournal)){throw "Committed journal verification failed after activation."}
    Retire-Journal
  }catch{
    $activationMessage=$_.Exception.Message
    try{
      if($null-ne$ActiveJournal-and(@("activation-started","committed")-contains([string]$ActiveJournal.phase))){$ActiveJournal=Set-JournalPhase -Journal $ActiveJournal -NextPhase "rollback-started"}
      Restore-Transaction -Files $TransactionFiles -OriginalState $OriginalState
      Assert-OriginalStateRestored -Files $TransactionFiles -OriginalState $OriginalState
      Retire-Journal
    }catch{throw("Activation failed: "+$activationMessage+". Rollback also failed: "+$_.Exception.Message)}
    throw("Activation failed and original package was restored: "+$activationMessage)
  }
  $entryPath=Get-SafeTargetPath -RelativePath ([string]$manifest.entry);Install-CommandCenterShortcut -EntryPath $entryPath
  Write-CcLog "Command Center v2.3 crash-recoverable update committed fra $ResolvedCommit. Oppdatert: $($result.Updated). Uendret: $($result.Unchanged). Backup: $BackupDir"
  Write-Host "RAH Command Center v2.3 Stable er klar." -ForegroundColor Green
  Write-Host "Release-integritet: recovery-before-network + exclusive lock + durable journal + full staging/Git blob-verifisering + verifisert backup/rollback. Fast authority 4 capabilities / 3 actions / 5 routes." -ForegroundColor Yellow
  if(-not$NoStart){Start-Process -FilePath $entryPath -WorkingDirectory $Root}
}catch{Write-CcLog "FEIL: $($_.Exception.Message)";Write-Host "Command Center-oppdateringen stoppet trygt. Se logg og beholdt backup/journal for detaljer." -ForegroundColor Red;exit 1}
finally{
  if(Test-Path -LiteralPath $StagingDir){Remove-Item -LiteralPath $StagingDir -Recurse -Force -ErrorAction SilentlyContinue}
  if($null-ne$LockHandle){$LockHandle.Dispose()}
}
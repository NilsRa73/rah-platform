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
$Stamp=Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir=Join-Path (Join-Path $Root ".rah-backups") ("command-center-"+$Stamp)
$LogFile=Join-Path $Root "rah-command-center-update.log"
$manifestTemp=$null;$releaseTemp=$null

function Write-CcLog{param([string]$Message)$line="[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$Message;Write-Host $line;Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8}
function Resolve-VerifiedRepositoryCommit{
  $headers=@{Accept="application/vnd.github+json";"User-Agent"="RAH-Raven-Command-Center-Updater"}
  $commitInfo=Invoke-RestMethod -Headers $headers -Uri "$ApiBase/commits/$ReleaseCommit"
  $sha=[string]$commitInfo.sha
  if($sha -notmatch '^[0-9a-fA-F]{40}$'){throw "GitHub returnerte ikke en gyldig commit-SHA for Command Center."}
  if($sha.ToLowerInvariant()-ne$ReleaseCommit.ToLowerInvariant()){throw "GitHub returnerte en annen commit enn den pinnede CC 2.1-releasen."}
  if(-not $commitInfo.commit.verification.verified){throw "Pinnet Command Center-release er ikke GitHub-verifisert. Oppdateringen stoppes."}
  return $sha.ToLowerInvariant()
}
function Get-SafeTargetPath{param([string]$RelativePath)if([string]::IsNullOrWhiteSpace($RelativePath)){throw "Tom filsti i Command Center-manifestet."};if([IO.Path]::IsPathRooted($RelativePath)-or $RelativePath.Contains("..")){throw "Utrygg Command Center-fil: $RelativePath"};$normal=$RelativePath.Replace("/",[IO.Path]::DirectorySeparatorChar);$target=[IO.Path]::GetFullPath((Join-Path $Root $normal));$rootFull=[IO.Path]::GetFullPath($Root+[IO.Path]::DirectorySeparatorChar);if(-not $target.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase)){throw "Command Center-fil peker utenfor RAH-mappen: $RelativePath"};return $target}
function Get-FileHashSafe{param([string]$Path)if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};return(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-FixedPackageContract{param($Manifest)$remote=@($Manifest.package_files|ForEach-Object{[string]$_});if($remote.Count-ne $AllowedPackageFiles.Count){throw "Command Center-pakken har uventet antall filer."};foreach($required in $AllowedPackageFiles){if($remote -notcontains $required){throw "Command Center-pakken mangler tillatt fil: $required"}};foreach($candidate in $remote){if($AllowedPackageFiles -notcontains $candidate){throw "Command Center-manifestet forsøker å legge til en ikke-tillatt fil: $candidate"}}}
function Assert-StableReleaseContract{param($Release)if($Release.stage-ne"stable-release"){throw "Stable release-manifest har feil stage."};if($Release.commandCenterVersion-ne"2.1.0"-or $Release.nodeAgentVersion-ne"1.3.0"){throw "Stable release-manifest har uventet CC/Node-versjon."};if($Release.nodeActionsProtocol-ne"rah-node-actions-v7"-or $Release.authProtocol-ne"rah-node-auth-v2"-or $Release.policyId-ne"rah-capability-allowlist-v1"){throw "Stable release-manifest har uventet protokoll/policy."};$caps=@($Release.authoritySurface.capabilities);$actions=@($Release.authoritySurface.actions);$routes=@($Release.authoritySurface.businessRoutes);if(($caps -join ",")-ne"compute,storage,display,remote-desktop"){throw "Stable release har uventet capability authority."};if(($actions -join ",")-ne"storage-summary.read,rustdesk.launch,rustdesk.connect"){throw "Stable release har uventet action authority."};if(($routes -join ",")-ne"/health,/actions,/storage,/launch/rustdesk,/handoff/rustdesk"){throw "Stable release har uventet route authority."};if($Release.fleetSnapshot.version-ne"rah-cc-fleet-snapshot-v1"-or $Release.fleetSnapshot.scope-ne"already-enrolled-devices-only"-or -not $Release.fleetSnapshot.freshNodeTokenRequiredPerRefreshClick-or -not $Release.fleetSnapshot.tokenProofAuthenticationRequired-or -not $Release.fleetSnapshot.sessionMatchRequired-or $Release.fleetSnapshot.tokenPersistence-or $Release.fleetSnapshot.snapshotPersistence-or $Release.fleetSnapshot.backgroundPolling-or $Release.fleetSnapshot.networkDiscovery-or $Release.fleetSnapshot.automaticRemoteControl){throw "Stable release har uventet Fleet Snapshot boundary."}}
function Install-CommandCenterShortcut{param([string]$EntryPath)$desktop=[Environment]::GetFolderPath("Desktop");$shortcutPath=Join-Path $desktop "RAH Command Center.lnk";$launcher=Join-Path $Root "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat";$target=if(Test-Path -LiteralPath $launcher -PathType Leaf){$launcher}else{$EntryPath};$shell=New-Object -ComObject WScript.Shell;$shortcut=$shell.CreateShortcut($shortcutPath);$shortcut.TargetPath=$target;$shortcut.WorkingDirectory=$Root;$shortcut.Description="Start RAH Raven Command Center v2.1 Stable";$shortcut.WindowStyle=1;$shortcut.Save();Write-CcLog "Skrivebordssnarvei klar: $shortcutPath"}

try{
  Write-CcLog "Starter eksplisitt RAH Command Center v2.1 pakkeoppdatering."
  $ResolvedCommit=Resolve-VerifiedRepositoryCommit
  $RawBase="https://raw.githubusercontent.com/$RepoOwner/$RepoName/$ResolvedCommit"
  Write-CcLog "Låst til GitHub-verifisert CC 2.1 release-commit: $ResolvedCommit"
  $manifestTemp=Join-Path ([IO.Path]::GetTempPath()) ("rah-cc-manifest-{0}.json" -f [Guid]::NewGuid())
  Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$ManifestName" -OutFile $manifestTemp
  $manifest=Get-Content -LiteralPath $manifestTemp -Raw -Encoding UTF8|ConvertFrom-Json
  if($manifest.product-ne"RAH Raven Command Center"){throw "Manifestet tilhører ikke RAH Raven Command Center."}
  if($manifest.version-ne"2.1.0"-or $manifest.stage-ne"stable"){throw "Pinnet Command Center-release er ikke canonical v2.1 Stable."}
  if($manifest.release_gate.status-ne"passed"-or -not $manifest.release_gate.runtime_files_frozen){throw "Command Center har ikke bestått frozen Stable release gate."}
  if($manifest.raven_contract-ne"2.0.32"){throw "Command Center-manifestet peker på en uventet Raven-kontrakt."}
  if([string]$manifest.entry-ne"RAH-COMMAND-CENTER-V2.1.html"-or [string]$manifest.runtime-ne"rah-command-center-core-v2.1.js"){throw "Canonical entry/runtime er uventet."}
  Assert-FixedPackageContract -Manifest $manifest
  $releasePath=[string]$manifest.stable_release_manifest
  if($releasePath-ne"RAH-CC21-NODE13-STABLE-RELEASE.json"){throw "Canonical manifest peker ikke paa forventet Stable release."}
  $releaseTemp=Join-Path ([IO.Path]::GetTempPath()) ("rah-cc-release-{0}.json" -f [Guid]::NewGuid())
  Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$releasePath" -OutFile $releaseTemp
  $release=Get-Content -LiteralPath $releaseTemp -Raw -Encoding UTF8|ConvertFrom-Json
  Assert-StableReleaseContract -Release $release
  New-Item -ItemType Directory -Path $BackupDir -Force|Out-Null
  $updated=0;$unchanged=0
  foreach($relativePath in $manifest.package_files){
    $relative=[string]$relativePath;$target=Get-SafeTargetPath -RelativePath $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
    $encodedPath=($relative -split "/"|ForEach-Object{[Uri]::EscapeDataString($_)}) -join "/"
    $download="$target.rah-download"
    try{
      Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$encodedPath" -OutFile $download
      if(-not(Test-Path -LiteralPath $download -PathType Leaf)-or(Get-Item -LiteralPath $download).Length-lt 1){throw "Tom eller manglende nedlasting: $relative"}
      $oldHash=Get-FileHashSafe -Path $target;$newHash=Get-FileHashSafe -Path $download
      if($oldHash-and $oldHash-eq $newHash){Remove-Item -LiteralPath $download -Force;$unchanged++;continue}
      if(Test-Path -LiteralPath $target -PathType Leaf){$backupTarget=Join-Path $BackupDir ($relative.Replace("/",[IO.Path]::DirectorySeparatorChar));New-Item -ItemType Directory -Path (Split-Path -Parent $backupTarget) -Force|Out-Null;Copy-Item -LiteralPath $target -Destination $backupTarget -Force}
      Move-Item -LiteralPath $download -Destination $target -Force;$updated++;Write-CcLog "Oppdatert fra ${ResolvedCommit}: $relative"
    }finally{Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue}
  }
  $manifestTarget=Get-SafeTargetPath -RelativePath $ManifestName
  Move-Item -LiteralPath $manifestTemp -Destination $manifestTarget -Force;$manifestTemp=$null
  $entryPath=Get-SafeTargetPath -RelativePath ([string]$manifest.entry)
  if(-not(Test-Path -LiteralPath $entryPath -PathType Leaf)){throw "Command Center entry mangler etter oppdatering: $entryPath"}
  Install-CommandCenterShortcut -EntryPath $entryPath
  Write-CcLog "Command Center v2.1 Stable klar fra verifisert release-commit $ResolvedCommit. Oppdatert: $updated. Uendret: $unchanged."
  Write-Host "RAH Command Center v2.1 Stable er klar." -ForegroundColor Green
  Write-Host "Token-proof: Node-token holdes lokalt; ingen Bearer-transport. Fast authority 4 capabilities / 3 actions / 5 routes. Shell/filer/generic process/native remote control er av." -ForegroundColor Yellow
  if(-not $NoStart){Start-Process -FilePath $entryPath -WorkingDirectory $Root}
}catch{
  Write-CcLog "FEIL: $($_.Exception.Message)"
  Write-Host "Command Center-oppdateringen stoppet trygt. Eldre installasjon kan bruke UPDATE-RAH-RAVEN.ps1 som overgangsbro til denne updater-versjonen." -ForegroundColor Red
  exit 1
}finally{
  if($manifestTemp){Remove-Item -LiteralPath $manifestTemp -Force -ErrorAction SilentlyContinue}
  if($releaseTemp){Remove-Item -LiteralPath $releaseTemp -Force -ErrorAction SilentlyContinue}
}

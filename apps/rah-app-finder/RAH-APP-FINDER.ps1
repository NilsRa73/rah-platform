param(
    [string]$OutputRoot = "",
    [string[]]$Roots = @(),
    [switch]$Install,
    [switch]$NoShortcuts,
    [switch]$NoOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$AppName = 'RAH App Finder'
$Version = '1.0.1'

function Write-Section([string]$Text) {
    Write-Host ''
    Write-Host ('=' * 68) -ForegroundColor DarkGray
    Write-Host (' ' + $Text) -ForegroundColor Yellow
    Write-Host ('=' * 68) -ForegroundColor DarkGray
}

function Test-WritableFolder([string]$Path) {
    try {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        $probe = Join-Path $Path ('.rah-write-' + [guid]::NewGuid().ToString('N') + '.tmp')
        [IO.File]::WriteAllText($probe, 'ok')
        Remove-Item -LiteralPath $probe -Force
        return $true
    } catch { return $false }
}

function Get-DefaultOutputRoot {
    $preferred = 'C:\RAH\AppFinder'
    if(Test-WritableFolder $preferred) { return $preferred }
    $fallback = Join-Path $env:LOCALAPPDATA 'RAH\AppFinder'
    New-Item -ItemType Directory -Force -Path $fallback | Out-Null
    return $fallback
}

if([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = Get-DefaultOutputRoot }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

if($Install) {
    Write-Section "$AppName v$Version - INSTALL"
    $sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    foreach($name in @('RAH-APP-FINDER.ps1','RESCAN-RAH-APPS.cmd','README.txt')) {
        $src = Join-Path $sourceRoot $name
        if(Test-Path -LiteralPath $src -PathType Leaf) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $OutputRoot $name) -Force
        }
    }
    Write-Host "PASS: Installed utility files to $OutputRoot" -ForegroundColor Green
}

function Add-Root([System.Collections.Generic.List[string]]$List, [string]$Path) {
    if([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())
        if(Test-Path -LiteralPath $expanded -PathType Container) {
            $full = [IO.Path]::GetFullPath($expanded).TrimEnd('\')
            if(-not $List.Contains($full)) { $List.Add($full) }
        }
    } catch {}
}

function Get-ScanRoots {
    $list = [System.Collections.Generic.List[string]]::new()
    if($Roots.Count -gt 0) {
        foreach($r in $Roots) { Add-Root $list $r }
        return $list
    }

    Add-Root $list 'C:\RAH'
    Add-Root $list (Join-Path $env:USERPROFILE 'Desktop')
    Add-Root $list (Join-Path $env:USERPROFILE 'Downloads')
    Add-Root $list (Join-Path $env:USERPROFILE 'Documents')
    if($env:OneDrive) { Add-Root $list $env:OneDrive }

    try {
        foreach($drive in Get-PSDrive -PSProvider FileSystem) {
            if(-not $drive.Root) { continue }
            foreach($candidate in @(
                (Join-Path $drive.Root 'RAH'),
                (Join-Path $drive.Root 'RAH AI Studio'),
                (Join-Path $drive.Root 'RAH AI Studios')
            )) { Add-Root $list $candidate }
        }
    } catch {}

    $rootsFile = Join-Path $OutputRoot 'roots.txt'
    if(Test-Path -LiteralPath $rootsFile) {
        foreach($line in Get-Content -LiteralPath $rootsFile -ErrorAction SilentlyContinue) {
            $v = $line.Trim()
            if($v -and -not $v.StartsWith('#')) { Add-Root $list $v }
        }
    }
    return $list
}

$skipDirNames = @(
    '.git','.github','node_modules','packages','vendor','__pycache__',
    'AppData','Windows','Program Files','Program Files (x86)',
    '$Recycle.Bin','System Volume Information'
)

function Get-DirectoriesLimited([string]$Root, [int]$MaxDepth = 5) {
    $result = [System.Collections.Generic.List[string]]::new()
    $queue = [System.Collections.Generic.Queue[object]]::new()
    $queue.Enqueue([pscustomobject]@{ Path = $Root; Depth = 0 })
    while($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        $result.Add($item.Path)
        if($item.Depth -ge $MaxDepth) { continue }
        try {
            foreach($d in Get-ChildItem -LiteralPath $item.Path -Directory -Force -ErrorAction SilentlyContinue) {
                if($skipDirNames -contains $d.Name) { continue }
                if($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                $queue.Enqueue([pscustomobject]@{ Path = $d.FullName; Depth = ($item.Depth + 1) })
            }
        } catch {}
    }
    return $result
}

function Get-LauncherScore([IO.FileInfo]$File) {
    $n = $File.Name.ToLowerInvariant()
    $e = $File.Extension.ToLowerInvariant()
    if($n -eq 'start-her.cmd' -or $n -eq 'start-here.cmd') { return 100 }
    if($n -eq 'start-her.bat' -or $n -eq 'start-here.bat') { return 99 }
    if(($e -eq '.cmd' -or $e -eq '.bat') -and $n -match '^start[-_ ]') {
        if($n -notmatch 'install|repair|selftest|diagnostic|uninstall|build|accept|test') { return 94 }
    }
    if($e -eq '.exe' -and $n -notmatch 'setup|install|uninstall|update|updater|crash|helper|service') { return 90 }
    if($e -eq '.hta') { return 84 }
    if($n -eq 'index.html' -or $n -eq 'index.htm') { return 82 }
    if(($e -eq '.html' -or $e -eq '.htm') -and $n -match 'command.*center|test.*hub|menu|dashboard|studio') { return 78 }
    if($e -eq '.html' -or $e -eq '.htm') { return 70 }
    return 0
}

function Get-VersionInfo([string]$Text) {
    $matches = [regex]::Matches($Text, '(?i)(?:^|[^a-z0-9])v?(\d+(?:\.\d+){0,3})(?:[-_ ]?(stable|candidate|rc\d*))?')
    if($matches.Count -eq 0) {
        return [pscustomobject]@{ Version=''; VersionObj=[version]'0.0'; Status='unknown'; StatusRank=0 }
    }
    $m = $matches[$matches.Count - 1]
    $raw = $m.Groups[1].Value
    try { $vo = [version]$raw } catch { $vo = [version]'0.0' }
    $tag = $m.Groups[2].Value.ToLowerInvariant()
    $status = if($tag -like 'stable*'){'stable'} elseif($tag -like 'rc*'){'rc'} elseif($tag -like 'candidate*'){'candidate'} else {'versioned'}
    $rank = switch($status) { 'stable'{4} 'versioned'{3} 'rc'{2} 'candidate'{1} default{0} }
    return [pscustomobject]@{ Version=$raw; VersionObj=$vo; Status=$status; StatusRank=$rank }
}

function Get-FamilyName([string]$Folder, [string]$Launcher) {
    $leaf = Split-Path $Folder -Leaf
    if($leaf -match '^(?i)(dist|release|build|bin|output|artifacts?)$') {
        $leaf = Split-Path (Split-Path $Folder -Parent) -Leaf
    }
    if([string]::IsNullOrWhiteSpace($leaf)) { $leaf = [IO.Path]::GetFileNameWithoutExtension($Launcher) }
    $name = [regex]::Replace($leaf, '(?i)[-_ ]*(?:v)?\d+(?:\.\d+){0,3}(?:[-_ ]?(?:stable|candidate|rc\d*))?', '')
    $name = [regex]::Replace($name, '(?i)[-_ ]+(?:stable|candidate|release|portable|windows|win64|x64)$', '')
    $name = ($name -replace '[_-]+',' ' -replace '\s+',' ').Trim()
    if([string]::IsNullOrWhiteSpace($name)) { $name = [IO.Path]::GetFileNameWithoutExtension($Launcher) -replace '[_-]+',' ' }
    return $name.Trim()
}

function Get-Type([string]$Path) {
    switch(([IO.Path]::GetExtension($Path)).ToLowerInvariant()) {
        '.exe' {'EXE'} '.cmd' {'CMD'} '.bat' {'BAT'} '.hta' {'HTA'} '.html' {'HTML'} '.htm' {'HTML'} default {'FILE'}
    }
}

Write-Section "$AppName v$Version - SCAN"
$scanRoots = @(Get-ScanRoots)
if($scanRoots.Count -eq 0) { throw 'No scan roots exist. Add paths to roots.txt or use -Roots.' }
Write-Host ('Roots: ' + ($scanRoots -join ' | '))

$found = [System.Collections.Generic.List[object]]::new()
$seenLaunchers = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach($root in $scanRoots) {
    Write-Host ("SCAN: " + $root) -ForegroundColor DarkCyan
    foreach($dir in Get-DirectoriesLimited $root 5) {
        try {
            $files = @(Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction SilentlyContinue)
            if($files.Count -eq 0) { continue }
            $ranked = @(
                $files | ForEach-Object {
                    $score = Get-LauncherScore $_
                    if($score -gt 0) { [pscustomobject]@{ File=$_; Score=$score } }
                } | Where-Object { $_ } |
                Sort-Object @{Expression='Score';Descending=$true}, @{Expression={$_.File.LastWriteTimeUtc};Descending=$true}
            )
            if($ranked.Count -eq 0) { continue }
            $best = $ranked[0]
            $launcher = $best.File.FullName
            if(-not $seenLaunchers.Add($launcher)) { continue }

            $vi = Get-VersionInfo ($dir + ' ' + $best.File.Name)
            $family = Get-FamilyName $dir $best.File.Name
            $idBytes = [Text.Encoding]::UTF8.GetBytes($launcher.ToLowerInvariant())
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $hash = [BitConverter]::ToString($sha.ComputeHash($idBytes)).Replace('-','').Substring(0,12).ToLowerInvariant() }
            finally { $sha.Dispose() }

            $found.Add([pscustomobject]@{
                Id=$hash; Name=$family; Family=$family; Version=$vi.Version; VersionObj=$vi.VersionObj;
                Status=$vi.Status; StatusRank=$vi.StatusRank; Launcher=$launcher; LauncherScore=$best.Score;
                Type=(Get-Type $launcher); Folder=$dir; Modified=$best.File.LastWriteTimeUtc; Preferred=$false
            })
        } catch {}
    }
}

$preferred = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($g in ($found | Group-Object Family)) {
    $winner = $g.Group | Sort-Object @{Expression='VersionObj';Descending=$true}, @{Expression='StatusRank';Descending=$true}, @{Expression='LauncherScore';Descending=$true}, @{Expression='Modified';Descending=$true} | Select-Object -First 1
    if($winner) { [void]$preferred.Add($winner.Id) }
}
foreach($row in $found) { $row.Preferred = $preferred.Contains($row.Id) }

$ordered = @($found | Sort-Object @{Expression='Preferred';Descending=$true}, @{Expression='Family';Descending=$false}, @{Expression='VersionObj';Descending=$true}, @{Expression='Modified';Descending=$true})
$export = @($ordered | Select-Object Id,Name,Family,Version,Status,Launcher,Type,Folder,@{Name='Modified';Expression={$_.Modified.ToString('o')}},Preferred)

$registryPath = Join-Path $OutputRoot 'apps.json'
$export | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $registryPath -Encoding UTF8

if(-not (Test-Path (Join-Path $OutputRoot 'roots.txt'))) {
    @('# Add one extra folder per line. Example:','# D:\RAH','# E:\Downloaded RAH Apps') | Set-Content -LiteralPath (Join-Path $OutputRoot 'roots.txt') -Encoding UTF8
}

$generated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$count = $export.Count
$preferredCount = @($export | Where-Object Preferred).Count
$rescanPath = Join-Path $OutputRoot 'RESCAN-RAH-APPS.cmd'

$bestCards = [System.Collections.Generic.List[string]]::new()
$allCards = [System.Collections.Generic.List[string]]::new()
$htaEvents = [System.Collections.Generic.List[string]]::new()
$buttonIndex = 0

function ConvertTo-VbsString([string]$Value) {
    if($null -eq $Value) { return '' }
    return $Value.Replace('"','""')
}

foreach($a in $export) {
    $safeName = [Net.WebUtility]::HtmlEncode([string]$a.Name)
    $safeVersion = [Net.WebUtility]::HtmlEncode($(if($a.Version){[string]$a.Version}else{'—'}))
    $safeStatus = [Net.WebUtility]::HtmlEncode([string]$a.Status)
    $safePath = [Net.WebUtility]::HtmlEncode([string]$a.Launcher)
    $safeType = [Net.WebUtility]::HtmlEncode([string]$a.Type)
    $bestBadge = if($a.Preferred){'<span class="badge primary">BEST / LATEST</span>'}else{''}
    $cardClass = if($a.Preferred){'card best'}else{'card'}
    $startId = 'start' + $buttonIndex
    $folderId = 'folder' + $buttonIndex

    $card = @"
<div class="$cardClass">
  <div class="name">$safeName $bestBadge <span class="badge">$safeType</span></div>
  <div class="meta">Version: $safeVersion &nbsp; • &nbsp; $safeStatus</div>
  <div class="path">$safePath</div>
  <div class="actions">
    <button id="$startId">START</button>
    <button id="$folderId">FOLDER</button>
  </div>
</div>
"@
    $allCards.Add($card)
    if($a.Preferred) { $bestCards.Add($card) }

    $launcherVbs = ConvertTo-VbsString ([string]$a.Launcher)
    $folderVbs = ConvertTo-VbsString ([string]$a.Folder)
    $htaEvents.Add(@"
Sub $($startId)_OnClick
  LaunchPath "$launcherVbs"
End Sub

Sub $($folderId)_OnClick
  OpenFolder "$folderVbs"
End Sub
"@)
    $buttonIndex++
}

$rescanVbs = ConvertTo-VbsString $rescanPath
$hta = @"
<!doctype html>
<html>
<head>
<meta http-equiv="x-ua-compatible" content="IE=9" />
<meta charset="utf-8" />
<hta:application id="rahHub" applicationname="RAH Test Hub" border="thin" caption="yes" maximizebutton="yes" minimizebutton="yes" scroll="yes" singleinstance="yes" sysmenu="yes" />
<title>RAH TEST HUB</title>
<style>
html,body{margin:0;background:#060708;color:#f3ead5;font-family:Segoe UI,Arial,sans-serif}
body{padding:24px}
.header{border:1px solid #80651f;background:#11100b;padding:22px;border-radius:14px;margin-bottom:16px}
h1{margin:0;color:#f2ce66;font-size:30px;letter-spacing:1px}
h2{color:#f2ce66;margin-top:24px}
.sub{color:#8fcfe7;margin-top:6px}
.stat{color:#aaa;font-size:12px;margin-top:10px}
.toolbar{margin:14px 0}
button{background:#181a1e;color:#f2ce66;border:1px solid #8f7430;padding:9px 12px;border-radius:8px;cursor:pointer;font-weight:600;margin-right:7px}
.card{display:inline-block;vertical-align:top;width:360px;min-height:145px;border:1px solid #3c3420;background:#0d1014;border-radius:12px;padding:14px;margin:0 10px 12px 0}
.card.best{border-color:#b69135}
.name{font-size:18px;font-weight:700;color:#f2ce66}
.badge{font-size:10px;padding:3px 6px;border:1px solid #555;border-radius:10px;margin-left:6px;color:#bbb}
.badge.primary{border-color:#b69135;color:#f2ce66}
.meta{font-size:12px;color:#95a0aa;margin-top:7px}
.path{font-size:11px;color:#6f7b84;margin-top:8px;word-wrap:break-word}
.actions{margin-top:11px}
.small{font-size:10px;color:#777}
.section{clear:both}
</style>
<script language="VBScript">
Option Explicit

Sub LaunchPath(p)
  On Error Resume Next
  Dim sh
  Set sh = CreateObject("WScript.Shell")
  sh.Run Chr(34) & p & Chr(34), 1, False
  If Err.Number <> 0 Then
    MsgBox "Could not launch:" & vbCrLf & p & vbCrLf & vbCrLf & Err.Description, 48, "RAH TEST HUB"
    Err.Clear
  End If
End Sub

Sub OpenFolder(p)
  On Error Resume Next
  Dim sh
  Set sh = CreateObject("WScript.Shell")
  sh.Run "explorer.exe " & Chr(34) & p & Chr(34), 1, False
  If Err.Number <> 0 Then
    MsgBox "Could not open folder:" & vbCrLf & p, 48, "RAH TEST HUB"
    Err.Clear
  End If
End Sub

Sub rescanBtn_OnClick
  On Error Resume Next
  Dim sh
  Set sh = CreateObject("WScript.Shell")
  sh.Run Chr(34) & "$rescanVbs" & Chr(34), 1, False
  If Err.Number <> 0 Then
    MsgBox "Could not start RAH RESCAN APPS.", 48, "RAH TEST HUB"
    Err.Clear
  End If
End Sub

$($htaEvents -join [Environment]::NewLine)
</script>
</head>
<body>
<div class="header">
  <h1>RAH TEST HUB</h1>
  <div class="sub">AUTO-DISCOVERY • LAUNCH • VERSION CHECK • SHORTCUT REPAIR</div>
  <div class="stat">Found $count versions • $preferredCount preferred apps • generated $generated</div>
</div>

<div class="toolbar">
  <button id="rescanBtn">RESCAN PC + REPAIR SHORTCUTS</button>
</div>

<div class="section">
  <h2>BEST / LATEST</h2>
  $($bestCards -join [Environment]::NewLine)
</div>

<div class="section">
  <h2>ALL DISCOVERED VERSIONS</h2>
  $($allCards -join [Environment]::NewLine)
</div>

<p class="small">RAH App Finder never deletes or moves discovered programs. It only rebuilds shortcuts inside the dedicated RAH Apps Desktop folder.</p>
</body>
</html>
"@
$htaPath = Join-Path $OutputRoot 'RAH-TEST-HUB.hta'
[IO.File]::WriteAllText($htaPath,$hta,[Text.UTF8Encoding]::new($false))

$htmlCards = foreach($a in $export) {
    $badge = if($a.Preferred){'<span class="badge">BEST / LATEST</span>'}else{''}
    $safeName=[Net.WebUtility]::HtmlEncode($a.Name)
    $safeVersion=[Net.WebUtility]::HtmlEncode($(if($a.Version){$a.Version}else{'—'}))
    $safeStatus=[Net.WebUtility]::HtmlEncode($a.Status)
    $safePath=[Net.WebUtility]::HtmlEncode($a.Launcher)
    "<div class='card'><div class='name'>$safeName $badge</div><div class='meta'>Version $safeVersion • $safeStatus • $($a.Type)</div><div class='path'>$safePath</div></div>"
}
$html = @"
<!doctype html><html><head><meta charset="utf-8"><title>RAH App Inventory</title><style>
body{margin:0;padding:24px;background:#060708;color:#eee;font-family:Segoe UI,Arial}h1{color:#f2ce66}.sub{color:#4fcfff}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:12px}
.card{background:#0d1014;border:1px solid #4b3d1d;border-radius:12px;padding:14px}.name{color:#f2ce66;font-weight:700}.badge{font-size:10px;border:1px solid #a88631;border-radius:10px;padding:3px 6px}.meta{color:#aaa;margin-top:6px}.path{color:#6f7b84;font-size:11px;margin-top:8px;word-break:break-all}
</style></head><body><h1>RAH APP INVENTORY</h1><div class="sub">Read-only browser view • use Desktop “RAH TEST HUB” to launch apps.</div><p>Found $count versions • $preferredCount preferred apps • generated $generated</p><div class="grid">$($htmlCards -join [Environment]::NewLine)</div></body></html>
"@
[IO.File]::WriteAllText((Join-Path $OutputRoot 'RAH-TEST-HUB.html'),$html,[Text.UTF8Encoding]::new($false))

$rescanCmd = @"
@echo off
setlocal
title RAH APP FINDER - RESCAN + REPAIR
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-APP-FINDER.ps1"
if errorlevel 1 (
  echo.
  echo RAH APP FINDER: FAIL
  pause
  exit /b 1
)
echo.
echo RAH APP FINDER: PASS
echo Menu and shortcuts refreshed.
timeout /t 2 /nobreak >nul
"@
[IO.File]::WriteAllText((Join-Path $OutputRoot 'RESCAN-RAH-APPS.cmd'),$rescanCmd,[Text.ASCIIEncoding]::new())

if(-not $NoShortcuts) {
    Write-Section 'SHORTCUT REPAIR'
    $desktop=[Environment]::GetFolderPath('Desktop')
    $shortcutRoot=Join-Path $desktop 'RAH Apps'
    $allRoot=Join-Path $shortcutRoot 'All versions'
    New-Item -ItemType Directory -Force -Path $shortcutRoot,$allRoot | Out-Null
    Get-ChildItem -LiteralPath $shortcutRoot -Filter '*.lnk' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $allRoot -Filter '*.lnk' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $wsh=New-Object -ComObject WScript.Shell

    function Safe-LinkName([string]$Name) {
        $s=$Name
        foreach($ch in [IO.Path]::GetInvalidFileNameChars()){$s=$s.Replace([string]$ch,' ')}
        return (($s -replace '\s+',' ').Trim())
    }
    function New-AppShortcut([object]$App,[string]$Destination) {
        $label=$App.Name
        if($App.Version){$label+=' v'+$App.Version}
        $linkPath=Join-Path $Destination ((Safe-LinkName $label)+'.lnk')
        $lnk=$wsh.CreateShortcut($linkPath)
        if($App.Type -eq 'HTML'){
            $lnk.TargetPath="$env:WINDIR\explorer.exe";$lnk.Arguments='"'+$App.Launcher+'"'
        } elseif($App.Type -eq 'HTA'){
            $lnk.TargetPath="$env:WINDIR\System32\mshta.exe";$lnk.Arguments='"'+$App.Launcher+'"'
        } else {$lnk.TargetPath=$App.Launcher}
        $lnk.WorkingDirectory=$App.Folder;$lnk.Description='RAH App Finder: '+$label;$lnk.Save()
    }

    foreach($a in $export){New-AppShortcut $a $allRoot;if($a.Preferred){New-AppShortcut $a $shortcutRoot}}

    $hubLink=$wsh.CreateShortcut((Join-Path $desktop 'RAH TEST HUB.lnk'))
    $hubLink.TargetPath="$env:WINDIR\System32\mshta.exe";$hubLink.Arguments='"'+$htaPath+'"';$hubLink.WorkingDirectory=$OutputRoot;$hubLink.Description='RAH Test Hub - all discovered RAH apps';$hubLink.Save()

    $htmlLink=$wsh.CreateShortcut((Join-Path $desktop 'RAH APP INVENTORY HTML.lnk'))
    $htmlLink.TargetPath="$env:WINDIR\explorer.exe";$htmlLink.Arguments='"'+(Join-Path $OutputRoot 'RAH-TEST-HUB.html')+'"';$htmlLink.WorkingDirectory=$OutputRoot;$htmlLink.Description='RAH App Inventory - browser view';$htmlLink.Save()

    $scanLink=$wsh.CreateShortcut((Join-Path $desktop 'RAH RESCAN APPS.lnk'))
    $scanLink.TargetPath=(Join-Path $OutputRoot 'RESCAN-RAH-APPS.cmd');$scanLink.WorkingDirectory=$OutputRoot;$scanLink.Description='Rescan RAH apps and repair shortcuts';$scanLink.Save()

    Write-Host "PASS: Desktop\RAH Apps contains preferred launchers + All versions." -ForegroundColor Green
    Write-Host "PASS: Desktop shortcuts created: RAH TEST HUB + RAH RESCAN APPS" -ForegroundColor Green
}

$report=[ordered]@{app=$AppName;version=$Version;generated=(Get-Date).ToString('o');output_root=$OutputRoot;roots=@($scanRoots);versions_found=$count;preferred_apps=$preferredCount;registry=$registryPath;hta=$htaPath;result='PASS'}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputRoot 'last-scan.json') -Encoding UTF8

Write-Section 'RESULT'
Write-Host ("PASS: "+$count+" discovered versions; "+$preferredCount+" preferred app shortcuts.") -ForegroundColor Green
Write-Host ("Hub : "+$htaPath)
Write-Host ("JSON: "+$registryPath)
if(-not $NoOpen -and -not $NoShortcuts){Start-Process "$env:WINDIR\System32\mshta.exe" -ArgumentList ('"'+$htaPath+'"')}
exit 0

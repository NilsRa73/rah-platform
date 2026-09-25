param(
  [switch]$SelfTest,
  [switch]$SelfImprove,
  [switch]$Repair,
  [switch]$Diagnostics
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$App = Join-Path $Root 'RAH_WORLD_MEDIA.py'
$World = Join-Path $Root 'world_countries_simplified.json'
$RahRoot = 'C:\RAH\IPTV'
$LogDir = Join-Path $RahRoot 'logs'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$Log = Join-Path $LogDir ('RAH_WORLD_MEDIA_v140_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
function Log([string]$m){ $m | Tee-Object -FilePath $Log -Append | Write-Host }
function Test-PythonCandidate($cmd,$prefix=@()) {
  try {
    $args = @($prefix) + @('-c','import sys, tkinter; print(sys.executable)')
    $out = & $cmd @args 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) { return @{ Command=$cmd; Prefix=$prefix; Exe=($out | Select-Object -Last 1).Trim() } }
  } catch {}
  return $null
}
function Find-Python {
  foreach($c in @('py','python','python3')) {
    $g = Get-Command $c -ErrorAction SilentlyContinue
    if($g){
      $prefix = if($c -eq 'py'){@('-3')}else{@()}
      $r = Test-PythonCandidate $g.Source $prefix
      if($r){ return $r }
    }
  }
  $paths = @()
  if($env:LOCALAPPDATA){ $paths += Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python*\python.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName }
  if($env:ProgramFiles){ $paths += Get-ChildItem "$env:ProgramFiles\Python*\python.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName }
  if(${env:ProgramFiles(x86)}){ $paths += Get-ChildItem "${env:ProgramFiles(x86)}\Python*\python.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName }
  foreach($hive in @('HKCU:\Software\Python\PythonCore','HKLM:\Software\Python\PythonCore')){
    try {
      foreach($ver in (Get-ChildItem $hive -ErrorAction SilentlyContinue)){
        $ip = Get-ItemProperty ($ver.PSPath + '\InstallPath') -ErrorAction SilentlyContinue
        $root = $ip.'(default)'
        if($root){ $paths += (Join-Path $root 'python.exe') }
      }
    } catch {}
  }
  foreach($p in ($paths | Where-Object { $_ } | Sort-Object -Unique)){
    $r=Test-PythonCandidate $p
    if($r){return $r}
  }
  return $null
}
function Invoke-Python($py,[string[]]$PyArgs){
  $all = @($py.Prefix) + $PyArgs
  & $py.Command @all
  return $LASTEXITCODE
}
function Find-VLC {
  $candidates = @(
    (Get-Command vlc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    "$env:ProgramFiles\VideoLAN\VLC\vlc.exe",
    "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe",
    "$env:USERPROFILE\scoop\apps\vlc\current\vlc.exe"
  ) | Where-Object { $_ -and (Test-Path $_) }
  return $candidates | Select-Object -First 1
}

Log '============================================================'
Log ' RAH WORLD MEDIA v14.0 RAVEN WORLD GRID - PRECHECK'
Log '============================================================'
Log ("Package: " + $Root)
$py = Find-Python
if(-not $py){
  Log 'FAIL: Working Python 3 + tkinter not found.'
  if($Repair -or -not $SelfTest){
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if($winget){
      $ans = Read-Host 'Install Python 3.13 with winget now? (Y/N)'
      if($ans -match '^[YyJj]'){
        & winget install -e --id Python.Python.3.13 --accept-package-agreements --accept-source-agreements
        $py = Find-Python
      }
    }
  }
}
if(-not $py){ Log 'FAIL: Python still unavailable.'; Read-Host 'Press Enter'; exit 2 }
Log ("PASS: Python: " + $py.Exe)
if(-not (Test-Path $App)){ Log 'FAIL: RAH_WORLD_MEDIA.py missing'; Read-Host 'Press Enter'; exit 3 }
if(-not (Test-Path $World)){ Log 'FAIL: world_countries_simplified.json missing'; Read-Host 'Press Enter'; exit 4 }
$rc = Invoke-Python $py @('-m','py_compile',$App)
if($rc -ne 0){ Log 'FAIL: Python compile failed'; Read-Host 'Press Enter'; exit 5 }
Log 'PASS: Python compile.'
$vlc = Find-VLC
if($vlc){ Log ("PASS: VLC: " + $vlc) } else { Log 'WARN: VLC not found. TV/radio PLAY needs VLC.' }

if($Repair -and -not $vlc){
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if($winget){
    $ans = Read-Host 'Install VLC with winget now? (Y/N)'
    if($ans -match '^[YyJj]'){ & winget install -e --id VideoLAN.VLC --accept-package-agreements --accept-source-agreements }
  }
}

if($Diagnostics){
  Log '--- RAH World Media diagnostics ---'
  $rc = Invoke-Python $py @($App,'--diagnostics')
  if($rc -eq 0){ Log 'PASS: diagnostics completed.' } else { Log ('FAIL: diagnostics exit code ' + $rc) }
  Read-Host 'Press Enter'
  exit $rc
}

if($SelfImprove){
  Log '--- SAFE SELF-IMPROVE ---'
  Log 'Repairs only RAH World Media local cache/state. Program source and Windows settings are not rewritten.'
  $rc = Invoke-Python $py @($App,'--self-improve')
  if($rc -eq 0){
    Log 'PASS: SELF-IMPROVE completed and post-selftest passed.'
  } else {
    Log ('FAIL: SELF-IMPROVE exit code ' + $rc)
  }
  Log ("Report: " + (Join-Path $RahRoot 'self_improve_v14.json'))
  Read-Host 'Press Enter'
  exit $rc
}

if($SelfTest){
  Log '--- BUILT-IN SELFTEST ---'
  $rc = Invoke-Python $py @($App,'--selftest')
  $manifest = Join-Path $Root 'MANIFEST.sha256'
  if(Test-Path -LiteralPath $manifest -PathType Leaf){
    Log '--- PACKAGE MANIFEST ---'
    $bad = 0
    foreach($line in Get-Content -LiteralPath $manifest){
      if($line.Length -lt 67){ continue }
      if($line.Substring(64,2) -ne '  '){ continue }
      $expected = $line.Substring(0,64).ToLowerInvariant()
      $name = $line.Substring(66)
      if([string]::IsNullOrWhiteSpace($name)){ continue }
      $p = Join-Path $Root $name
      if(-not (Test-Path -LiteralPath $p -PathType Leaf)){
        Log ("FAIL: manifest missing " + $name)
        $bad++
        continue
      }
      $actual = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()
      if($actual -eq $expected){
        Log ("PASS: manifest " + $name)
      } else {
        Log ("FAIL: manifest hash " + $name)
        $bad++
      }
    }
    if($bad -gt 0){ $rc = 9 }
  } else {
    Log 'WARN: MANIFEST.sha256 not present (source-tree run).'
  }
  Log '============================================================'
  if($rc -eq 0){ Log ' RAH WORLD MEDIA v14.0 SELFTEST: PASS' }
  else { Log (' RAH WORLD MEDIA v14.0 SELFTEST: FAIL exit=' + $rc) }
  Log '============================================================'
  Log ("Report: " + (Join-Path $RahRoot 'selftest_v14.json'))
  Read-Host 'Press Enter'
  exit $rc
}

Log 'POSTCHECK: starting RAH World Media v14.0 RAVEN WORLD GRID...'
$launchArgs = @($py.Prefix) + @(('"' + $App + '"'))
Start-Process -FilePath $py.Command -ArgumentList $launchArgs -WorkingDirectory $Root
Log 'PASS: Launch command dispatched.'
exit 0

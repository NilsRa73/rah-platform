param(
  [switch]$SelfTest,
  [switch]$Repair
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$App = Join-Path $Root 'RAH_WORLD_MEDIA.py'
$World = Join-Path $Root 'world_countries_simplified.json'
$RahRoot = 'C:\RAH\IPTV'
$LogDir = Join-Path $RahRoot 'logs'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$Log = Join-Path $LogDir ('RAH_WORLD_MEDIA_v99_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
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
Log ' RAH WORLD MEDIA v9.9 SUPER MODE - PRECHECK'
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

if($SelfTest){
  Log '--- Network smoke tests (warnings only) ---'
  foreach($url in @(
    'https://iptv-org.github.io/api/countries.json',
    'https://de1.api.radio-browser.info/json/countries',
    'https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js'
  )){
    try { $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 8; Log ("PASS: " + $url + " HTTP " + $r.StatusCode) }
    catch { Log ("WARN: " + $url + " -> " + $_.Exception.Message) }
  }
  Log '============================================================'
  Log ' RAH WORLD MEDIA v9.9 SELFTEST: PASS (warnings may remain)'
  Log '============================================================'
  Read-Host 'Press Enter'
  exit 0
}

Log 'POSTCHECK: starting RAH World Media v9.9 SUPER MODE...'
$launchArgs = @($py.Prefix) + @(('"' + $App + '"'))
Start-Process -FilePath $py.Command -ArgumentList $launchArgs -WorkingDirectory $Root
Log 'PASS: Launch command dispatched.'
exit 0

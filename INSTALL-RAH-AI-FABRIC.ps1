param(
    [ValidateSet("Install","Repair","Status")]
    [string]$Mode = "Install",
    [switch]$NoPause,
    [string]$Ref = "main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$hexChars = "0123456789abcdefABCDEF"
if($Ref -ne "main"){
    $badRefChars = @($Ref.ToCharArray() | Where-Object { $hexChars.IndexOf([string]$_) -lt 0 })
    if($Ref.Length -ne 40 -or $badRefChars.Count -gt 0){
        throw "Ref must be main or a 40-character Git commit SHA."
    }
}

$Version = "1.3.2"
$Root = "C:\RAH\AI-Fabric"
$Source = Join-Path $Root "rah-platform"
$Venv = Join-Path $Root "venv"
$VenvPython = Join-Path $Venv "Scripts\python.exe"
$Logs = Join-Path $Root "Logs"
$Report = Join-Path $Root "ACCEPTANCE-SUMMARY.txt"
$JsonStatus = Join-Path $Root "STATUS.json"
$SourceRefFile = Join-Path $Root "SOURCE-REF.txt"
$ArchiveUrl = if($Ref -eq "main"){
    "https://github.com/NilsRa73/rah-platform/archive/refs/heads/main.zip"
} else {
    "https://github.com/NilsRa73/rah-platform/archive/$Ref.zip"
}
$BridgeTask = "RAH Raven Bridge"
$NodeTask = "RAH Raven Node Agent 18766"
$ProviderTask = "RAH Raven AI Providers"
$WatchdogTask = "RAH Raven AI Fabric Watchdog"
$SelfCheckTask = "RAH Raven AI Self Check"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path $Logs "install-$Stamp.log"
$Awake = $false

$State = [ordered]@{
    version = $Version
    timestamp = (Get-Date).ToString("o")
    computer = $env:COMPUTERNAME
    sourceRef = ""
    source = "NOT_RUN"
    python = "NOT_RUN"
    tests = "NOT_RUN"
    bridge18765 = "NOT_RUN"
    jobs = "NOT_RUN"
    node18766 = "NOT_RUN"
    lmstudio = "UNKNOWN"
    anythingllm = "UNKNOWN"
    anythingllmApi = "UNKNOWN"
    projectMemory = "UNKNOWN"
    projectMemoryWorkspace = ""
    watchdog = "NOT_RUN"
    selfCheck = "NOT_RUN"
    overall = "FAIL"
    smallestFix = ""
}

function Say([string]$Text,[ConsoleColor]$Color=[ConsoleColor]::Gray) {
    Write-Host $Text -ForegroundColor $Color
    try { Add-Content -LiteralPath $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "s"),$Text) -Encoding UTF8 } catch {}
}

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Elevate-IfNeeded {
    if ($Mode -eq "Status" -or (Is-Admin)) { return }
    $elevateArgs = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"","-Mode",$Mode,"-Ref",$Ref)
    if($NoPause){$elevateArgs += "-NoPause"}
    Start-Process powershell.exe -Verb RunAs -ArgumentList $elevateArgs
    exit
}

function Enable-Awake {
    if ($Mode -eq "Status") { return }
    try {
        if (-not ("RAH.Awake" -as [type])) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace RAH {
    public static class Awake {
        [DllImport("kernel32.dll", SetLastError=true)]
        public static extern uint SetThreadExecutionState(uint esFlags);
    }
}
"@
        }
        [RAH.Awake]::SetThreadExecutionState(0x80000001) | Out-Null
        $script:Awake = $true
        Say "Raven Awake: ON under install/repair." DarkYellow
    } catch {}
}

function Disable-Awake {
    if (-not $script:Awake) { return }
    try { [RAH.Awake]::SetThreadExecutionState(0x80000000) | Out-Null } catch {}
    $script:Awake = $false
}

function Ensure-Dirs {
    foreach ($p in @($Root,$Logs,"C:\RAH\AgentJobs","C:\RAH\Status")) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
    }
}

function Test-PythonExecutable {
    param([string]$Path,[switch]$Launcher)
    try {
        if ($Launcher) {
            $out = & $Path -3 -c "import sys; print(sys.executable)" 2>$null | Select-Object -First 1
        } else {
            $out = & $Path -c "import sys; print(sys.executable)" 2>$null | Select-Object -First 1
        }
        return ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$out))
    } catch { return $false }
}

function Get-Python {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "C:\Python313\python.exe",
        "C:\Python312\python.exe"
    )
    foreach ($p in $candidates) {
        if ((Test-Path -LiteralPath $p -PathType Leaf) -and (Test-PythonExecutable -Path $p)) { return $p }
    }
    $py = Get-Command py.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($py -and (Test-PythonExecutable -Path $py.Source -Launcher)) { return "py:-3" }
    $python = Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($python -and (Test-PythonExecutable -Path $python.Source)) { return $python.Source }
    return $null
}

function Ensure-Python {
    $base = Get-Python
    if (-not $base -and $Mode -ne "Status") {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if (-not $winget) { throw "Python mangler og Winget er ikke tilgjengelig." }
        Say "Installerer Python 3.13 automatisk..." Cyan
        & winget.exe install --id Python.Python.3.13 -e --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
        $base = Get-Python
    }
    if (-not $base) { throw "Python 3 ble ikke funnet." }

    if (-not (Test-Path -LiteralPath $VenvPython)) {
        Say "Oppretter isolert Python runtime..." Cyan
        if ($base -eq "py:-3") { & py.exe -3 -m venv $Venv }
        else { & $base -m venv $Venv }
        if ($LASTEXITCODE -ne 0) { throw "Kunne ikke opprette Python venv." }
    }
    $State.python = "PASS"
}

function Refresh-Source {
    if ($Mode -eq "Status") {
        if (Test-Path -LiteralPath (Join-Path $Source "desktop-bridge\raven_ai_fabric.py")) { $State.source = "PASS" }
        if(Test-Path -LiteralPath $SourceRefFile){
            try{$State.sourceRef=[IO.File]::ReadAllText($SourceRefFile).Trim()}catch{$State.sourceRef="UNKNOWN"}
        } else {
            $State.sourceRef="UNKNOWN"
        }
        return
    }

    $zip = Join-Path $env:TEMP "rah-ai-fabric-$Stamp.zip"
    $stage = Join-Path $env:TEMP "rah-ai-fabric-$Stamp"
    try {
        Say "Henter verifiserbar AI Fabric runtime fra GitHub ref $Ref..." Cyan
        Invoke-WebRequest -UseBasicParsing -Uri $ArchiveUrl -OutFile $zip -TimeoutSec 90
        New-Item -ItemType Directory -Force -Path $stage | Out-Null
        Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
        $expanded = Get-ChildItem -LiteralPath $stage -Directory | Select-Object -First 1
        if (-not $expanded) { throw "GitHub-arkivet inneholdt ingen prosjektmappe." }

        foreach ($rel in @(
            "desktop-bridge\raven_ai_fabric.py",
            "desktop-bridge\raven_project_memory.py",
            "desktop-bridge\raven_council.py",
            "desktop-bridge\raven_bridge_agent.py",
            "desktop-bridge\raven_jobs.py",
            "desktop-bridge\agent_runner.py",
            "RAH-HOME-NODE-AGENT.ps1",
            "RAH-HOME-NODE-CLIENT.ps1",
            "RAH-HARDWARE-INVENTORY.ps1",
            "RAH-HARDWARE-REGISTRY.ps1",
            "START-RAH-BRIDGE-AUTOSTART.bat",
            "CONFIGURE-RAH-PROJECT-MEMORY.ps1",
            "CONFIGURE-RAH-PROJECT-MEMORY.cmd",
            "SYNC-RAH-PROJECT-MEMORY.ps1",
            "SYNC-RAH-PROJECT-MEMORY.cmd",
            "RAH-PROJECT-MEMORY.md",
            "RAVEN-AI-SELF-CHECK.ps1",
            "RAVEN-AI-SELF-CHECK.cmd",
            "RAVEN-AI-SELF-CHECK.md",
        "TEST-ANYTHINGLLM-APPROVAL.ps1",
        "START-HER-ANYTHINGLLM-APPROVAL.cmd"
        )) {
            if (-not (Test-Path -LiteralPath (Join-Path $expanded.FullName $rel))) { throw "Runtime mangler $rel" }
        }

        if (Test-Path -LiteralPath $Source) {
            $backup = "$Source.old-$Stamp"
            Move-Item -LiteralPath $Source -Destination $backup -Force
        }
        Move-Item -LiteralPath $expanded.FullName -Destination $Source -Force
        [IO.File]::WriteAllText($SourceRefFile,$Ref,[Text.UTF8Encoding]::new($false))
        $State.sourceRef = $Ref
        $State.source = "PASS"
    } finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Dependencies-And-Test {
    if ($Mode -eq "Status") { return }
    $bridge = Join-Path $Source "desktop-bridge"
    Say "Installerer/verifiserer Raven-avhengigheter..." Cyan
    & $VenvPython -m pip install --disable-pip-version-check --no-input -r (Join-Path $bridge "requirements.txt")
    if ($LASTEXITCODE -ne 0) { throw "pip requirements feilet." }

    Push-Location $bridge
    try {
        & $VenvPython -m py_compile raven_ai_fabric.py raven_project_memory.py raven_council.py raven_bridge_agent.py raven_jobs.py agent_runner.py server_v17.py test_raven_ai_fabric.py test_raven_project_memory.py test_raven_council.py
        if ($LASTEXITCODE -ne 0) { throw "Python compile feilet." }
        & $VenvPython -m unittest -v test_raven_ai_fabric.py
        if ($LASTEXITCODE -ne 0) { throw "AI Fabric test feilet." }
        & $VenvPython -m unittest -v test_raven_project_memory.py
        if ($LASTEXITCODE -ne 0) { throw "Project Memory test feilet." }
        & $VenvPython -m unittest -v test_raven_council.py
        if ($LASTEXITCODE -ne 0) { throw "Raven Council test feilet." }
        & $VenvPython test_raven_jobs.py
        if ($LASTEXITCODE -ne 0) { throw "Raven Jobs regression-test feilet." }
        & $VenvPython test_agent_runner.py
        if ($LASTEXITCODE -ne 0) { throw "Agent Runner regression-test feilet." }
        $State.tests = "PASS"
        Say "Lokale AI Fabric + Project Memory + Council + Raven regression tests: PASS" Green
    } finally { Pop-Location }
}

function Register-Task([string]$Name,[string]$Execute,[string]$Arguments,[string]$RunLevel,[object[]]$Triggers) {
    Import-Module ScheduledTasks -ErrorAction Stop
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action = New-ScheduledTaskAction -Execute $Execute -Argument $Arguments
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel $RunLevel
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Seconds 0)
    Register-ScheduledTask -TaskName $Name -Action $action -Trigger $Triggers -Principal $principal -Settings $settings -Force | Out-Null
}

function Write-Local-Runners {
    $nodeRoot = Join-Path $Root "Node"
    New-Item -ItemType Directory -Force -Path $nodeRoot | Out-Null
    Copy-Item (Join-Path $Source "RAH-HOME-NODE-AGENT.ps1") (Join-Path $nodeRoot "RAH-HOME-NODE-AGENT.ps1") -Force
    Copy-Item (Join-Path $Source "RAH-HOME-NODE-CLIENT.ps1") (Join-Path $nodeRoot "RAH-HOME-NODE-CLIENT.ps1") -Force

    @'
$ErrorActionPreference="Stop"
$agent=Join-Path $PSScriptRoot "RAH-HOME-NODE-AGENT.ps1"
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $agent -ListenAddress 127.0.0.1 -Port 18766
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath (Join-Path $nodeRoot "RUN-NODE.ps1") -Encoding UTF8

    @'
$ErrorActionPreference="Continue"
function PortOpen([int]$p){
  try{$c=New-Object Net.Sockets.TcpClient;$a=$c.BeginConnect("127.0.0.1",$p,$null,$null);if(-not$a.AsyncWaitHandle.WaitOne(700)){return $false};$c.EndConnect($a);$c.Dispose();return $true}catch{return $false}
}
if(-not(PortOpen 1234)){
  $lms=Get-Command lms.exe -ErrorAction SilentlyContinue
  if(-not$lms){$lms=Get-Command lms -ErrorAction SilentlyContinue}
  if($lms){Start-Process -FilePath $lms.Source -ArgumentList "server","start" -WindowStyle Hidden -ErrorAction SilentlyContinue}
  else{
    $c=@(
      "$env:LOCALAPPDATA\Programs\LM Studio\LM Studio.exe",
      "$env:LOCALAPPDATA\Programs\LM Studio\LM Studio Launcher.exe",
      "$env:ProgramFiles\LM Studio\LM Studio.exe"
    );foreach($p in$c){if(Test-Path $p){Start-Process $p -ErrorAction SilentlyContinue;break}}
  }
}
if(-not(PortOpen 3001)){
  $c=@(
    "$env:LOCALAPPDATA\Programs\AnythingLLM\AnythingLLM.exe",
    "$env:LOCALAPPDATA\Programs\anythingllm-desktop\AnythingLLM.exe",
    "$env:LOCALAPPDATA\Programs\AnythingLLM Desktop\AnythingLLM.exe",
    "$env:ProgramFiles\AnythingLLM\AnythingLLM.exe"
  );foreach($p in$c){if(Test-Path $p){Start-Process $p -ErrorAction SilentlyContinue;break}}
}
'@ | Set-Content -LiteralPath (Join-Path $Root "START-PROVIDERS.ps1") -Encoding UTF8

    @'
$ErrorActionPreference="Continue"
function Json($u){try{Invoke-RestMethod -Uri $u -TimeoutSec 3}catch{$null}}
$h=Json "http://127.0.0.1:18765/health"
$j=Json "http://127.0.0.1:18765/agent/jobs/health"
if(-not$h -or $h.ai_fabric-ne$true -or -not$j -or $j.ready-ne$true){Start-ScheduledTask -TaskName "RAH Raven Bridge" -ErrorAction SilentlyContinue}
try{$n=Get-NetTCPConnection -LocalPort 18766 -State Listen -ErrorAction SilentlyContinue}catch{$n=$null}
if(-not$n){Start-ScheduledTask -TaskName "RAH Raven Node Agent 18766" -ErrorAction SilentlyContinue}
try{$null=Invoke-RestMethod -Uri "http://127.0.0.1:18765/ai/providers" -TimeoutSec 5}catch{Start-ScheduledTask -TaskName "RAH Raven AI Providers" -ErrorAction SilentlyContinue}
try{$m=Invoke-RestMethod -Uri "http://127.0.0.1:18765/ai/memory/status" -TimeoutSec 5;if($m.detail -match "offline"){Start-ScheduledTask -TaskName "RAH Raven AI Providers" -ErrorAction SilentlyContinue}}catch{}
'@ | Set-Content -LiteralPath (Join-Path $Root "WATCHDOG.ps1") -Encoding UTF8

    foreach($name in @("RAVEN-AI-SELF-CHECK.ps1","RAVEN-AI-SELF-CHECK.cmd","RAVEN-AI-SELF-CHECK.md")){
        $sourceFile=Join-Path $Source $name
        if(Test-Path -LiteralPath $sourceFile){
            Copy-Item -LiteralPath $sourceFile -Destination (Join-Path "C:\RAH" $name) -Force
        }
    }
}

function Install-Tasks {
    if ($Mode -eq "Status") { return }
    Write-Local-Runners
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $logon = New-ScheduledTaskTrigger -AtLogOn -User $user

    $bridgeBat = Join-Path $Source "START-RAH-BRIDGE-AUTOSTART.bat"
    Register-Task -Name $BridgeTask -Execute "cmd.exe" -Arguments ("/d /c `"`"{0}`"`"" -f $bridgeBat) -RunLevel "Highest" -Triggers @($logon)

    $nodeRunner = Join-Path $Root "Node\RUN-NODE.ps1"
    Register-Task -Name $NodeTask -Execute "powershell.exe" -Arguments ("-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"{0}`"" -f $nodeRunner) -RunLevel "Limited" -Triggers @($logon)

    $providerRunner = Join-Path $Root "START-PROVIDERS.ps1"
    Register-Task -Name $ProviderTask -Execute "powershell.exe" -Arguments ("-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"{0}`"" -f $providerRunner) -RunLevel "Limited" -Triggers @($logon)

    $watchdogRunner = Join-Path $Root "WATCHDOG.ps1"
    $repeat = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(1)) -RepetitionInterval (New-TimeSpan -Minutes 5)
    Register-Task -Name $WatchdogTask -Execute "powershell.exe" -Arguments ("-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"{0}`"" -f $watchdogRunner) -RunLevel "Highest" -Triggers @($logon,$repeat)

    $selfCheckRunner = "C:\RAH\RAVEN-AI-SELF-CHECK.ps1"
    $selfRepeat = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(3)) -RepetitionInterval (New-TimeSpan -Minutes 30)
    Register-Task -Name $SelfCheckTask -Execute "powershell.exe" -Arguments ("-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"{0}`"" -f $selfCheckRunner) -RunLevel "Highest" -Triggers @($logon,$selfRepeat)
    $State.watchdog = "PASS"

    $startup = [Environment]::GetFolderPath("Startup")
    $legacy = Join-Path $startup "RAH Raven Bridge.lnk"
    if (Test-Path -LiteralPath $legacy) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Root "Backup") | Out-Null
        Copy-Item $legacy (Join-Path $Root "Backup\RAH Raven Bridge.legacy.lnk") -Force
        Remove-Item $legacy -Force
    }
}

function Start-Stack {
    if ($Mode -eq "Status") { return }
    Start-ScheduledTask -TaskName $ProviderTask -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-ScheduledTask -TaskName $BridgeTask -ErrorAction Stop
    Start-ScheduledTask -TaskName $NodeTask -ErrorAction Stop
}

function Wait-Http([string]$Url,[int]$Seconds=35) {
    $end=(Get-Date).AddSeconds($Seconds)
    do {
        try { return Invoke-RestMethod -Uri $Url -TimeoutSec 3 } catch {}
        Start-Sleep -Milliseconds 700
    } while((Get-Date)-lt$end)
    return $null
}

function Test-Stack {
    $h = Wait-Http "http://127.0.0.1:18765/health" 35
    $j = Wait-Http "http://127.0.0.1:18765/agent/jobs/health" 10
    $a = Wait-Http "http://127.0.0.1:18765/ai/providers" 10
    $m = Wait-Http "http://127.0.0.1:18765/ai/memory/status" 10

    if ($h -and $h.ai_fabric -eq $true) { $State.bridge18765="PASS" }
    if ($j -and $j.ready -eq $true -and $j.elevated -eq $true) { $State.jobs="PASS" }

    if ($a -and $a.providers) {
        foreach($p in $a.providers){
            if($p.id-eq"lmstudio"){$State.lmstudio=if($p.ready){"READY"}elseif($p.online){"ONLINE_NO_MODEL"}else{"OFFLINE"}}
            if($p.id-eq"anythingllm"){
                $State.anythingllm=if($p.online){"ONLINE"}else{"OFFLINE"}
                $State.anythingllmApi=if($p.ready){"READY"}elseif($p.online){"NEEDS_API_TOKEN_OR_AUTH"}else{"OFFLINE"}
            }
        }
    }

    if ($m) {
        $State.projectMemoryWorkspace=[string]$m.workspace
        if($m.ready -eq $true){$State.projectMemory="READY"}
        elseif($m.enabled -eq $false){$State.projectMemory="DISABLED"}
        elseif([string]$m.detail -match "token.*not configured"){$State.projectMemory="NEEDS_TOKEN"}
        elseif([string]$m.detail -match "workspace not found"){$State.projectMemory="WORKSPACE_MISSING"}
        else{$State.projectMemory="NOT_READY"}
    }

    $client = Join-Path $Root "Node\RAH-HOME-NODE-CLIENT.ps1"
    if (Test-Path $client) {
        $out=& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $client -NodeAddress 127.0.0.1 -Port 18766 -Action hello -TimeoutMs 5000 2>&1
        if($LASTEXITCODE-eq0){
            try{$o=($out|Out-String)|ConvertFrom-Json;if($o.ok-eq$true -and $o.product-eq"RAH Home Node Agent"){$State.node18766="PASS"}}catch{}
        }
    }

    $selfCheckScript = "C:\RAH\RAVEN-AI-SELF-CHECK.ps1"
    $selfCheckTask = Get-ScheduledTask -TaskName $SelfCheckTask -ErrorAction SilentlyContinue
    if((Test-Path -LiteralPath $selfCheckScript) -and $selfCheckTask){$State.selfCheck="PASS"}
    elseif(Test-Path -LiteralPath $selfCheckScript){$State.selfCheck="TASK_MISSING"}
    else{$State.selfCheck="MISSING"}

    if($State.bridge18765-eq"PASS" -and $State.jobs-eq"PASS" -and $State.node18766-eq"PASS"){$State.overall="PASS"}
    else{
        $State.overall="FAIL"
        if($State.bridge18765-ne"PASS"){$State.smallestFix="Bridge/AI Fabric paa 18765 er ikke frisk."}
        elseif($State.jobs-ne"PASS"){$State.smallestFix="Job Executor er ikke ready/elevated."}
        elseif($State.node18766-ne"PASS"){$State.smallestFix="Node Agent paa 18766 svarer ikke paa hello."}
    }
}

function Write-Report {
    $State.timestamp=(Get-Date).ToString("o")
    $State|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $JsonStatus -Encoding UTF8
    @(
        "RAH RAVEN AI FABRIC v$Version",
        "============================",
        "PC                   : $env:COMPUTERNAME",
        "Source ref           : $($State.sourceRef)",
        "Bridge 18765         : $($State.bridge18765)",
        "Job Executor         : $($State.jobs)",
        "Node 18766           : $($State.node18766)",
        "LM Studio            : $($State.lmstudio)",
        "AnythingLLM          : $($State.anythingllm)",
        "AnythingLLM API      : $($State.anythingllmApi)",
        "Project Memory       : $($State.projectMemory)",
        "Memory Workspace     : $($State.projectMemoryWorkspace)",
        "Watchdog             : $($State.watchdog)",
        "AI Self-Check        : $($State.selfCheck)",
        "OVERALL              : $($State.overall)",
        "MINSTE FIX           : $($State.smallestFix)",
        "",
        "Status JSON          : $JsonStatus",
        "Logg                 : $LogFile"
    )|Set-Content -LiteralPath $Report -Encoding UTF8

    Say ""
    Say "============================================================" Yellow
    Say " RAH RAVEN AI FABRIC - FINAL STATUS" Yellow
    Say "============================================================" Yellow
    Get-Content -LiteralPath $Report | ForEach-Object { Write-Host $_ }
    Say "============================================================" Yellow
}

function Install-Root-Shortcuts {
    if ($Mode -eq "Status") { return }
    $repair = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode Repair`r`n"
    $status = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode Status`r`npause`r`n"
    Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $Root "INSTALL-RAH-AI-FABRIC.ps1") -Force
    $installed = Join-Path $Root "INSTALL-RAH-AI-FABRIC.ps1"
    [IO.File]::WriteAllText("C:\RAH\START-HER.cmd",("@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$installed`" -Mode Repair`r`n"),[Text.Encoding]::ASCII)
    [IO.File]::WriteAllText("C:\RAH\RAVEN-STATUS.cmd",("@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$installed`" -Mode Status`r`npause`r`n"),[Text.Encoding]::ASCII)

    foreach($name in @(
        "CONFIGURE-RAH-PROJECT-MEMORY.ps1",
        "CONFIGURE-RAH-PROJECT-MEMORY.cmd",
        "SYNC-RAH-PROJECT-MEMORY.ps1",
        "SYNC-RAH-PROJECT-MEMORY.cmd",
        "RAH-PROJECT-MEMORY.md",
        "RAVEN-AI-SELF-CHECK.ps1",
        "RAVEN-AI-SELF-CHECK.cmd",
        "RAVEN-AI-SELF-CHECK.md",
        "TEST-ANYTHINGLLM-APPROVAL.ps1",
        "START-HER-ANYTHINGLLM-APPROVAL.cmd"
    )){
        $sourceFile=Join-Path $Source $name
        if(Test-Path -LiteralPath $sourceFile){
            Copy-Item -LiteralPath $sourceFile -Destination (Join-Path "C:\RAH" $name) -Force
        }
    }

    foreach($requiredApprovalFile in @(
        "C:\RAH\TEST-ANYTHINGLLM-APPROVAL.ps1",
        "C:\RAH\START-HER-ANYTHINGLLM-APPROVAL.cmd"
    )){
        if(-not(Test-Path -LiteralPath $requiredApprovalFile)){
            throw "AnythingLLM approval root launcher missing after install: $requiredApprovalFile"
        }
    }
}

Ensure-Dirs
Elevate-IfNeeded
Enable-Awake
Start-Transcript -LiteralPath $LogFile -Append -ErrorAction SilentlyContinue | Out-Null
try {
    Say "RAH Raven AI Fabric bootstrap v$Version / $Mode" Yellow
    if($Mode-ne"Status"){
        Refresh-Source
        Ensure-Python
        Install-Dependencies-And-Test
        Install-Tasks
        Install-Root-Shortcuts
        Start-Stack
    } else {
        Refresh-Source
        if(Test-Path $VenvPython){$State.python="PASS"}
        if(Get-ScheduledTask -TaskName $WatchdogTask -ErrorAction SilentlyContinue){$State.watchdog="PASS"}
        if(Get-ScheduledTask -TaskName $SelfCheckTask -ErrorAction SilentlyContinue){
            if(Test-Path -LiteralPath "C:\RAH\RAVEN-AI-SELF-CHECK.ps1"){$State.selfCheck="PASS"}
            else{$State.selfCheck="MISSING"}
        } else {
            $State.selfCheck="TASK_MISSING"
            Say "AI Self-Check task mangler." Yellow
        }
    }
    Test-Stack
    if($State.overall-eq"PASS" -and $State.projectMemory-eq"NEEDS_TOKEN"){
        Say "Raven core: PASS. Project Memory trenger kun lokal AnythingLLM API-token." Yellow
        Say "Kjor C:\RAH\CONFIGURE-RAH-PROJECT-MEMORY.cmd en gang." Yellow
    }
} catch {
    $State.overall="FAIL"
    if(-not$State.smallestFix){$State.smallestFix=$_.Exception.Message}
    Say ("FAIL: "+$_.Exception.Message) Red
} finally {
    Write-Report
    Disable-Awake
    try{Stop-Transcript|Out-Null}catch{}
}

if($Mode-ne"Status" -and -not $NoPause){Read-Host "Trykk ENTER for a avslutte"}

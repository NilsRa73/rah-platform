param(
    [ValidateSet('Interactive','Audit','SelfTest','RestoreLatest')]
    [string]$Mode = 'Interactive',
    [string]$Root = 'C:\RAH\MemoryDoctor',
    [int]$MemoryThresholdMB = 250,
    [switch]$NoOpenReport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahMemoryDoctorVersion = '1.0.0'
$script:Utf8NoBom = New-Object Text.UTF8Encoding($false)

trap {
    $failure = $_
    try {
        $reports = Join-Path $Root 'reports'
        New-Item -ItemType Directory -Path $reports -Force | Out-Null
        $doc=[pscustomobject]@{
            schema='rah-memory-doctor-failure'
            version=1
            createdAt=(Get-Date).ToUniversalTime().ToString('o')
            mode=$Mode
            message=[string]$failure.Exception.Message
            scriptStack=[string]$failure.ScriptStackTrace
            computerName=$env:COMPUTERNAME
            administrator=[bool](Test-RahAdministrator)
        }
        [IO.File]::WriteAllText((Join-Path $reports 'last-error.json'),($doc | ConvertTo-Json -Depth 5),$script:Utf8NoBom)
        [IO.File]::WriteAllText((Join-Path $reports 'last-error.txt'),("RAH Memory Doctor FAIL" + [Environment]::NewLine + $doc.message + [Environment]::NewLine + $doc.scriptStack),$script:Utf8NoBom)
        Write-Host ("Memory Doctor diagnostics: " + $reports) -ForegroundColor Yellow
    } catch {}
    Write-Error $failure
    exit 1
}

$script:CriticalNames = @(
    'system','idle','registry','smss','csrss','wininit','services','lsass','winlogon',
    'svchost','fontdrvhost','dwm','explorer','sihost','taskhostw','ctfmon','audiodg',
    'searchhost','searchindexer','startmenuexperiencehost','shellexperiencehost',
    'securityhealthservice','securityhealthsystray','msmpeng','nissrv','memory compression'
)

$script:ProtectPatterns = @(
    'c:\rah\','\rah\','rah ','raven','anythingllm','anything llm','lm studio','lmstudio',
    'tailscale','rustdesk','anydesk','teamviewer','wireguard','openvpn','speedify',
    'windows defender','securityhealth','msmpeng'
)

$script:ManualOnlyPatterns = @(
    'chrome','msedge','firefox','brave','opera','vivaldi','code','devenv','notepad',
    'winword','excel','powerpnt','outlook','photoshop','gimp','obs','vlc','discord'
)

$script:StartupReviewPatterns = @(
    'update','updater','helper','tray','launcher','quickstart','assistant','bootstrap',
    'spotify','steam','epic','adobe','ccxprocess','teams','onedrive','dropbox'
)

function Test-RahAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function ConvertTo-RahFlatText {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    return ([string]$Value).Trim()
}

function Test-RahPattern {
    param([string]$Text,[string[]]$Patterns)
    $lower = (ConvertTo-RahFlatText $Text).ToLowerInvariant()
    foreach ($pattern in $Patterns) {
        if ($lower.Contains($pattern.ToLowerInvariant())) { return $true }
    }
    return $false
}

function Get-RahMemorySnapshot {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $total = [math]::Round(([double]$os.TotalVisibleMemorySize / 1024),1)
        $free = [math]::Round(([double]$os.FreePhysicalMemory / 1024),1)
        return [pscustomobject]@{
            totalMB=$total
            freeMB=$free
            usedMB=[math]::Round(($total-$free),1)
            usedPercent=$(if($total -gt 0){[math]::Round((($total-$free)/$total)*100,1)}else{0})
        }
    } catch {
        return [pscustomobject]@{totalMB=$null;freeMB=$null;usedMB=$null;usedPercent=$null;error=$_.Exception.Message}
    }
}

function Get-RahProcessClassification {
    param(
        [string]$Name,
        [string]$Path,
        [string]$CommandLine,
        [double]$WorkingSetMB
    )
    $n = (ConvertTo-RahFlatText $Name).ToLowerInvariant()
    $combined = ((ConvertTo-RahFlatText $Path) + ' ' + (ConvertTo-RahFlatText $CommandLine) + ' ' + $n).ToLowerInvariant()

    if ($script:CriticalNames -contains $n) {
        return [pscustomobject]@{category='PROTECTED';stopAllowed=$false;reason='Windows critical/core process';score=-100}
    }
    if ($combined -match '^[^ ]*c:\\windows\\' -or $combined.Contains(' c:\windows\system32\') -or $combined.Contains(' c:\windows\systemapps\')) {
        return [pscustomobject]@{category='PROTECTED';stopAllowed=$false;reason='Windows system path';score=-100}
    }
    if (Test-RahPattern $combined $script:ProtectPatterns) {
        return [pscustomobject]@{category='PROTECTED';stopAllowed=$false;reason='RAH/AI/network/security/remote-session protected';score=-100}
    }
    if (Test-RahPattern $combined $script:ManualOnlyPatterns) {
        return [pscustomobject]@{category='MANUAL';stopAllowed=$true;reason='Interactive app; may contain unsaved work';score=0}
    }

    $score = 0
    $reasons = @()
    if ($WorkingSetMB -ge $MemoryThresholdMB) {
        $score += 2
        $reasons += "uses $([math]::Round($WorkingSetMB,0)) MB RAM"
    }
    if (Test-RahPattern $combined $script:StartupReviewPatterns) {
        $score += 2
        $reasons += 'looks like updater/helper/tray/launcher'
    }
    if ($score -ge 2) {
        return [pscustomobject]@{category='REVIEW';stopAllowed=$true;reason=($reasons -join '; ');score=$score}
    }
    return [pscustomobject]@{category='INFO';stopAllowed=$true;reason='No strong optimization signal';score=$score}
}

function Get-RahProcessInventory {
    $cimMap = @{}
    try {
        foreach ($c in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
            $cimMap[[int]$c.ProcessId] = $c
        }
    } catch {}

    $rows = @()
    foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
        $pidValue = [int]$p.Id
        $name = [string]$p.ProcessName
        $path = ''
        $cmdline = ''
        if ($cimMap.ContainsKey($pidValue)) {
            $c = $cimMap[$pidValue]
            $path = ConvertTo-RahFlatText $c.ExecutablePath
            $cmdline = ConvertTo-RahFlatText $c.CommandLine
        }
        $ws = [math]::Round(([double]$p.WorkingSet64 / 1MB),1)
        $class = Get-RahProcessClassification -Name $name -Path $path -CommandLine $cmdline -WorkingSetMB $ws
        $rows += [pscustomobject]@{
            pid=$pidValue
            name=$name
            memoryMB=$ws
            category=$class.category
            stopAllowed=[bool]$class.stopAllowed
            score=[int]$class.score
            reason=$class.reason
            path=$path
            commandLine=$cmdline
        }
    }
    return @($rows | Sort-Object memoryMB -Descending)
}

function Get-RahRegistryStartupEntries {
    $locations = @(
        @{Scope='User';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'},
        @{Scope='Machine';Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'},
        @{Scope='Machine32';Path='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'}
    )
    $rows = @()
    foreach ($loc in $locations) {
        if (-not (Test-Path -LiteralPath $loc.Path)) { continue }
        try {
            $item = Get-ItemProperty -LiteralPath $loc.Path -ErrorAction Stop
            foreach ($prop in $item.PSObject.Properties) {
                if ($prop.Name -match '^PS') { continue }
                $rows += [pscustomobject]@{
                    sourceType='Registry'
                    scope=$loc.Scope
                    source=$loc.Path
                    name=$prop.Name
                    command=ConvertTo-RahFlatText $prop.Value
                    originalPath=$null
                }
            }
        } catch {}
    }
    return @($rows)
}

function Get-RahFolderStartupEntries {
    $rows = @()
    $folders = @(
        @{Scope='User';Path=[Environment]::GetFolderPath('Startup')},
        @{Scope='Machine';Path=[Environment]::GetFolderPath('CommonStartup')}
    )
    foreach ($f in $folders) {
        if (-not $f.Path -or -not (Test-Path -LiteralPath $f.Path -PathType Container)) { continue }
        foreach ($item in @(Get-ChildItem -LiteralPath $f.Path -File -ErrorAction SilentlyContinue)) {
            $rows += [pscustomobject]@{
                sourceType='StartupFolder'
                scope=$f.Scope
                source=$f.Path
                name=$item.Name
                command=$item.FullName
                originalPath=$item.FullName
            }
        }
    }
    return @($rows)
}

function Get-RahStartupClassification {
    param([object]$Entry,[object[]]$Processes)
    $combined = ((ConvertTo-RahFlatText $Entry.name) + ' ' + (ConvertTo-RahFlatText $Entry.command)).ToLowerInvariant()
    if ($combined.Contains('c:\windows\') -or (Test-RahPattern $combined $script:ProtectPatterns)) {
        return [pscustomobject]@{category='KEEP';disableAllowed=$false;score=-100;reason='Windows/RAH/AI/network/security protected'}
    }

    $score = 0
    $reasons = @()
    if ($Entry.scope -eq 'User') {
        $score += 1
        $reasons += 'user-level startup'
    }
    if (Test-RahPattern $combined $script:StartupReviewPatterns) {
        $score += 2
        $reasons += 'updater/helper/tray/launcher pattern'
    }

    $matchedMemory = 0.0
    foreach ($p in $Processes) {
        $needle = ([string]$p.name).ToLowerInvariant()
        if ($needle -and $combined.Contains($needle)) {
            if ([double]$p.memoryMB -gt $matchedMemory) { $matchedMemory = [double]$p.memoryMB }
        }
    }
    if ($matchedMemory -ge $MemoryThresholdMB) {
        $score += 2
        $reasons += "related process uses $([math]::Round($matchedMemory,0)) MB"
    }

    if ($score -ge 2) {
        return [pscustomobject]@{category='REVIEW';disableAllowed=$true;score=$score;reason=($reasons -join '; ')}
    }
    return [pscustomobject]@{category='INFO';disableAllowed=$true;score=$score;reason=$(if($reasons.Count){$reasons -join '; '}else{'No strong startup optimization signal'})}
}

function Get-RahStartupInventory {
    param([object[]]$Processes)
    $base = @()
    $base += @(Get-RahRegistryStartupEntries)
    $base += @(Get-RahFolderStartupEntries)
    $rows = @()
    $index = 1
    foreach ($entry in $base) {
        $c = Get-RahStartupClassification -Entry $entry -Processes $Processes
        $rows += [pscustomobject]@{
            id=$index
            sourceType=$entry.sourceType
            scope=$entry.scope
            source=$entry.source
            name=$entry.name
            command=$entry.command
            originalPath=$entry.originalPath
            category=$c.category
            disableAllowed=[bool]$c.disableAllowed
            score=[int]$c.score
            reason=$c.reason
        }
        $index++
    }
    return @($rows)
}

function Save-RahJson {
    param([string]$Path,[object]$Value)
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($Path,($Value | ConvertTo-Json -Depth 12),$script:Utf8NoBom)
}

function Write-RahReport {
    param([object]$Memory,[object[]]$Processes,[object[]]$Startup)
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $reports = Join-Path $Root 'reports'
    New-Item -ItemType Directory -Path $reports -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $jsonPath = Join-Path $reports "memory-doctor-$stamp.json"
    $htmlPath = Join-Path $reports "memory-doctor-$stamp.html"
    $txtPath = Join-Path $reports "memory-doctor-$stamp.txt"

    $doc = [pscustomobject]@{
        schema='rah-memory-startup-doctor'
        version=1
        doctorVersion=$script:RahMemoryDoctorVersion
        createdAt=(Get-Date).ToUniversalTime().ToString('o')
        computerName=$env:COMPUTERNAME
        administrator=[bool](Test-RahAdministrator)
        memory=$Memory
        thresholds=[pscustomobject]@{memoryMB=$MemoryThresholdMB}
        processes=@($Processes)
        startup=@($Startup)
    }
    Save-RahJson $jsonPath $doc

    $reviewProcesses = @($Processes | Where-Object category -eq 'REVIEW')
    $reviewStartup = @($Startup | Where-Object category -eq 'REVIEW')
    $lines = @(
        'RAH MEMORY & STARTUP DOCTOR v1',
        '==============================',
        "Computer: $env:COMPUTERNAME",
        "RAM total/free/used: $($Memory.totalMB) / $($Memory.freeMB) / $($Memory.usedMB) MB",
        "RAM used: $($Memory.usedPercent)%",
        "Processes checked: $($Processes.Count)",
        "RAM review candidates: $($reviewProcesses.Count)",
        "Startup entries checked: $($Startup.Count)",
        "Startup review candidates: $($reviewStartup.Count)",
        '',
        'No process or startup entry is changed by Audit mode.'
    )
    [IO.File]::WriteAllLines($txtPath,$lines,$script:Utf8NoBom)

    function H([object]$v) { return [Net.WebUtility]::HtmlEncode([string]$v) }
    $procRows = ''
    foreach ($p in @($Processes | Select-Object -First 40)) {
        $procRows += "<tr><td>$(H $p.name)</td><td>$($p.pid)</td><td>$($p.memoryMB)</td><td>$(H $p.category)</td><td>$(H $p.reason)</td><td>$(H $p.path)</td></tr>"
    }
    $startupRows = ''
    foreach ($s in $Startup) {
        $startupRows += "<tr><td>$($s.id)</td><td>$(H $s.name)</td><td>$(H $s.scope)</td><td>$(H $s.category)</td><td>$(H $s.reason)</td><td>$(H $s.command)</td></tr>"
    }
    $html = @"
<!doctype html>
<html><head><meta charset="utf-8"><title>RAH Memory & Startup Doctor</title>
<style>
body{background:#080808;color:#eee;font-family:Segoe UI,Arial;margin:24px}
h1,h2{color:#d8af45} .card{border:1px solid #6d5725;background:#111;padding:16px;margin:12px 0;border-radius:10px}
table{border-collapse:collapse;width:100%;font-size:13px} th,td{border-bottom:1px solid #333;text-align:left;padding:8px;vertical-align:top}
th{color:#e7c86e;background:#15120b;position:sticky;top:0}.warn{color:#ffd76a}.ok{color:#8ee39b}
code{color:#e7c86e} .small{color:#aaa;font-size:12px}
</style></head><body>
<h1>RAH Memory & Startup Doctor v1</h1>
<div class="card"><b>RAM:</b> $($Memory.usedMB) / $($Memory.totalMB) MB brukt ($($Memory.usedPercent)%) &nbsp; | &nbsp;
<b>Review:</b> $($reviewProcesses.Count) prosesser, $($reviewStartup.Count) autostart-oppføringer</div>
<div class="card"><span class="ok">BESKYTTET:</span> Windows, RAH/Raven, AnythingLLM, LM Studio, nettverk, sikkerhet og fjernstyringsverktøy blir ikke automatisk stoppet.
<span class="warn">REVIEW:</span> betyr kandidat for vurdering, ikke at programmet er unødvendig.</div>
<h2>Prosesser - topp 40 etter RAM</h2><table><tr><th>Program</th><th>PID</th><th>MB</th><th>Status</th><th>Hvorfor</th><th>Sti</th></tr>$procRows</table>
<h2>Autostart</h2><table><tr><th>ID</th><th>Navn</th><th>Scope</th><th>Status</th><th>Hvorfor</th><th>Kommando</th></tr>$startupRows</table>
<p class="small">Audit gjør ingen endringer. Deaktivering i interaktiv modus blir sikkerhetskopiert under <code>$(H (Join-Path $Root 'Backups'))</code>.</p>
</body></html>
"@
    [IO.File]::WriteAllText($htmlPath,$html,$script:Utf8NoBom)

    $latest = [pscustomobject]@{json=$jsonPath;html=$htmlPath;txt=$txtPath;createdAt=$doc.createdAt}
    Save-RahJson (Join-Path $reports 'latest.json') $latest
    return $latest
}

function Read-RahSelection {
    param([string]$Prompt,[int[]]$Allowed)
    $raw = Read-Host $Prompt
    $values = @()
    foreach ($part in ($raw -split ',')) {
        $n=0
        if ([int]::TryParse($part.Trim(),[ref]$n) -and ($Allowed -contains $n)) { $values += $n }
    }
    return @($values | Select-Object -Unique)
}

function Stop-RahSelectedProcesses {
    param([object[]]$Candidates)
    if (-not $Candidates.Count) {
        Write-Host 'Ingen RAM-kandidater funnet.' -ForegroundColor DarkYellow
        return
    }
    $map = @{}
    $i = 1
    foreach ($p in $Candidates) {
        $map[$i]=$p
        Write-Host ("[{0}] {1}  PID={2}  RAM={3} MB  {4}" -f $i,$p.name,$p.pid,$p.memoryMB,$p.reason)
        $i++
    }
    $selected = Read-RahSelection 'Velg nummer(e) som skal avsluttes, f.eks. 1,3. ENTER avbryter' @($map.Keys)
    foreach ($n in $selected) {
        $p = $map[$n]
        $live = Get-Process -Id $p.pid -ErrorAction SilentlyContinue
        if (-not $live) { continue }
        $fresh = Get-RahProcessClassification -Name $live.ProcessName -Path $p.path -CommandLine $p.commandLine -WorkingSetMB ([math]::Round($live.WorkingSet64/1MB,1))
        if (-not $fresh.stopAllowed -or $fresh.category -eq 'PROTECTED') {
            Write-Host "BLOKKERT: $($p.name) er nå beskyttet." -ForegroundColor Red
            continue
        }
        $confirm = Read-Host "Avslutt $($p.name) (PID $($p.pid))? Skriv JA"
        if ($confirm -ne 'JA') { continue }
        $graceful = $false
        try { $graceful = [bool]$live.CloseMainWindow() } catch {}
        if ($graceful) {
            try { $null = $live.WaitForExit(3000) } catch {}
        }
        $still = Get-Process -Id $p.pid -ErrorAction SilentlyContinue
        if ($still) {
            $force = Read-Host "$($p.name) svarte ikke/ligger i bakgrunnen. Tving stopp? Skriv JA"
            if ($force -eq 'JA') {
                Stop-Process -Id $p.pid -Force -ErrorAction Stop
                Write-Host "Stoppet: $($p.name)" -ForegroundColor Green
            }
        } else {
            Write-Host "Lukket: $($p.name)" -ForegroundColor Green
        }
    }
}

function Disable-RahSelectedStartup {
    param([object[]]$Candidates)
    if (-not $Candidates.Count) {
        Write-Host 'Ingen autostart-kandidater funnet.' -ForegroundColor DarkYellow
        return
    }
    $map=@{}
    foreach ($s in $Candidates) {
        $map[[int]$s.id]=$s
        Write-Host ("[{0}] {1}  {2}  {3}" -f $s.id,$s.name,$s.scope,$s.reason)
    }
    $selected = Read-RahSelection 'Velg startup-ID(er) som skal deaktiveres. ENTER avbryter' @($map.Keys)
    if (-not $selected.Count) { return }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDir = Join-Path $Root 'Backups'
    $disabledDir = Join-Path $Root ("DisabledStartup\" + $stamp)
    New-Item -ItemType Directory -Path $backupDir,$disabledDir -Force | Out-Null
    $backupRows=@()

    foreach ($id in $selected) {
        $s=$map[$id]
        if (-not $s.disableAllowed -or $s.category -eq 'KEEP') {
            Write-Host "BLOKKERT: $($s.name) er beskyttet." -ForegroundColor Red
            continue
        }
        $confirm=Read-Host "Deaktiver autostart for $($s.name)? Skriv JA"
        if ($confirm -ne 'JA') { continue }

        if ($s.sourceType -eq 'Registry') {
            $backupRows += [pscustomobject]@{sourceType='Registry';source=$s.source;name=$s.name;value=$s.command;disabledPath=$null;originalPath=$null}
            Remove-ItemProperty -LiteralPath $s.source -Name $s.name -ErrorAction Stop
            Write-Host "Deaktivert: $($s.name)" -ForegroundColor Green
        }
        elseif ($s.sourceType -eq 'StartupFolder') {
            $dest = Join-Path $disabledDir ([IO.Path]::GetFileName([string]$s.originalPath))
            $backupRows += [pscustomobject]@{sourceType='StartupFolder';source=$s.source;name=$s.name;value=$s.command;disabledPath=$dest;originalPath=$s.originalPath}
            Move-Item -LiteralPath $s.originalPath -Destination $dest -Force
            Write-Host "Flyttet ut av Startup: $($s.name)" -ForegroundColor Green
        }
    }

    if ($backupRows.Count) {
        $backup=[pscustomobject]@{schema='rah-memory-doctor-startup-backup';version=1;createdAt=(Get-Date).ToUniversalTime().ToString('o');entries=@($backupRows)}
        $path=Join-Path $backupDir ("startup-$stamp.json")
        Save-RahJson $path $backup
        Write-Host "Backup: $path" -ForegroundColor Cyan
    }
}

function Restore-RahLatestStartup {
    $backupDir=Join-Path $Root 'Backups'
    $latest=Get-ChildItem -LiteralPath $backupDir -Filter 'startup-*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Host 'Ingen startup-backup funnet.' -ForegroundColor DarkYellow
        return
    }
    $doc=Get-Content -LiteralPath $latest.FullName -Raw | ConvertFrom-Json
    foreach ($e in @($doc.entries)) {
        if ($e.sourceType -eq 'Registry') {
            New-Item -Path $e.source -Force | Out-Null
            Set-ItemProperty -LiteralPath $e.source -Name $e.name -Value ([string]$e.value) -Force
            Write-Host "Gjenopprettet registry startup: $($e.name)" -ForegroundColor Green
        }
        elseif ($e.sourceType -eq 'StartupFolder') {
            if ($e.disabledPath -and (Test-Path -LiteralPath $e.disabledPath -PathType Leaf)) {
                $parent=Split-Path -Parent ([string]$e.originalPath)
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
                Move-Item -LiteralPath $e.disabledPath -Destination $e.originalPath -Force
                Write-Host "Gjenopprettet Startup-fil: $($e.name)" -ForegroundColor Green
            }
        }
    }
}

function Invoke-RahSelfTest {
    $a=Get-RahProcessClassification -Name 'MsMpEng' -Path 'C:\ProgramData\Microsoft\Windows Defender\MsMpEng.exe' -CommandLine '' -WorkingSetMB 500
    if ($a.category -ne 'PROTECTED' -or $a.stopAllowed) { throw 'SelfTest: Defender protection failed.' }
    $b=Get-RahProcessClassification -Name 'rah_agent_bridge' -Path 'C:\RAH\AgentBridge\rah_agent_bridge.py' -CommandLine 'python C:\RAH\AgentBridge\rah_agent_bridge.py' -WorkingSetMB 600
    if ($b.category -ne 'PROTECTED' -or $b.stopAllowed) { throw 'SelfTest: RAH protection failed.' }
    $c=Get-RahProcessClassification -Name 'ExampleUpdater' -Path 'C:\Apps\ExampleUpdater.exe' -CommandLine 'ExampleUpdater --tray' -WorkingSetMB 400
    if ($c.category -ne 'REVIEW' -or -not $c.stopAllowed) { throw 'SelfTest: review classification failed.' }
    $fake=[pscustomobject]@{sourceType='Registry';scope='User';source='HKCU:\X';name='Example Updater';command='C:\Apps\updater.exe';originalPath=$null}
    $sc=Get-RahStartupClassification -Entry $fake -Processes @($c)
    if ($sc.category -ne 'REVIEW' -or -not $sc.disableAllowed) { throw 'SelfTest: startup classification failed.' }
    Write-Host 'PASS: RAH Memory & Startup Doctor v1 self-test' -ForegroundColor Green
}

if ($MemoryThresholdMB -lt 50 -or $MemoryThresholdMB -gt 16384) { throw 'MemoryThresholdMB must be between 50 and 16384.' }
New-Item -ItemType Directory -Path $Root -Force | Out-Null

if ($Mode -eq 'SelfTest') {
    Invoke-RahSelfTest
    exit 0
}
if ($Mode -eq 'RestoreLatest') {
    if (-not (Test-RahAdministrator)) { throw 'Administrator required for restore.' }
    Restore-RahLatestStartup
    exit 0
}

$memoryBefore=Get-RahMemorySnapshot
$processes=Get-RahProcessInventory
$startup=Get-RahStartupInventory -Processes $processes
$latest=Write-RahReport -Memory $memoryBefore -Processes $processes -Startup $startup

Write-Host ''
Write-Host '=============================================================' -ForegroundColor Yellow
Write-Host 'RAH MEMORY & STARTUP DOCTOR v1' -ForegroundColor Yellow
Write-Host '=============================================================' -ForegroundColor Yellow
Write-Host ("RAM: {0} / {1} MB brukt ({2}%)" -f $memoryBefore.usedMB,$memoryBefore.totalMB,$memoryBefore.usedPercent)
Write-Host ("Prosess REVIEW: {0}" -f @($processes | Where-Object category -eq 'REVIEW').Count)
Write-Host ("Startup REVIEW: {0}" -f @($startup | Where-Object category -eq 'REVIEW').Count)
Write-Host ("Rapport: {0}" -f $latest.html) -ForegroundColor Cyan
Write-Host 'REVIEW betyr vurderingskandidat, ikke at programmet er unødvendig.' -ForegroundColor DarkYellow

if ($Mode -eq 'Audit') {
    if (-not $NoOpenReport) { Start-Process $latest.html }
    exit 0
}

while ($true) {
    Write-Host ''
    Write-Host '[K] Kill/close valgt RAM-kandidat' -ForegroundColor Cyan
    Write-Host '[S] Deaktiver valgt autostart (med backup)' -ForegroundColor Cyan
    Write-Host '[R] Restore siste autostart-backup' -ForegroundColor Cyan
    Write-Host '[A] Ny analyse og rapport' -ForegroundColor Cyan
    Write-Host '[O] Åpne HTML-rapport' -ForegroundColor Cyan
    Write-Host '[Q] Avslutt' -ForegroundColor Cyan
    $choice=(Read-Host 'Velg').Trim().ToUpperInvariant()

    switch ($choice) {
        'K' {
            $candidates=@($processes | Where-Object { $_.category -eq 'REVIEW' -and $_.stopAllowed })
            Stop-RahSelectedProcesses -Candidates $candidates
            $memoryAfter=Get-RahMemorySnapshot
            Write-Host ("RAM etter: {0} MB brukt / {1} MB fri" -f $memoryAfter.usedMB,$memoryAfter.freeMB) -ForegroundColor Green
        }
        'S' {
            if (-not (Test-RahAdministrator)) {
                Write-Host 'Administrator kreves for autostart-endringer.' -ForegroundColor Red
            } else {
                $candidates=@($startup | Where-Object { $_.category -eq 'REVIEW' -and $_.disableAllowed })
                Disable-RahSelectedStartup -Candidates $candidates
            }
        }
        'R' {
            if (-not (Test-RahAdministrator)) { Write-Host 'Administrator kreves for restore.' -ForegroundColor Red }
            else { Restore-RahLatestStartup }
        }
        'A' {
            $memoryBefore=Get-RahMemorySnapshot
            $processes=Get-RahProcessInventory
            $startup=Get-RahStartupInventory -Processes $processes
            $latest=Write-RahReport -Memory $memoryBefore -Processes $processes -Startup $startup
            Write-Host "Ny rapport: $($latest.html)" -ForegroundColor Green
        }
        'O' { Start-Process $latest.html }
        'Q' { break }
        default { Write-Host 'Ukjent valg.' -ForegroundColor DarkYellow }
    }
}
exit 0

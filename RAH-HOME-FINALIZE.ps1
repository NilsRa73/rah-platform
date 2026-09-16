param(
    [ValidateSet('Auto','Leader','Worker')][string]$Mode = 'Auto',
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [string]$InstallRoot = 'C:\RAH\Home',
    [string]$DesktopPath = '',
    [string]$SourceDirectory = '',
    [string]$WorkerAddress = '',
    [string]$PairCode = '',
    [switch]$NoRemote,
    [switch]$SkipFirewall,
    [switch]$SkipAutostart,
    [switch]$NoStart,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahHomeFinalizeVersion = '1.0.0'
$script:RahSourceBase = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$script:RahMaxScriptBytes = 4MB
$script:RahWorkerTaskName = 'RAH Home Worker'
$script:RahFirewallName = 'RAH Home Worker TCP 18766'

function Test-RahPrivateIPv4 {
    param([Parameter(Mandatory)][string]$Address)
    $parts = $Address.Split('.')
    if ($parts.Count -ne 4) { return $false }
    $numbers = @()
    foreach ($part in $parts) {
        if ($part -notmatch '^\d{1,3}$') { return $false }
        $n = [int]$part
        if ($n -lt 0 -or $n -gt 255 -or [string]$n -ne $part) { return $false }
        $numbers += $n
    }
    return (
        $numbers[0] -eq 10 -or
        ($numbers[0] -eq 192 -and $numbers[1] -eq 168) -or
        ($numbers[0] -eq 172 -and $numbers[1] -ge 16 -and $numbers[1] -le 31)
    )
}

function Test-RahAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { return $false }
}

function Resolve-RahDesktopPath {
    param([string]$Requested)
    if (-not [string]::IsNullOrWhiteSpace($Requested)) { return [IO.Path]::GetFullPath($Requested) }
    $value = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($value)) { throw 'Fant ikke skrivebordsmappen.' }
    return [IO.Path]::GetFullPath($value)
}

function Assert-RahPowerShellFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Markers
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Mangler PowerShell-fil: $Path" }
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -le 0 -or $item.Length -gt $script:RahMaxScriptBytes) { throw "Ugyldig filstorrelse: $Path" }
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($item.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count -ne 0) { throw "PowerShell-parser avviste $Path : $($errors[0].Message)" }
    $text = [IO.File]::ReadAllText($item.FullName)
    foreach ($marker in $Markers) {
        if (-not $text.Contains($marker)) { throw "Kontraktmarkor mangler i $Path : $marker" }
    }
    return $item.FullName
}

function Get-RahScript {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string[]]$Markers,
        [Parameter(Mandatory)][string]$BootstrapRoot
    )
    New-Item -ItemType Directory -Path $BootstrapRoot -Force | Out-Null
    $target = Join-Path $BootstrapRoot $Name
    if (-not [string]::IsNullOrWhiteSpace($SourceDirectory)) {
        $source = Join-Path ([IO.Path]::GetFullPath($SourceDirectory)) $Name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "SourceDirectory mangler $Name" }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    else {
        $uri = "$script:RahSourceBase/$Name"
        Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $target -ErrorAction Stop
    }
    return Assert-RahPowerShellFile -Path $target -Markers $Markers
}

function Invoke-RahChildPowerShell {
    param([Parameter(Mandatory)][string[]]$Arguments,[switch]$Capture)
    $exe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Fant ikke Windows PowerShell: $exe" }
    if ($Capture) {
        $old = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $raw = & $exe @Arguments 2>&1
            $code = $LASTEXITCODE
        }
        finally { $ErrorActionPreference = $old }
        return [pscustomobject]@{ ExitCode=$code; Text=(($raw | Out-String).Trim()) }
    }
    & $exe @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "Child PowerShell feilet med exit code $code." }
}

function Get-RahPrivateLocalAddresses {
    $found = @()
    if (-not (Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue)) { return $found }
    foreach ($cfg in @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter -and $_.NetAdapter.Status -eq 'Up' })) {
        foreach ($a in @($cfg.IPv4Address)) {
            if ($a -and (Test-RahPrivateIPv4 -Address ([string]$a.IPAddress))) {
                $found += [pscustomobject]@{
                    Address = [string]$a.IPAddress
                    HasGateway = [bool](@($cfg.IPv4DefaultGateway).Count -gt 0)
                    Alias = [string]$cfg.InterfaceAlias
                }
            }
        }
    }
    return @($found | Sort-Object Address -Unique)
}

function Select-RahWorkerAddress {
    param([string]$Requested)
    $candidates = @(Get-RahPrivateLocalAddresses)
    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        $value = $Requested.Trim()
        if (-not (Test-RahPrivateIPv4 -Address $value)) { throw 'WorkerAddress ma vaere privat RFC1918 IPv4.' }
        if (@($candidates | Where-Object Address -eq $value).Count -eq 0) { throw 'WorkerAddress finnes ikke pa en aktiv lokal adapter.' }
        return $value
    }
    $gateway = @($candidates | Where-Object HasGateway)
    if ($gateway.Count -eq 1) { return [string]$gateway[0].Address }
    if ($candidates.Count -eq 1) { return [string]$candidates[0].Address }
    if ($candidates.Count -eq 0) { throw 'Fant ingen aktiv privat RFC1918-adresse pa denne PC-en.' }

    Write-Host 'Flere private adresser ble funnet:' -ForegroundColor Yellow
    for ($i=0; $i -lt $candidates.Count; $i++) {
        Write-Host ("[{0}] {1}  {2}" -f ($i+1),$candidates[$i].Address,$candidates[$i].Alias)
    }
    $choice = 0
    $raw = Read-Host 'Velg RAH-hjemmenett-adresse'
    if (-not [int]::TryParse($raw,[ref]$choice) -or $choice -lt 1 -or $choice -gt $candidates.Count) { throw 'Ugyldig adressevalg.' }
    return [string]$candidates[$choice-1].Address
}

function Test-RahTcpPort {
    param([Parameter(Mandatory)][string]$Address,[Parameter(Mandatory)][int]$TargetPort,[int]$TimeoutMs=1200)
    $tcp = New-Object Net.Sockets.TcpClient
    try {
        $op = $tcp.BeginConnect($Address,$TargetPort,$null,$null)
        $handle = $op.AsyncWaitHandle
        try {
            if (-not $handle.WaitOne($TimeoutMs)) { return $false }
            $tcp.EndConnect($op)
            return $true
        }
        catch { return $false }
        finally { $handle.Close() }
    }
    finally { $tcp.Dispose() }
}

function Stop-RahOwnWorkerAgents {
    param([Parameter(Mandatory)][string]$AgentPath)
    $needle = [IO.Path]::GetFileName($AgentPath)
    foreach ($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -ieq 'powershell.exe' -or $_.Name -ieq 'pwsh.exe') -and
        $_.CommandLine -and $_.CommandLine.Contains($needle)
    })) {
        try { Stop-Process -Id ([int]$p.ProcessId) -Force -ErrorAction Stop } catch { }
    }
    Start-Sleep -Milliseconds 400
}

function Start-RahWorkerAgent {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][int]$TargetPort
    )
    $agent = Join-Path $Root 'RAH-HOME-NODE-AGENT.ps1'
    Assert-RahPowerShellFile -Path $agent -Markers @("RahNodeAgentVersion = '1.0.0'",'RahAllowedActions') | Out-Null
    Stop-RahOwnWorkerAgents -AgentPath $agent

    $logDir = Join-Path $Root 'logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $stdout = Join-Path $logDir 'worker-agent.log'
    $stderr = Join-Path $logDir 'worker-agent.err.log'
    Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
    $exe = Join-Path $PSHOME 'powershell.exe'
    $argText = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $agent + '" -ListenAddress ' + $Address + ' -AllowLan -Port ' + $TargetPort
    $proc = Start-Process -FilePath $exe -ArgumentList $argText -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru

    $pairCode = ''
    $deadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 250
        if ($proc.HasExited) {
            $err = if (Test-Path -LiteralPath $stderr) { (Get-Content -Raw -LiteralPath $stderr -ErrorAction SilentlyContinue) } else { '' }
            throw "Worker Agent stoppet under oppstart. $err"
        }
        if (Test-Path -LiteralPath $stdout) {
            $text = Get-Content -Raw -LiteralPath $stdout -ErrorAction SilentlyContinue
            if ($text -match 'PAIR CODE:\s*(\d{6})') { $pairCode = $Matches[1] }
        }
        $portReady = Test-RahTcpPort -Address $Address -TargetPort $TargetPort -TimeoutMs 500
    } while (([string]::IsNullOrWhiteSpace($pairCode) -or -not $portReady) -and (Get-Date) -lt $deadline)

    if ([string]::IsNullOrWhiteSpace($pairCode)) { throw 'Worker Agent startet, men pairingkode ble ikke fanget innen 20 sekunder.' }
    if (-not $portReady) { throw 'Worker Agent startet, men TCP-porten ble ikke klar.' }
    return [pscustomobject]@{ PairCode=$pairCode; ProcessId=$proc.Id; Stdout=$stdout; Stderr=$stderr }
}

function Set-RahWorkerFirewall {
    param([Parameter(Mandatory)][string]$Address,[Parameter(Mandatory)][int]$TargetPort)
    if ($SkipFirewall) { return 'skipped' }
    if (-not (Get-Command New-NetFirewallRule -ErrorAction SilentlyContinue)) { throw 'Windows Firewall cmdlets mangler.' }
    Get-NetFirewallRule -DisplayName $script:RahFirewallName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName $script:RahFirewallName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $TargetPort -LocalAddress $Address -Profile Private | Out-Null
    return 'ready'
}

function Set-RahWorkerAutostart {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Address,[Parameter(Mandatory)][int]$TargetPort)
    if ($SkipAutostart) { return 'skipped' }
    if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) { throw 'ScheduledTasks-modulen mangler.' }
    $agent = Join-Path $Root 'RAH-HOME-NODE-AGENT.ps1'
    $exe = Join-Path $PSHOME 'powershell.exe'
    $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $agent + '" -ListenAddress ' + $Address + ' -AllowLan -Port ' + $TargetPort
    $action = New-ScheduledTaskAction -Execute $exe -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $script:RahWorkerTaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    $task = Get-ScheduledTask -TaskName $script:RahWorkerTaskName -ErrorAction Stop
    if ($null -eq $task) { throw 'Autostart-task ble ikke opprettet.' }
    return 'ready'
}

function Get-RahPeerAddress {
    param([int]$TargetPort)
    $peersPath = Join-Path $env:LOCALAPPDATA 'RAH\home-node-peers.json'
    if (-not (Test-Path -LiteralPath $peersPath -PathType Leaf)) { return '' }
    try {
        $doc = Get-Content -Raw -LiteralPath $peersPath | ConvertFrom-Json
        $found = @()
        foreach ($peer in @($doc.peers)) {
            $key = [string]$peer.key
            if ($key -match '^((?:\d{1,3}\.){3}\d{1,3}):(\d+)$') {
                $ip = $Matches[1]
                $p = [int]$Matches[2]
                if ($p -eq $TargetPort -and (Test-RahPrivateIPv4 -Address $ip)) { $found += $ip }
            }
        }
        $found = @($found | Select-Object -Unique)
        if ($found.Count -eq 1) { return [string]$found[0] }
    }
    catch { }
    return ''
}

function Invoke-RahClientAction {
    param(
        [Parameter(Mandatory)][string]$ClientPath,
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][string]$Action,
        [string]$Code=''
    )
    $args = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$ClientPath,'-NodeAddress',$Address,'-Port',[string]$Port,'-Action',$Action,'-TimeoutMs','10000')
    if ($Action -eq 'pair') { $args += @('-PairCode',$Code) }
    return Invoke-RahChildPowerShell -Arguments $args -Capture
}

function Convert-RahClientJson {
    param([Parameter(Mandatory)]$Invocation,[Parameter(Mandatory)][string]$Context)
    if ($Invocation.ExitCode -ne 0) { throw "$Context feilet: $($Invocation.Text)" }
    try { return $Invocation.Text | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "$Context returnerte ikke gyldig JSON." }
}

function Write-RahFinalizeReport {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$FinalMode,
        [Parameter(Mandatory)][bool]$Pass,
        [Parameter(Mandatory)]$Checks,
        [string]$Failure='',
        [string]$RemoteAddress=''
    )
    $reportDir = Join-Path $Root 'reports'
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    $doc = [pscustomobject]@{
        schema='rah-home-finalize'
        version=1
        finalizeVersion=$script:RahHomeFinalizeVersion
        mode=$FinalMode
        computerName=$env:COMPUTERNAME
        createdAt=(Get-Date).ToUniversalTime().ToString('o')
        installRoot=$Root
        remoteAddress=if([string]::IsNullOrWhiteSpace($RemoteAddress)){$null}else{$RemoteAddress}
        pass=[bool]$Pass
        failure=if([string]::IsNullOrWhiteSpace($Failure)){$null}else{$Failure}
        checks=@($Checks)
    }
    $json = Join-Path $reportDir 'rah-home-finalize-latest.json'
    $txt = Join-Path $Root 'RAH-HOME-FINAL-REPORT.txt'
    [IO.File]::WriteAllText($json,($doc | ConvertTo-Json -Depth 10),(New-Object Text.UTF8Encoding($false)))
    $lines = @(
        'RAH HOME FINAL REPORT',
        '=====================',
        "Computer : $($doc.computerName)",
        "Mode     : $FinalMode",
        "Result   : $(if($Pass){'PASS'}else{'FAIL'})",
        "Root     : $Root",
        "Remote   : $(if($RemoteAddress){$RemoteAddress}else{'-'})",
        "Created  : $($doc.createdAt)"
    )
    if ($Failure) { $lines += "Failure  : $Failure" }
    $lines += ''
    foreach ($c in @($Checks)) { $lines += ("[{0}] {1}" -f $(if($c.ok){'OK'}else{'FAIL'}),$c.name) }
    [IO.File]::WriteAllLines($txt,$lines,(New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{ Json=$json; Text=$txt }
}

function Invoke-RahFinalizeSelfTest {
    foreach ($good in @('10.0.0.2','172.16.5.6','192.168.1.9')) {
        if (-not (Test-RahPrivateIPv4 -Address $good)) { throw "SelfTest: privat IP avvist: $good" }
    }
    foreach ($bad in @('127.0.0.1','8.8.8.8','0.0.0.0','192.168.001.1')) {
        if (Test-RahPrivateIPv4 -Address $bad) { throw "SelfTest: ugyldig IP tillatt: $bad" }
    }
    if ($script:RahHomeFinalizeVersion -ne '1.0.0') { throw 'SelfTest: feil finalize-versjon.' }
    if ($script:RahSourceBase -ne 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main') { throw 'SelfTest: uventet source base.' }
    if ($script:RahWorkerTaskName -ne 'RAH Home Worker') { throw 'SelfTest: uventet task-navn.' }
    Write-Host 'PASS: RAH Home Finalize v1 self-test' -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahFinalizeSelfTest
    exit 0
}

$resolvedMode = $Mode
if ($resolvedMode -eq 'Auto') {
    $resolvedMode = if ($env:COMPUTERNAME -ieq 'HOVED-PC') { 'Leader' } else { 'Worker' }
}
$root = [IO.Path]::GetFullPath($InstallRoot)
$desktop = Resolve-RahDesktopPath -Requested $DesktopPath
$bootstrap = Join-Path $root 'bootstrap'
$checks = @()
$remote = ''

Write-Host '=====================================================================' -ForegroundColor Yellow
Write-Host '                  RAH HOME FINALIZE v1.0.0' -ForegroundColor Yellow
Write-Host '=====================================================================' -ForegroundColor Yellow
Write-Host "PC   : $env:COMPUTERNAME"
Write-Host "Mode : $resolvedMode"
Write-Host "Root : $root"
Write-Host ''

try {
    New-Item -ItemType Directory -Path $root,$desktop,$bootstrap -Force | Out-Null

    if ($resolvedMode -eq 'Worker') {
        Write-Host '[1/6] PRECHECK: velger privat worker-adresse ...' -ForegroundColor Cyan
        $address = Select-RahWorkerAddress -Requested $WorkerAddress
        $checks += [pscustomobject]@{name="private-address:$address";ok=$true}
        Write-Host "      $address" -ForegroundColor Green

        Write-Host '[2/6] Installerer/reparerer stable Worker ...' -ForegroundColor Cyan
        $installer = Get-RahScript -Name 'RAH-HOME-INSTALL.ps1' -Markers @("RahHomeInstallerVersion = '1.0.0'",'Get-RahComponentManifest','New-RahWorkerShortcut') -BootstrapRoot $bootstrap
        Invoke-RahChildPowerShell -Arguments @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$installer,'-SelfTest')
        $installArgs = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$installer,'-Mode','Worker','-Port',[string]$Port,'-InstallRoot',$root,'-DesktopPath',$desktop,'-WorkerAddress',$address)
        if (-not [string]::IsNullOrWhiteSpace($SourceDirectory)) { $installArgs += @('-SourceDirectory',[IO.Path]::GetFullPath($SourceDirectory)) }
        Invoke-RahChildPowerShell -Arguments $installArgs
        $checks += [pscustomobject]@{name='worker-install';ok=$true}

        Write-Host '[3/6] Kjører Agent + Client self-test ...' -ForegroundColor Cyan
        foreach ($item in @(
            @{Name='RAH-HOME-NODE-AGENT.ps1';Args=@('-SelfTest')},
            @{Name='RAH-HOME-NODE-CLIENT.ps1';Args=@('-NodeAddress','127.0.0.1','-SelfTest')}
        )) {
            $path = Join-Path $root $item.Name
            $args = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$path) + @($item.Args)
            Invoke-RahChildPowerShell -Arguments $args
        }
        $checks += [pscustomobject]@{name='agent-client-selftests';ok=$true}

        Write-Host '[4/6] Reparerer firewall + autostart ...' -ForegroundColor Cyan
        $fw = Set-RahWorkerFirewall -Address $address -TargetPort $Port
        $auto = Set-RahWorkerAutostart -Root $root -Address $address -TargetPort $Port
        $checks += [pscustomobject]@{name="firewall:$fw";ok=$true}
        $checks += [pscustomobject]@{name="autostart:$auto";ok=$true}

        Write-Host '[5/6] Starter Worker Agent og fanger pairingkode ...' -ForegroundColor Cyan
        if ($NoStart) {
            $agentStart = $null
            $checks += [pscustomobject]@{name='worker-start:skipped';ok=$true}
        }
        else {
            $agentStart = Start-RahWorkerAgent -Root $root -Address $address -TargetPort $Port
            $checks += [pscustomobject]@{name='worker-agent-listening';ok=$true}
        }

        Write-Host '[6/6] Skriver samlet Worker-status ...' -ForegroundColor Cyan
        $statePath = Join-Path $root 'rah-home-install-state.json'
        $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
        if ($state.mode -ne 'Worker' -or [string]$state.workerAddress -ne $address -or [int]$state.port -ne $Port) { throw 'Worker install-state stemmer ikke med sluttkonfigurasjonen.' }
        $checks += [pscustomobject]@{name='worker-install-state';ok=$true}

        if ($agentStart) {
            $readyPath = Join-Path $root 'RAH-HOME-WORKER-READY.txt'
            $expires = (Get-Date).AddMinutes(10).ToString('yyyy-MM-dd HH:mm:ss')
            $readyText = @(
                'RAH HOME WORKER READY',
                '=====================',
                "PC        : $env:COMPUTERNAME",
                "IP        : $address",
                "PORT      : $Port",
                "PAIR CODE : $($agentStart.PairCode)",
                "GYLDIG TIL: $expires",
                '',
                'Pa HOVED-PC: kjor samme START-HER.cmd og skriv IP + PAIR CODE nar den spor.'
            )
            [IO.File]::WriteAllLines($readyPath,$readyText,(New-Object Text.UTF8Encoding($false)))
            Write-Host ''
            Write-Host '=============================================================' -ForegroundColor Green
            Write-Host 'RAH HOME WORKER: READY' -ForegroundColor Green
            Write-Host "IP        : $address"
            Write-Host "PAIR CODE : $($agentStart.PairCode)" -ForegroundColor Cyan
            Write-Host "Gyldig ca.: $expires"
            Write-Host "Ready-fil : $readyPath"
            Write-Host '=============================================================' -ForegroundColor Green
        }
        $paths = Write-RahFinalizeReport -Root $root -FinalMode 'Worker' -Pass $true -Checks $checks
        Write-Host "Rapport: $($paths.Text)"
        exit 0
    }

    Write-Host '[1/5] PRECHECK + lokal HOVED-PC acceptance ...' -ForegroundColor Cyan
    $acceptance = Get-RahScript -Name 'RAH-HOME-ACCEPTANCE.ps1' -Markers @("RahHomeAcceptanceVersion = '1.0.0'",'Test-RahInstallOutput','rah-home-acceptance') -BootstrapRoot $bootstrap
    Invoke-RahChildPowerShell -Arguments @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$acceptance,'-SelfTest')
    $acceptArgs = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$acceptance,'-InstallRoot',$root,'-DesktopPath',$desktop)
    if (-not [string]::IsNullOrWhiteSpace($SourceDirectory)) { $acceptArgs += @('-SourceDirectory',[IO.Path]::GetFullPath($SourceDirectory)) }
    Invoke-RahChildPowerShell -Arguments $acceptArgs
    $checks += [pscustomobject]@{name='hoved-pc-local-acceptance';ok=$true}

    Write-Host '[2/5] Verifiserer stable Client/Job/Controller self-tests ...' -ForegroundColor Cyan
    $client = Join-Path $root 'RAH-HOME-NODE-CLIENT.ps1'
    foreach ($item in @(
        @{Name='RAH-HOME-NODE-CLIENT.ps1';Args=@('-NodeAddress','127.0.0.1','-SelfTest')},
        @{Name='RAH-HOME-NODE-JOB.ps1';Args=@('-NodeAddress','127.0.0.1','-SelfTest')},
        @{Name='RAH-HOME-CLUSTER-CONTROLLER.ps1';Args=@('-SelfTest')}
    )) {
        $path = Join-Path $root $item.Name
        $args = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$path) + @($item.Args)
        Invoke-RahChildPowerShell -Arguments $args
    }
    $checks += [pscustomobject]@{name='leader-component-selftests';ok=$true}

    if ($NoRemote) {
        $checks += [pscustomobject]@{name='physical-worker:skipped-by-request';ok=$true}
        $paths = Write-RahFinalizeReport -Root $root -FinalMode 'Leader' -Pass $true -Checks $checks
        Write-Host 'LOCAL LEADER PASS (remote test skipped by request).' -ForegroundColor Green
        Write-Host "Rapport: $($paths.Text)"
        exit 0
    }

    Write-Host '[3/5] Finner Worker ...' -ForegroundColor Cyan
    $remote = $WorkerAddress.Trim()
    if ([string]::IsNullOrWhiteSpace($remote)) { $remote = Get-RahPeerAddress -TargetPort $Port }
    if ([string]::IsNullOrWhiteSpace($remote)) {
        $remote = (Read-Host 'Worker IP-adresse (fra WORKER READY)').Trim()
    }
    if (-not (Test-RahPrivateIPv4 -Address $remote)) { throw 'Worker IP ma vaere privat RFC1918 IPv4.' }
    $checks += [pscustomobject]@{name="worker-address:$remote";ok=$true}

    Write-Host '[4/5] Autentiserer/pairer Worker ...' -ForegroundColor Cyan
    $healthTry = Invoke-RahClientAction -ClientPath $client -Address $remote -Action 'health'
    if ($healthTry.ExitCode -ne 0) {
        $code = $PairCode.Trim()
        if ([string]::IsNullOrWhiteSpace($code)) { $code = (Read-Host 'PAIR CODE (6 siffer fra Worker)').Trim() }
        if ($code -notmatch '^\d{6}$') { throw 'PAIR CODE ma vaere nøyaktig seks siffer.' }
        $pair = Invoke-RahClientAction -ClientPath $client -Address $remote -Action 'pair' -Code $code
        if ($pair.ExitCode -ne 0) { throw "Pairing feilet: $($pair.Text)" }
        $checks += [pscustomobject]@{name='worker-pairing';ok=$true}
    }
    else {
        $checks += [pscustomobject]@{name='worker-existing-pairing';ok=$true}
    }

    Write-Host '[5/5] Kjører ekte health + systemInfo + benchmark ...' -ForegroundColor Cyan
    foreach ($action in @('health','systemInfo','benchmark')) {
        $call = Invoke-RahClientAction -ClientPath $client -Address $remote -Action $action
        $parsed = Convert-RahClientJson -Invocation $call -Context $action
        if ($parsed.ok -ne $true) { throw "$action returnerte ok=false." }
        $checks += [pscustomobject]@{name="remote-$action";ok=$true}
        Write-Host ("      {0}: OK" -f $action) -ForegroundColor Green
    }

    $paths = Write-RahFinalizeReport -Root $root -FinalMode 'Leader' -Pass $true -Checks $checks -RemoteAddress $remote
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Green
    Write-Host '                 RAH HOME 2-PC: FULL PASS' -ForegroundColor Green
    Write-Host '=====================================================================' -ForegroundColor Green
    Write-Host "Worker : $remote`:$Port"
    Write-Host "Rapport: $($paths.Text)"
    Write-Host 'HOVED-PC og Worker er paret og har bestatt health/systemInfo/benchmark.'
    exit 0
}
catch {
    $message = $_.Exception.Message
    $checks += [pscustomobject]@{name='finalize-error';ok=$false}
    try { $paths = Write-RahFinalizeReport -Root $root -FinalMode $resolvedMode -Pass $false -Checks $checks -Failure $message -RemoteAddress $remote } catch { $paths = $null }
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Red
    Write-Host '                    RAH HOME FINALIZE: FAIL' -ForegroundColor Red
    Write-Host '=====================================================================' -ForegroundColor Red
    Write-Host $message -ForegroundColor Red
    if ($paths) { Write-Host "Rapport: $($paths.Text)" }
    exit 1
}

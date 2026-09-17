[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$bridgeDir = Join-Path $root 'desktop-bridge'
$installer = Join-Path $root 'INSTALL-RAH-AUTOSTART.bat'
$launcher = Join-Path $root 'START-RAH-BRIDGE-AUTOSTART.bat'
$requirements = Join-Path $bridgeDir 'requirements.txt'
$logDir = 'C:\RAH\Logs'
$jobDir = 'C:\RAH\AgentJobs'
$latestJson = Join-Path $logDir 'RAVEN-HOVED-PC-FINAL-LATEST.json'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcript = Join-Path $logDir "RAVEN-HOVED-PC-FINAL-$timestamp.log"
$bridgeHealthUrl = 'http://127.0.0.1:18765/health'
$jobHealthUrl = 'http://127.0.0.1:18765/agent/jobs/health'
$jobsUrl = 'http://127.0.0.1:18765/agent/jobs'
$taskName = 'RAH Raven Bridge'
$script:Checks = [System.Collections.Generic.List[object]]::new()

function Add-Check([string]$Name, [bool]$Ok, [string]$Detail) {
    $script:Checks.Add([pscustomobject]@{ name=$Name; ok=$Ok; detail=$Detail })
    $tag = if($Ok){ 'PASS' } else { 'FAIL' }
    Write-Host "[$tag] $Name - $Detail"
    if(-not $Ok){ throw "$Name: $Detail" }
}

function Get-BasePython {
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if($py){ return [pscustomobject]@{ File=$py.Source; Args=@('-3') } }
    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if($python){ return [pscustomobject]@{ File=$python.Source; Args=@() } }
    throw 'Python 3 ble ikke funnet. Installer Python 3 eller legg python.exe/py.exe i PATH.'
}

function Invoke-JsonGet([string]$Uri, [int]$TimeoutSec=5) {
    Invoke-RestMethod -Method Get -Uri $Uri -TimeoutSec $TimeoutSec
}

New-Item -ItemType Directory -Force -Path $logDir,$jobDir | Out-Null
Start-Transcript -Path $transcript -Force | Out-Null
$final = 'FAIL'
$errorText = $null
$jobResult = $null

try {
    Write-Host '===================================================================='
    Write-Host ' RAH RAVEN HOVED-PC - FINAL / STABLE VERIFICATION'
    Write-Host ' PRECHECK -> REPAIR -> START -> POSTCHECK -> SYSTEM-INVENTORY'
    Write-Host '===================================================================='

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Add-Check 'Administrator token' $isAdmin $identity.Name

    $required = @(
        $installer,
        $launcher,
        (Join-Path $bridgeDir 'raven_bridge_agent.py'),
        (Join-Path $bridgeDir 'raven_bridge.py'),
        (Join-Path $bridgeDir 'raven_jobs.py'),
        (Join-Path $bridgeDir 'agent_runner.py'),
        $requirements
    )
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath $_) })
    Add-Check 'Canonical files' ($missing.Count -eq 0) ($(if($missing.Count){ $missing -join ', ' } else { 'alle nødvendige filer finnes' }))

    $venvPy = Join-Path $bridgeDir '.venv\Scripts\python.exe'
    if(-not (Test-Path -LiteralPath $venvPy)) {
        Write-Host '[REPAIR] Oppretter lokal Desktop Bridge venv...'
        $base = Get-BasePython
        & $base.File @($base.Args) -m venv (Join-Path $bridgeDir '.venv')
        if($LASTEXITCODE -ne 0){ throw "venv-oppretting feilet med exit $LASTEXITCODE" }
    }
    Add-Check 'Python venv' (Test-Path -LiteralPath $venvPy) $venvPy

    & $venvPy -c "import flask,mss,PIL" 2>$null
    if($LASTEXITCODE -ne 0) {
        Write-Host '[REPAIR] Python-avhengigheter mangler. Installerer pinned requirements...'
        & $venvPy -m pip install --disable-pip-version-check -r $requirements
        if($LASTEXITCODE -ne 0){ throw "pip requirements feilet med exit $LASTEXITCODE" }
    }
    & $venvPy -c "import flask,mss,PIL; print('bridge dependencies ok')"
    Add-Check 'Bridge dependencies' ($LASTEXITCODE -eq 0) 'Flask + mss + Pillow kan importeres'

    $compileTargets = @(
        (Join-Path $bridgeDir 'raven_bridge_agent.py'),
        (Join-Path $bridgeDir 'raven_bridge.py'),
        (Join-Path $bridgeDir 'raven_jobs.py'),
        (Join-Path $bridgeDir 'agent_runner.py')
    )
    & $venvPy -m py_compile @compileTargets
    Add-Check 'Python syntax' ($LASTEXITCODE -eq 0) 'canonical Bridge/Jobs/Agent kompilerer'

    Write-Host '[REPAIR] Installerer/reparerer elevated Scheduled Task og starter canonical Raven...'
    & $installer '--no-pause'
    Add-Check 'Autostart installer' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $highest = [string]$task.Principal.RunLevel -eq 'Highest'
    Add-Check 'Scheduled Task RunLevel' $highest ([string]$task.Principal.RunLevel)
    $actionText = (($task.Actions | ForEach-Object { "$( $_.Execute ) $( $_.Arguments )" }) -join ' ')
    $canonicalAction = $actionText -match 'START-RAH-BRIDGE-AUTOSTART\.bat'
    Add-Check 'Scheduled Task action' $canonicalAction $actionText

    $startup = [Environment]::GetFolderPath('Startup')
    $legacyShortcut = Join-Path $startup 'RAH Raven Bridge.lnk'
    Add-Check 'Legacy Startup shortcut' (-not (Test-Path -LiteralPath $legacyShortcut)) 'legacy shortcut er fjernet/ikke til stede'

    $h = Invoke-JsonGet $bridgeHealthUrl 6
    Add-Check 'Bridge /health' ($h.job_executor -eq $true) 'job_executor=true'
    Add-Check 'Bridge executor ready' ($h.job_executor_ready -eq $true) 'job_executor_ready=true'
    Add-Check 'Bridge executor elevated' ($h.job_executor_elevated -eq $true) 'job_executor_elevated=true'

    $jh = Invoke-JsonGet $jobHealthUrl 6
    Add-Check 'Jobs /health ready' ($jh.ready -eq $true) "ready=$($jh.ready)"
    Add-Check 'Jobs /health elevated' ($jh.elevated -eq $true) "elevated=$($jh.elevated)"
    Add-Check 'Jobs safe mode' (($jh.arbitrary_commands -eq $false) -and ($jh.arguments_allowed -eq $false)) 'arbitrary_commands=false, arguments_allowed=false'

    $requestId = "hovedpc-final-$timestamp"
    $payload = @{
        capability = 'system-inventory'
        confirm = $true
        client_request_id = $requestId
    } | ConvertTo-Json -Compress
    Write-Host '[TEST] Sender allowlisted system-inventory jobb...'
    $submitted = Invoke-RestMethod -Method Post -Uri $jobsUrl -ContentType 'application/json' -Body $payload -TimeoutSec 8
    Add-Check 'Job accepted' (($submitted.ok -eq $true) -and ($submitted.accepted -eq $true)) "id=$($submitted.job.id)"
    $jobId = [string]$submitted.job.id
    if([string]::IsNullOrWhiteSpace($jobId)){ throw 'Job Executor returnerte ingen job-id.' }

    for($i=0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 500
        $poll = Invoke-JsonGet "$jobsUrl/$jobId" 6
        if($poll.job.status -in @('succeeded','failed')) { $jobResult = $poll.job; break }
    }
    if($null -eq $jobResult){ throw 'system-inventory nådde ikke sluttstatus innen tidsgrensen.' }
    Add-Check 'system-inventory status' ($jobResult.status -eq 'succeeded') "status=$($jobResult.status)"
    $result = $jobResult.result
    Add-Check 'system-inventory result' ($result.ok -eq $true) 'result.ok=true'
    Add-Check 'Read-only invariant' (($result.read_only -eq $true) -and ($result.files_modified -eq $false) -and ($result.arbitrary_commands -eq $false)) 'read_only=true, files_modified=false, arbitrary_commands=false'

    $audit = Join-Path $jobDir 'jobs.jsonl'
    Add-Check 'Job audit log' (Test-Path -LiteralPath $audit) $audit

    $final = 'PASS'
    Write-Host ''
    Write-Host '===================================================================='
    Write-Host ' RAH RAVEN HOVED-PC FINAL/STABLE: PASS'
    Write-Host ' Bridge 18765 + elevated Job Executor + system-inventory er verifisert.'
    Write-Host '===================================================================='
}
catch {
    $errorText = $_.Exception.Message
    Write-Host ''
    Write-Host '===================================================================='
    Write-Host ' RAH RAVEN HOVED-PC FINAL/STABLE: FAIL'
    Write-Host " $errorText"
    Write-Host ' Se logg og LATEST JSON under C:\RAH\Logs.'
    Write-Host '===================================================================='
}
finally {
    $report = [ordered]@{
        schema = 'rah-raven-hovedpc-final-v1'
        generated_at = (Get-Date).ToString('o')
        computer = $env:COMPUTERNAME
        result = $final
        error = $errorText
        bridge = $bridgeHealthUrl
        job_health = $jobHealthUrl
        scheduled_task = $taskName
        checks = @($script:Checks)
        system_inventory_job = $jobResult
        transcript = $transcript
    }
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $latestJson -Encoding UTF8
    Stop-Transcript | Out-Null
}

if($final -eq 'PASS'){ exit 0 }
exit 1

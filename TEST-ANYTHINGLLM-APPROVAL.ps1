param(
    [string]$BridgeUrl = 'http://127.0.0.1:18765',
    [int]$TimeoutSeconds = 45,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RahAnythingApprovalTestVersion = '0.1.0'

function Test-RahLoopbackUrl {
    param([string]$Url)
    try {
        $u = [Uri]$Url
        if ($u.Scheme -notin @('http','https')) { return $false }
        if ($u.Host -notin @('127.0.0.1','localhost','::1')) { return $false }
        return [string]::IsNullOrWhiteSpace($u.UserInfo)
    } catch {
        return $false
    }
}

function Join-RahUrl {
    param([string]$Base,[string]$Path)
    return $Base.TrimEnd('/') + $Path
}

function Invoke-RahJson {
    param(
        [ValidateSet('GET','POST')][string]$Method,
        [string]$Url,
        [object]$Body = $null,
        [int]$Timeout = 10
    )
    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Url -TimeoutSec $Timeout -ErrorAction Stop
        }
        return Invoke-RestMethod -Method $Method -Uri $Url -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 8) -TimeoutSec $Timeout -ErrorAction Stop
    } catch {
        $detail = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $detail += ' | ' + $_.ErrorDetails.Message
        }
        throw "HTTP/API feil mot $Url : $detail"
    }
}

function Write-RahReport {
    param([object]$Doc)
    $root = 'C:\RAH\AI-Fabric'
    try {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $path = Join-Path $root 'anythingllm-approval-test.json'
        [IO.File]::WriteAllText(
            $path,
            ($Doc | ConvertTo-Json -Depth 10),
            [Text.UTF8Encoding]::new($false)
        )
        return $path
    } catch {
        $path = Join-Path $env:TEMP 'rah-anythingllm-approval-test.json'
        [IO.File]::WriteAllText(
            $path,
            ($Doc | ConvertTo-Json -Depth 10),
            [Text.UTF8Encoding]::new($false)
        )
        return $path
    }
}

if ($SelfTest) {
    if (-not (Test-RahLoopbackUrl 'http://127.0.0.1:18765')) { throw 'Loopback self-test failed.' }
    if (-not (Test-RahLoopbackUrl 'http://localhost:18765')) { throw 'Localhost self-test failed.' }
    if (Test-RahLoopbackUrl 'http://192.168.1.10:18765') { throw 'LAN URL self-test failed.' }
    if (Test-RahLoopbackUrl 'https://example.com') { throw 'Public URL self-test failed.' }
    if ($script:RahAnythingApprovalTestVersion -ne '0.1.0') { throw 'Version self-test failed.' }
    Write-Host 'PASS: AnythingLLM approval launcher self-test' -ForegroundColor Green
    exit 0
}

if (-not (Test-RahLoopbackUrl $BridgeUrl)) {
    throw 'BridgeUrl must be localhost/loopback.'
}
if ($TimeoutSeconds -lt 15 -or $TimeoutSeconds -gt 180) {
    throw 'TimeoutSeconds must be between 15 and 180.'
}

$started = Get-Date
$status = Invoke-RahJson GET (Join-RahUrl $BridgeUrl '/agent/approval/status') -Timeout 8
if (-not $status.ok) {
    throw ('Approval gate status failed: ' + [string]$status.error)
}
if (-not $status.configured) {
    Write-Host 'RAH AnythingLLM approval: NOT CONFIGURED' -ForegroundColor Yellow
    Write-Host 'Kjor C:\RAH\CONFIGURE-RAH-PROJECT-MEMORY.cmd en gang.' -ForegroundColor Yellow
    exit 10
}

$jobs = Invoke-RahJson GET (Join-RahUrl $BridgeUrl '/agent/jobs/health') -Timeout 8
if (-not $jobs.ready) {
    throw 'Raven Job Executor is not ready/elevated.'
}

$requestId = 'anythingllm-approval-' + [guid]::NewGuid().ToString('N').Substring(0,12)
$submit = Invoke-RahJson POST (Join-RahUrl $BridgeUrl '/agent/jobs/auto') @{
    capability = 'system-inventory'
    client_request_id = $requestId
    purpose = 'RAH no-keyboard approval acceptance test.'
} -Timeout 35

if (-not $submit.accepted -or [string]$submit.decision -ne 'APPROVE') {
    throw ('AnythingLLM did not approve the fixed read-only inventory job. Decision=' + [string]$submit.decision)
}

$jobId = [string]$submit.job.id
if (-not $jobId) { throw 'Auto job did not return a job id.' }

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$final = $null
do {
    Start-Sleep -Milliseconds 300
    $snapshot = Invoke-RahJson GET (Join-RahUrl $BridgeUrl ('/agent/jobs/' + $jobId)) -Timeout 8
    $final = $snapshot.job
    if ([string]$final.status -in @('succeeded','failed')) { break }
} while ((Get-Date) -lt $deadline)

if (-not $final) { throw 'No job result returned.' }
if ([string]$final.status -ne 'succeeded') {
    throw ('Auto job failed or timed out. Status=' + [string]$final.status)
}

$result = $final.result
if ($result.ok -ne $true) { throw 'Inventory result ok=false.' }
if ($result.read_only -ne $true) { throw 'Safety check failed: read_only is not true.' }
if ($result.files_modified -ne $false) { throw 'Safety check failed: files_modified is not false.' }
if ($result.arbitrary_commands -ne $false) { throw 'Safety check failed: arbitrary_commands is not false.' }
if ([string]$result.execution_mode -ne 'queued-after-anythingllm-approval') {
    throw ('Unexpected execution mode: ' + [string]$result.execution_mode)
}
if ([string]$result.approval_source -ne 'anythingllm') {
    throw ('Unexpected approval source: ' + [string]$result.approval_source)
}

$report = [ordered]@{
    schema = 'rah-anythingllm-approval-test'
    version = 1
    testVersion = $script:RahAnythingApprovalTestVersion
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    bridge = $BridgeUrl
    anythingllmConfigured = $true
    credentialSource = [string]$status.credential_source
    workspace = [string]$status.workspace
    approvalDecision = [string]$submit.decision
    capability = 'system-inventory'
    jobId = $jobId
    jobStatus = [string]$final.status
    executionMode = [string]$result.execution_mode
    approvalSource = [string]$result.approval_source
    readOnly = [bool]$result.read_only
    filesModified = [bool]$result.files_modified
    arbitraryCommands = [bool]$result.arbitrary_commands
    durationSeconds = [math]::Round(((Get-Date) - $started).TotalSeconds,2)
    overall = 'PASS'
    secretIncluded = $false
}

$reportPath = Write-RahReport ([pscustomobject]$report)

Write-Host ''
Write-Host '============================================================' -ForegroundColor Yellow
Write-Host ' RAH ANYTHINGLLM APPROVAL: FULL PASS' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Yellow
Write-Host ('Decision       : ' + $report.approvalDecision)
Write-Host ('Job            : ' + $report.jobId)
Write-Host ('Status         : ' + $report.jobStatus)
Write-Host ('Execution mode : ' + $report.executionMode)
Write-Host ('Approval       : ' + $report.approvalSource)
Write-Host ('Read-only      : ' + $report.readOnly)
Write-Host ('Report         : ' + $reportPath)
Write-Host '============================================================' -ForegroundColor Yellow
exit 0

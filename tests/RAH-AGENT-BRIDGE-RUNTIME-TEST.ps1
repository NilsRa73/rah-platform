Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$server = Join-Path $repo 'rah_agent_bridge.py'
$client = Join-Path $repo 'RAH-AGENT-BUS.ps1'
$installer = Join-Path $repo 'INSTALL-RAH-AGENT-BRIDGE.ps1'
$root = Join-Path $env:RUNNER_TEMP ('rah-agent-bridge-root-' + [guid]::NewGuid().ToString('N'))
$bus = Join-Path $env:RUNNER_TEMP ('rah-agent-bus-' + [guid]::NewGuid().ToString('N'))
$port = 18791
$proc = $null

try {
    $python = (Get-Command python.exe -ErrorAction Stop).Source

    foreach ($p in @($client,$installer)) {
        $tokens=$null
        $errors=$null
        [Management.Automation.Language.Parser]::ParseFile($p,[ref]$tokens,[ref]$errors) | Out-Null
        if (@($errors).Count) { throw "Parse failed: $p : $($errors[0].Message)" }
    }

    & $python -m py_compile $server
    if ($LASTEXITCODE -ne 0) { throw 'py_compile failed.' }

    & $python $server --self-test
    if ($LASTEXITCODE -ne 0) { throw 'Python self-test failed.' }

    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $client -SelfTest
    if ($LASTEXITCODE -ne 0) { throw 'Client self-test failed.' }

    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $installer -SelfTest -SourceDirectory $repo
    if ($LASTEXITCODE -ne 0) { throw 'Installer self-test failed.' }

    New-Item -ItemType Directory -Path $root,$bus -Force | Out-Null
    $proc = Start-Process -FilePath $python -ArgumentList @(
        $server,'--root',$root,'--bus-root',$bus,'--host','127.0.0.1','--port',[string]$port
    ) -PassThru -WindowStyle Hidden

    $health=$null
    for($i=0;$i -lt 30;$i++){
        Start-Sleep -Milliseconds 200
        try {
            $health=Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -TimeoutSec 2
            if($health.ok){ break }
        } catch {}
    }
    if(-not $health -or -not $health.ok){ throw 'Health failed.' }
    if([string]$health.bind -ne '127.0.0.1'){ throw 'Bridge did not bind to loopback.' }
    if($health.execCapability -ne $false){ throw 'Bridge unexpectedly exposes exec capability.' }

    $token=(Get-Content -LiteralPath (Join-Path $root 'token.txt') -Raw).Trim()
    if($token.Length -lt 24){ throw 'Token missing/invalid.' }
    $headers=@{Authorization="Bearer $token"}

    $enqueue=@{kind='text.task';source='ci';payload=@{text='hello'}} | ConvertTo-Json -Depth 6
    $q=Invoke-RestMethod -Uri "http://127.0.0.1:$port/v1/jobs/enqueue" -Method Post -Headers $headers -ContentType 'application/json' -Body $enqueue
    if(-not $q.ok -or $q.job.status -ne 'queued'){ throw 'Enqueue failed.' }
    $jobId=[string]$q.job.id

    $claim=@{worker='ci-worker'} | ConvertTo-Json
    $c=Invoke-RestMethod -Uri "http://127.0.0.1:$port/v1/jobs/claim" -Method Post -Headers $headers -ContentType 'application/json' -Body $claim
    if(-not $c.ok -or $c.job.id -ne $jobId -or $c.job.status -ne 'running'){ throw 'Claim failed.' }

    $complete=@{worker='ci-worker';result=@{answer='ok'}} | ConvertTo-Json -Depth 6
    $done=Invoke-RestMethod -Uri "http://127.0.0.1:$port/v1/jobs/$jobId/complete" -Method Post -Headers $headers -ContentType 'application/json' -Body $complete
    if(-not $done.ok -or $done.job.status -ne 'completed'){ throw 'Complete failed.' }

    $status=Invoke-RestMethod -Uri "http://127.0.0.1:$port/v1/jobs/status" -Headers $headers -TimeoutSec 5
    if([int]$status.counts.completed -ne 1 -or [int]$status.counts.queued -ne 0){ throw 'Status counts mismatch.' }

    if(-not (Test-Path -LiteralPath (Join-Path $bus "results\$jobId.json") -PathType Leaf)){ throw 'Result file missing.' }
    Write-Host 'PASS: RAH Agent Bridge v1 Windows runtime' -ForegroundColor Green
}
finally {
    if($proc -and -not $proc.HasExited){ Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $root,$bus -Recurse -Force -ErrorAction SilentlyContinue
}

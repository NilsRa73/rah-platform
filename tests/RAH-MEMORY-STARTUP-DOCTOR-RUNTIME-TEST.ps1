Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$doctor = Join-Path $repo 'RAH-MEMORY-STARTUP-DOCTOR.ps1'
$root = Join-Path $env:RUNNER_TEMP ('rah-memory-doctor-' + [guid]::NewGuid().ToString('N'))

try {
    $tokens=$null
    $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($doctor,[ref]$tokens,[ref]$errors) | Out-Null
    if(@($errors).Count){ throw "Parse failed: $($errors[0].Message)" }

    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $doctor -Mode SelfTest -Root $root
    if($LASTEXITCODE -ne 0){ throw "SelfTest failed: $LASTEXITCODE" }

    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $doctor -Mode Audit -Root $root -NoOpenReport
    if($LASTEXITCODE -ne 0){ throw "Audit failed: $LASTEXITCODE" }

    $latestPath = Join-Path $root 'reports\latest.json'
    if(-not (Test-Path -LiteralPath $latestPath -PathType Leaf)){ throw 'latest.json missing.' }
    $latest = Get-Content -LiteralPath $latestPath -Raw | ConvertFrom-Json
    foreach($p in @([string]$latest.json,[string]$latest.html,[string]$latest.txt)){
        if(-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)){ throw "Report output missing: $p" }
    }
    $doc = Get-Content -LiteralPath ([string]$latest.json) -Raw | ConvertFrom-Json
    if($doc.schema -ne 'rah-memory-startup-doctor' -or [int]$doc.version -ne 1){ throw 'Report schema/version mismatch.' }
    if([string]$doc.doctorVersion -ne '1.0.0'){ throw 'Doctor version mismatch.' }
    if(-not $doc.memory){ throw 'Memory snapshot missing.' }
    if($null -eq $doc.processes){ throw 'Process inventory missing.' }
    if($null -eq $doc.startup){ throw 'Startup inventory missing.' }

    if(Test-Path -LiteralPath (Join-Path $root 'DisabledStartup')){ throw 'Audit unexpectedly created DisabledStartup.' }
    if(Test-Path -LiteralPath (Join-Path $root 'Backups')){ throw 'Audit unexpectedly created startup backups.' }

    $html = Get-Content -LiteralPath ([string]$latest.html) -Raw
    if($html -notmatch 'RAH Memory & Startup Doctor v1'){ throw 'HTML title missing.' }
    if($html -notmatch 'REVIEW'){ throw 'HTML classification legend missing.' }

    Write-Host 'PASS: RAH Memory & Startup Doctor v1 Windows audit runtime' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

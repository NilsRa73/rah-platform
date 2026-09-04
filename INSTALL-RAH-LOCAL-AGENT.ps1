$ErrorActionPreference = 'Stop'

$RepoRaw = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$Root = Join-Path $env:LOCALAPPDATA 'RAH\LocalAgent'
$Agent = Join-Path $Root 'rah_local_agent.py'
$Client = Join-Path $Root 'rah_agent_client.py'
$Task = 'RAH Local Agent'

Write-Host '============================================================' -ForegroundColor DarkYellow
Write-Host ' RAH LOCAL AGENT - INSTALL / UPDATE' -ForegroundColor Yellow
Write-Host '============================================================' -ForegroundColor DarkYellow

New-Item -ItemType Directory -Force -Path $Root | Out-Null

$Python = $null
foreach ($candidate in @('py.exe','python.exe')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $Python = $cmd.Source; break }
}
if (-not $Python) { throw 'Python 3 was not found. Install Python 3, then run this installer again.' }

Write-Host '[1/6] Downloading RAH Local Agent...' -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing "$RepoRaw/rah_local_agent.py" -OutFile $Agent
Invoke-WebRequest -UseBasicParsing "$RepoRaw/rah_agent_client.py" -OutFile $Client

Write-Host '[2/6] Syntax check...' -ForegroundColor Cyan
& $Python -m py_compile $Agent $Client
if ($LASTEXITCODE -ne 0) { throw 'Python syntax check failed.' }

Write-Host '[3/6] Creating visible scheduled task...' -ForegroundColor Cyan
$Arg = '"' + $Agent + '"'
$Action = New-ScheduledTaskAction -Execute $Python -Argument $Arg
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$Principal = New-ScheduledTaskPrincipal -UserId $Identity -LogonType Interactive -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 3650) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $Task -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null

Write-Host '[4/6] Starting agent...' -ForegroundColor Cyan
try { Stop-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue } catch {}
Start-ScheduledTask -TaskName $Task
Start-Sleep -Seconds 2

Write-Host '[5/6] Health check...' -ForegroundColor Cyan
$Health = $null
try { $Health = Invoke-RestMethod 'http://127.0.0.1:18779/health' -TimeoutSec 5 } catch {}
if (-not $Health.ok) {
    Write-Host 'Scheduled-task launch did not answer yet; starting one visible test instance.' -ForegroundColor DarkYellow
    Start-Process -FilePath $Python -ArgumentList $Arg -WorkingDirectory $Root
    Start-Sleep -Seconds 2
    $Health = Invoke-RestMethod 'http://127.0.0.1:18779/health' -TimeoutSec 5
}
if (-not $Health.ok) { throw 'RAH Local Agent health check failed.' }

Write-Host '[6/6] CPU self-test through the agent...' -ForegroundColor Cyan
$Token = (Get-Content (Join-Path $Root 'token.txt') -Raw).Trim()
$Headers = @{ Authorization = "Bearer $Token" }
$Body = @{ tool='system.cpu'; args=@{} } | ConvertTo-Json -Depth 5
$CpuResult = Invoke-RestMethod 'http://127.0.0.1:18779/v1/tool' -Method Post -Headers $Headers -ContentType 'application/json' -Body $Body -TimeoutSec 15

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' RAH LOCAL AGENT : READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' Local endpoint : http://127.0.0.1:18779' -ForegroundColor Yellow
Write-Host ' Autostart      : RAH Local Agent' -ForegroundColor Yellow
Write-Host ' Filesystem     : read/write under this Windows account' -ForegroundColor Yellow
Write-Host ' Admin mode     : highest privileges for this account' -ForegroundColor Yellow
Write-Host ''
Write-Host 'CPU returned by RAH Agent:' -ForegroundColor Cyan
$CpuResult.result | Format-List
Write-Host ''
Write-Host 'Raven/RAH software can now call the local tool bus instead of asking for copy/paste system information.' -ForegroundColor Green

$ErrorActionPreference = 'Stop'

$RepoRaw = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$Root = Join-Path $env:LOCALAPPDATA 'RAH\LocalAgent'
$Agent = Join-Path $Root 'rah_local_agent.py'
$Client = Join-Path $Root 'rah_agent_client.py'
$AIBridge = Join-Path $Root 'rah_ai_tool_bridge.py'
$UserTemplate = Join-Path $Root 'RAH-CHATGPT-BRIDGE.template.user.js'
$UserScript = Join-Path $Root 'RAH-CHATGPT-BRIDGE.user.js'
$BridgeServer = Join-Path $Root 'rah_bridge_install_server.py'
$Task = 'RAH Local Agent'

Write-Host '============================================================' -ForegroundColor DarkYellow
Write-Host ' RAH LOCAL AGENT + AI BRIDGE - INSTALL / UPDATE' -ForegroundColor Yellow
Write-Host '============================================================' -ForegroundColor DarkYellow

New-Item -ItemType Directory -Force -Path $Root | Out-Null

$Python = $null
foreach ($candidate in @('py.exe','python.exe')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $Python = $cmd.Source; break }
}
if (-not $Python) { throw 'Python 3 was not found. Install Python 3, then run this installer again.' }

Write-Host '[1/8] Downloading RAH Agent + AI bridge...' -ForegroundColor Cyan
Invoke-WebRequest -UseBasicParsing "$RepoRaw/rah_local_agent.py" -OutFile $Agent
Invoke-WebRequest -UseBasicParsing "$RepoRaw/rah_agent_client.py" -OutFile $Client
Invoke-WebRequest -UseBasicParsing "$RepoRaw/rah_ai_tool_bridge.py" -OutFile $AIBridge
Invoke-WebRequest -UseBasicParsing "$RepoRaw/RAH-CHATGPT-BRIDGE.user.js" -OutFile $UserTemplate

# Python 3.12+ warns about the Windows path written literally in the module docstring.
# Escape only that documentation example; runtime paths are unchanged.
$AgentText = Get-Content -LiteralPath $Agent -Raw
$AgentText = $AgentText.Replace('%LOCALAPPDATA%\RAH\LocalAgent\token.txt.', '%LOCALAPPDATA%\\RAH\\LocalAgent\\token.txt.')
Set-Content -LiteralPath $Agent -Value $AgentText -Encoding UTF8

Write-Host '[2/8] Syntax check...' -ForegroundColor Cyan
& $Python -m py_compile $Agent $Client $AIBridge
if ($LASTEXITCODE -ne 0) { throw 'Python syntax check failed.' }

Write-Host '[3/8] Creating scheduled agent task...' -ForegroundColor Cyan
$Arg = '"' + $Agent + '"'
$Action = New-ScheduledTaskAction -Execute $Python -Argument $Arg
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$Principal = New-ScheduledTaskPrincipal -UserId $Identity -LogonType Interactive -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 3650) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $Task -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null

Write-Host '[4/8] Starting agent...' -ForegroundColor Cyan
try { Stop-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue } catch {}
Start-ScheduledTask -TaskName $Task
Start-Sleep -Seconds 2

Write-Host '[5/8] Health check...' -ForegroundColor Cyan
$Health = $null
try { $Health = Invoke-RestMethod 'http://127.0.0.1:18779/health' -TimeoutSec 5 } catch {}
if (-not $Health.ok) {
    Write-Host 'Scheduled-task launch did not answer yet; starting one visible test instance.' -ForegroundColor DarkYellow
    Start-Process -FilePath $Python -ArgumentList $Arg -WorkingDirectory $Root
    Start-Sleep -Seconds 2
    $Health = Invoke-RestMethod 'http://127.0.0.1:18779/health' -TimeoutSec 5
}
if (-not $Health.ok) { throw 'RAH Local Agent health check failed.' }

Write-Host '[6/8] CPU self-test through the agent...' -ForegroundColor Cyan
$Token = (Get-Content (Join-Path $Root 'token.txt') -Raw).Trim()
$Headers = @{ Authorization = "Bearer $Token" }
$Body = @{ tool='system.cpu'; args=@{} } | ConvertTo-Json -Depth 5
$CpuResult = Invoke-RestMethod 'http://127.0.0.1:18779/v1/tool' -Method Post -Headers $Headers -ContentType 'application/json' -Body $Body -TimeoutSec 15

Write-Host '[7/8] Preparing personalized ChatGPT bridge...' -ForegroundColor Cyan
$Template = Get-Content $UserTemplate -Raw
$Personal = $Template.Replace('__RAH_TOKEN__', $Token)
Set-Content -LiteralPath $UserScript -Value $Personal -Encoding UTF8
$Desktop = [Environment]::GetFolderPath('Desktop')
$DesktopBridge = Join-Path $Desktop 'RAH-CHATGPT-BRIDGE.user.js'
Copy-Item -LiteralPath $UserScript -Destination $DesktopBridge -Force

Write-Host '[8/8] Opening bridge installer in browser...' -ForegroundColor Cyan
$ServerCode = @'
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys, threading, urllib.parse

script = Path(sys.argv[1]).read_bytes()

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        return
    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path != '/RAH-CHATGPT-BRIDGE.user.js':
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header('Content-Type', 'text/javascript; charset=utf-8')
        self.send_header('Content-Length', str(len(script)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(script)
        threading.Thread(target=self.server.shutdown, daemon=True).start()

server = ThreadingHTTPServer(('127.0.0.1', 18780), Handler)
server.serve_forever(poll_interval=0.1)
server.server_close()
'@
Set-Content -LiteralPath $BridgeServer -Value $ServerCode -Encoding UTF8
$ServerArg = '"' + $BridgeServer + '" "' + $UserScript + '"'
$BridgeProcess = Start-Process -FilePath $Python -ArgumentList $ServerArg -WorkingDirectory $Root -WindowStyle Hidden -PassThru
Start-Sleep -Milliseconds 500
$InstallUrl = 'http://127.0.0.1:18780/RAH-CHATGPT-BRIDGE.user.js'
Start-Process $InstallUrl

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' RAH LOCAL AGENT : READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' Local endpoint : http://127.0.0.1:18779' -ForegroundColor Yellow
Write-Host ' Autostart      : RAH Local Agent' -ForegroundColor Yellow
Write-Host ' Filesystem     : broad read/write under this Windows account' -ForegroundColor Yellow
Write-Host ' AI router      : rah_ai_tool_bridge.py' -ForegroundColor Yellow
Write-Host ' ChatGPT bridge : ' $DesktopBridge -ForegroundColor Yellow
Write-Host ''
Write-Host 'CPU returned by RAH Agent:' -ForegroundColor Cyan
$CpuResult.result | Format-List
Write-Host ''
Write-Host 'Tampermonkey should now show the RAH ChatGPT Local Agent Bridge install page.' -ForegroundColor Green
Write-Host 'Choose Install once, then return to the same ChatGPT conversation.' -ForegroundColor Green
Write-Host 'The temporary localhost installer stops itself after the userscript is fetched.' -ForegroundColor DarkGray

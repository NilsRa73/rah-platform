param(
    [Parameter(Mandatory=$true)][string]$ResultPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logDir = 'C:\RAH\Logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir 'RAH-QUIET-POPUPS.log'
$lines = New-Object System.Collections.Generic.List[string]
$fixed = 0
$already = 0
$skipped = 0
$warnings = 0

function Add-Line([string]$Text) {
    $lines.Add($Text)
    Add-Content -LiteralPath $logPath -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Text)
}

function Quote-PsLiteral([string]$Value) {
    if ($null -eq $Value) { return "''" }
    return "'" + $Value.Replace("'", "''") + "'"
}

function Protect-RahTask($Task) {
    $actions = @($Task.Actions)
    if ($actions.Count -ne 1) {
        Add-Line ("SKIP  {0}{1} - flere enn en action" -f $Task.TaskPath,$Task.TaskName)
        $script:skipped++
        return
    }

    $action = $actions[0]
    $exe = [Environment]::ExpandEnvironmentVariables([string]$action.Execute)
    $args = [string]$action.Arguments
    $wd = [Environment]::ExpandEnvironmentVariables([string]$action.WorkingDirectory)
    $leaf = [IO.Path]::GetFileName($exe).ToLowerInvariant()

    if ($leaf -notin @('cmd.exe','powershell.exe','pwsh.exe')) {
        return
    }

    if (($leaf -in @('powershell.exe','pwsh.exe')) -and $args -match '(?i)-WindowStyle\s+Hidden' -and $args -match '(?i)-EncodedCommand') {
        Add-Line ("OK    {0}{1} - allerede skjult" -f $Task.TaskPath,$Task.TaskName)
        $script:already++
        return
    }

    $runner = New-Object System.Collections.Generic.List[string]
    $runner.Add('$ErrorActionPreference = ''Stop''')
    $runner.Add('$psi = New-Object System.Diagnostics.ProcessStartInfo')
    $runner.Add('$psi.FileName = ' + (Quote-PsLiteral $exe))
    $runner.Add('$psi.Arguments = ' + (Quote-PsLiteral $args))
    $runner.Add('$psi.UseShellExecute = $false')
    $runner.Add('$psi.CreateNoWindow = $true')
    $runner.Add('$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden')
    if ($wd) { $runner.Add('$psi.WorkingDirectory = ' + (Quote-PsLiteral $wd)) }
    $runner.Add('$p = [System.Diagnostics.Process]::Start($psi)')
    $runner.Add('$p.WaitForExit()')
    $runner.Add('exit $p.ExitCode')
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(($runner -join [Environment]::NewLine)))
    $hiddenArgs = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand ' + $encoded
    $hostExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($wd) {
        $newAction = New-ScheduledTaskAction -Execute $hostExe -Argument $hiddenArgs -WorkingDirectory $wd
    } else {
        $newAction = New-ScheduledTaskAction -Execute $hostExe -Argument $hiddenArgs
    }

    $wasRunning = ([string]$Task.State -eq 'Running')
    if ($wasRunning) {
        try { Stop-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction Stop } catch {}
        Start-Sleep -Milliseconds 300
    }

    Set-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -Action $newAction | Out-Null
    if ($wasRunning) {
        Start-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath
    }

    Add-Line ("FIXED {0}{1} - consoleaction pakket inn som CreateNoWindow + Hidden" -f $Task.TaskPath,$Task.TaskName)
    $script:fixed++
}

Add-Line '--- RAH Quiet Popups repair started ---'

$tasks = @(Get-ScheduledTask | Where-Object {
    $taskText = ([string]$_.TaskPath + [string]$_.TaskName)
    $actionText = (@($_.Actions) | ForEach-Object { ([string]$_.Execute + ' ' + [string]$_.Arguments) }) -join ' '
    $taskText -match '(?i)RAH|Raven' -or $actionText -match '(?i)RAH|Raven'
})

foreach ($task in $tasks) {
    try { Protect-RahTask $task }
    catch {
        Add-Line ("WARN  {0}{1} - {2}" -f $task.TaskPath,$task.TaskName,$_.Exception.Message)
        $warnings++
    }
}

try {
    $startup = [Environment]::GetFolderPath('Startup')
    $legacy = Join-Path $startup 'RAH Raven Bridge.lnk'
    if (Test-Path -LiteralPath $legacy) {
        $backup = 'C:\RAH\Backups\QuietPopups'
        New-Item -ItemType Directory -Force -Path $backup | Out-Null
        Move-Item -LiteralPath $legacy -Destination (Join-Path $backup ('RAH Raven Bridge.' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.lnk')) -Force
        Add-Line 'FIXED legacy Startup shortcut RAH Raven Bridge.lnk moved to backup.'
        $fixed++
    }
} catch {
    Add-Line ('WARN  legacy Startup shortcut: ' + $_.Exception.Message)
    $warnings++
}

$runKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
)
foreach ($key in $runKeys) {
    try {
        if (Test-Path $key) {
            $props = Get-ItemProperty -Path $key
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -match '^PS' -or $p.Name -eq 'RunspaceId') { continue }
                $value = [string]$p.Value
                if (($p.Name + ' ' + $value) -match '(?i)RAH|Raven' -and $value -match '(?i)powershell|pwsh|cmd\.exe') {
                    Add-Line ("REVIEW Run-key {0} :: {1} = {2}" -f $key,$p.Name,$value)
                    $warnings++
                }
            }
        }
    } catch {}
}

Add-Line ("SUMMARY fixed={0} already_hidden={1} skipped={2} warnings={3}" -f $fixed,$already,$skipped,$warnings)

if ($warnings -gt 0 -or $skipped -gt 0) {
    Add-Line 'FINAL: PENDING'
    $exitCode = 2
} else {
    Add-Line 'FINAL: PASS'
    $exitCode = 0
}

$lines | Set-Content -LiteralPath $ResultPath -Encoding UTF8
exit $exitCode

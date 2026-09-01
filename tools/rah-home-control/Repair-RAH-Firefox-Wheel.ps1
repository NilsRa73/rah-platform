[CmdletBinding()]
param(
    [switch]$Elevated
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Branch = 'codex/rah-home-control-powershell'
$BaseUrl = "https://raw.githubusercontent.com/NilsRa73/rah-platform/$Branch/tools/rah-home-control"
$WheelVersion = '3.7.2'
$WheelFileName = 'RAH_Raven_Command_Wheel_COPY_PASTE_v3.6.user.js'
$WheelSha256 = '90DD2709EC3675F27DF458B18BF433E50176C4B538DAFA7AAB1E64AEDA558E15'
$ProvisionFileName = 'RAH-Firefox-Wheel-Provision-v3.7.2.json'
$ProvisionSha256 = '17461FE605E619F1887E7F54C131F7357FD80D53AB1B977862E7B51284D67F4C'
$ProvisionHash = '1:d573fedb999850994bafdd9dd5df8e9d1d28e0d3a15e6946a9799732e4637af4'
$ProvisionUrl = "$BaseUrl/$ProvisionFileName"
$TampermonkeyXpi = 'https://addons.mozilla.org/firefox/downloads/latest/tampermonkey/latest.xpi'
$RahRoot = Join-Path $env:USERPROFILE 'Documents\RAH Room Control'
$ToolRoot = Join-Path $RahRoot 'Tools'
$BackupRoot = Join-Path $RahRoot (
    'Backups\Firefox-Repair-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
)
$LogFile = Join-Path $RahRoot 'RAH-Firefox-Repair.log'

function Write-RahStep {
    param([string]$Message)
    $stamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$stamp] $Message" -ForegroundColor Yellow
    "[$stamp] $Message" | Add-Content -LiteralPath $LogFile -Encoding utf8
}

function Test-RahAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Find-RahPwsh {
    $command = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue
    $paths = @(
        $(if ($command) { $command.Source })
        $(if ($env:ProgramFiles) {
            Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
        })
        $(if ($env:LOCALAPPDATA) {
            Join-Path $env:LOCALAPPDATA 'Microsoft\PowerShell\7\pwsh.exe'
        })
    ) | Where-Object {
        $_ -and (Test-Path -LiteralPath $_ -PathType Leaf)
    } | Select-Object -Unique
    return $paths | Select-Object -First 1
}

function Find-RahFirefox {
    $command = Get-Command 'firefox.exe' -ErrorAction SilentlyContinue
    $paths = @(
        $(if ($command) { $command.Source })
        $(if ($env:ProgramFiles) {
            Join-Path $env:ProgramFiles 'Mozilla Firefox\firefox.exe'
        })
        $(if (${env:ProgramFiles(x86)}) {
            Join-Path ${env:ProgramFiles(x86)} 'Mozilla Firefox\firefox.exe'
        })
        $(if ($env:LOCALAPPDATA) {
            Join-Path $env:LOCALAPPDATA 'Mozilla Firefox\firefox.exe'
        })
    ) | Where-Object {
        $_ -and (Test-Path -LiteralPath $_ -PathType Leaf)
    } | Select-Object -Unique
    return $paths | Select-Object -First 1
}

function Install-RahFirefox {
    $firefox = Find-RahFirefox
    if ($firefox) {
        return $firefox
    }

    Write-RahStep 'Firefox mangler. Installerer offisiell Mozilla Firefox ...'
    $winget = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
    if ($winget) {
        & $winget.Source install --id Mozilla.Firefox --exact --silent `
            --accept-package-agreements --accept-source-agreements `
            --disable-interactivity
    }

    $firefox = Find-RahFirefox
    if (-not $firefox) {
        $installer = Join-Path $env:TEMP 'RAH-Firefox-Setup.exe'
        $installerUrl = 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=nb-NO'
        Invoke-WebRequest -Uri $installerUrl -OutFile $installer `
            -UseBasicParsing
        Start-Process -FilePath $installer -ArgumentList '/S' -Wait
        Remove-Item -LiteralPath $installer -Force `
            -ErrorAction SilentlyContinue
        $firefox = Find-RahFirefox
    }

    if (-not $firefox) {
        throw 'Firefox kunne ikke installeres automatisk.'
    }
    return $firefox
}

function Get-RahPolicyMap {
    param(
        [System.Collections.IDictionary]$Parent,
        [string]$Key
    )
    if (
        -not $Parent.Contains($Key) -or
        -not ($Parent[$Key] -is [System.Collections.IDictionary])
    ) {
        $Parent[$Key] = @{}
    }
    return $Parent[$Key]
}

function Test-RahTampermonkeyActive {
    $profilesRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
    if (-not (Test-Path -LiteralPath $profilesRoot -PathType Container)) {
        return $false
    }

    foreach (
        $profile in Get-ChildItem -LiteralPath $profilesRoot -Directory `
            -ErrorAction SilentlyContinue
    ) {
        $extensionsFile = Join-Path $profile.FullName 'extensions.json'
        if (-not (Test-Path -LiteralPath $extensionsFile -PathType Leaf)) {
            continue
        }
        try {
            $extensions = Get-Content -LiteralPath $extensionsFile -Raw |
                ConvertFrom-Json
            $found = @($extensions.addons) | Where-Object {
                $_.active -eq $true -and
                $_.id -eq 'firefox@tampermonkey.net'
            } | Select-Object -First 1
            if ($found) {
                return $true
            }
        }
        catch { }
    }
    return $false
}

function Install-RahHomeFiles {
    param([string]$TempRoot)

    $files = @(
        'RAH-Control-Center.ps1'
        'RAH-Master-Power.ps1'
        'RAH-Link-Speed.ps1'
        'RAH-Remote-Setup.ps1'
        'RAH-Node-Register.ps1'
        'RAH-Command-Wheel-Home-Control-Addon.user.js'
        $WheelFileName
    )

    New-Item -ItemType Directory -Path $ToolRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

    foreach ($file in $files) {
        Write-RahStep "Henter $file ..."
        $tempFile = Join-Path $TempRoot $file
        Invoke-WebRequest -Uri "$BaseUrl/$file" -OutFile $tempFile `
            -UseBasicParsing
        Unblock-File -LiteralPath $tempFile

        if ($file -eq $WheelFileName) {
            $actualHash = (
                Get-FileHash -LiteralPath $tempFile -Algorithm SHA256
            ).Hash
            if ($actualHash -ne $WheelSha256) {
                throw 'Sikkerhetskontrollen for RAH Wheel v3.7.2 feilet.'
            }
        }

        $destination = Join-Path $ToolRoot $file
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            Copy-Item -LiteralPath $destination `
                -Destination (Join-Path $BackupRoot $file) -Force
        }
        Copy-Item -LiteralPath $tempFile -Destination $destination -Force
    }

    $provisionFile = Join-Path $TempRoot $ProvisionFileName
    Invoke-WebRequest -Uri $ProvisionUrl -OutFile $provisionFile `
        -UseBasicParsing
    $actualProvisionHash = (
        Get-FileHash -LiteralPath $provisionFile -Algorithm SHA256
    ).Hash
    if ($actualProvisionHash -ne $ProvisionSha256) {
        throw 'Sikkerhetskontrollen for Firefox-provisioneringen feilet.'
    }
    Copy-Item -LiteralPath $provisionFile `
        -Destination (Join-Path $RahRoot $ProvisionFileName) -Force
}

function Set-RahProtocol {
    param([string]$Pwsh)

    $launcher = Join-Path $ToolRoot 'RAH-Control-Center.ps1'
    $protocolRoot = 'HKCU:\Software\Classes\rah-control-center'
    New-Item -Path $protocolRoot -Force | Out-Null
    Set-Item -Path $protocolRoot -Value 'URL:RAH Control Center Protocol'
    New-ItemProperty -Path $protocolRoot -Name 'URL Protocol' -Value '' `
        -PropertyType String -Force | Out-Null
    New-Item -Path "$protocolRoot\DefaultIcon" -Force | Out-Null
    Set-Item -Path "$protocolRoot\DefaultIcon" -Value ('"{0}",0' -f $Pwsh)
    New-Item -Path "$protocolRoot\shell\open\command" -Force | Out-Null
    $command = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -ProtocolUri "%1"' -f `
        $Pwsh, $launcher
    Set-Item -Path "$protocolRoot\shell\open\command" -Value $command
}

function Set-RahFirefoxPolicy {
    param([string]$Firefox)

    $distribution = Join-Path (Split-Path -Parent $Firefox) 'distribution'
    $policyFile = Join-Path $distribution 'policies.json'
    New-Item -ItemType Directory -Path $distribution -Force | Out-Null

    $policy = @{}
    if (Test-Path -LiteralPath $policyFile -PathType Leaf) {
        Copy-Item -LiteralPath $policyFile `
            -Destination (Join-Path $BackupRoot 'policies.json') -Force
        try {
            $policy = Get-Content -LiteralPath $policyFile -Raw |
                ConvertFrom-Json -AsHashtable
        }
        catch {
            throw "Eksisterende Firefox-policy var ugyldig og er ikke overskrevet. Sikkerhetskopi: $BackupRoot"
        }
    }

    $policies = Get-RahPolicyMap -Parent $policy -Key 'policies'
    $extensions = Get-RahPolicyMap -Parent $policies -Key 'Extensions'
    $extensionInstalls = @($extensions['Install']) + @($TampermonkeyXpi)
    $extensions['Install'] = @(
        $extensionInstalls | Where-Object { $_ } | Select-Object -Unique
    )

    $thirdParty = Get-RahPolicyMap -Parent $policies -Key '3rdparty'
    $thirdPartyExtensions = Get-RahPolicyMap `
        -Parent $thirdParty -Key 'Extensions'
    $tampermonkey = Get-RahPolicyMap `
        -Parent $thirdPartyExtensions -Key 'firefox@tampermonkey.net'
    $tampermonkey['jsonImport'] = @(
        @{
            hash = $ProvisionHash
            url = $ProvisionUrl
            haltOnError = $false
            installAsSystemScripts = $false
        }
    )

    $autoLaunch = @($policies['AutoLaunchProtocolsFromOrigins']) |
        Where-Object {
            $_ -and $_['protocol'] -ne 'rah-control-center'
        }
    $policies['AutoLaunchProtocolsFromOrigins'] = @(
        $autoLaunch
        @{
            protocol = 'rah-control-center'
            allowed_origins = @(
                'https://chatgpt.com'
                'https://chat.openai.com'
                'https://nilsra73.github.io'
                'https://github.com'
            )
        }
    )

    $policy | ConvertTo-Json -Depth 100 |
        Set-Content -LiteralPath $policyFile -Encoding utf8NoBOM
    Write-RahStep "Firefox-policy lagret: $policyFile"
}

New-Item -ItemType Directory -Path $RahRoot -Force | Out-Null
"RAH Firefox repair started $(Get-Date -Format o)" |
    Set-Content -LiteralPath $LogFile -Encoding utf8

$pwsh = Find-RahPwsh
if (-not $pwsh) {
    throw 'PowerShell 7 (pwsh.exe) ble ikke funnet.'
}

if (-not (Test-RahAdministrator)) {
    Write-Host 'Åpner RAH Firefox Repair som administrator ...' `
        -ForegroundColor Yellow
    Start-Process -FilePath $pwsh -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $PSCommandPath)
        '-Elevated'
    )
    return
}

$tempRoot = Join-Path $env:TEMP (
    'RAH-Firefox-Repair-{0}' -f [guid]::NewGuid()
)

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Write-RahStep 'RAH Firefox Repair starter.'
    Install-RahHomeFiles -TempRoot $tempRoot
    Set-RahProtocol -Pwsh $pwsh
    $firefox = Install-RahFirefox

    $runningFirefox = @(Get-Process 'firefox' -ErrorAction SilentlyContinue)
    if ($runningFirefox.Count -gt 0) {
        Write-RahStep 'Lagrer Firefox-økten og starter nettleseren på nytt ...'
        foreach ($process in $runningFirefox) {
            [void]$process.CloseMainWindow()
        }
        Start-Sleep -Seconds 5
        Get-Process 'firefox' -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    Set-RahFirefoxPolicy -Firefox $firefox
    "managed-policy-ready $(Get-Date -Format o)" |
        Set-Content -LiteralPath (
            Join-Path $RahRoot "RAH-Firefox-Wheel-v$WheelVersion.state"
        ) -Encoding utf8

    $masterPower = Join-Path $ToolRoot 'RAH-Master-Power.ps1'
    Start-Process -FilePath $pwsh -WindowStyle Hidden -ArgumentList @(
        '-NoProfile'
        '-WindowStyle', 'Hidden'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $masterPower)
        '-Quiet'
    )

    Write-RahStep 'Starter Firefox og installerer Tampermonkey + RAH Wheel ...'
    Start-Process -FilePath $firefox -ArgumentList @('-new-window', 'about:blank')

    $tampermonkeyReady = $false
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        Start-Sleep -Seconds 2
        if (Test-RahTampermonkeyActive) {
            $tampermonkeyReady = $true
            break
        }
    }

    if ($tampermonkeyReady) {
        Start-Sleep -Seconds 4
    }

    Start-Process -FilePath $firefox -ArgumentList @(
        '-new-tab'
        'https://chatgpt.com/'
    )

    if ($tampermonkeyReady) {
        Write-RahStep 'Tampermonkey er aktiv. RAH Wheel v3.7.2 er provisionert.'
    }
    else {
        Write-RahStep 'Firefox-policy er aktiv. Første oppstart kan bruke litt ekstra tid.'
    }

    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show(
        "FERDIG`n`nFirefox, Tampermonkey og RAH Command Wheel v3.7.2 er satt opp automatisk.`n`nFirefox er åpnet på ChatGPT. Vent noen sekunder og trykk Ctrl+F5 hvis Wheel ikke vises med en gang.`n`nAlt+H åpner RAH Home Control.",
        'RAH Firefox Repair',
        'OK',
        'Information'
    ) | Out-Null
}
catch {
    $message = $_.Exception.Message
    "ERROR: $message" | Add-Content -LiteralPath $LogFile -Encoding utf8
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [Windows.Forms.MessageBox]::Show(
            "RAH Firefox Repair stoppet trygt.`n`n$message`n`nLogg: $LogFile`n`nEksisterende Wheel- og Firefox-filer er bevart.",
            'RAH Firefox Repair',
            'OK',
            'Error'
        ) | Out-Null
    }
    catch { }
    throw
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force `
            -ErrorAction SilentlyContinue
    }
}

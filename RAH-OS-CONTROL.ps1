Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

$script:Version = '0.2.0-candidate'
$script:RahRoot = 'C:\RAH'
$script:OsRoot = 'C:\RAH\RavenOS'
$script:LogRoot = Join-Path $script:OsRoot 'logs'
$script:LogFile = Join-Path $script:LogRoot 'rah-os.log'
New-Item -ItemType Directory -Force -Path $script:OsRoot,$script:LogRoot | Out-Null

function Write-RahOsLog {
    param([string]$Message)
    $line = ('{0}  {1}' -f (Get-Date).ToString('s'), $Message)
    Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
}

function Find-RahFile {
    param([Parameter(Mandatory=$true)][string]$Name,[string[]]$ExtraRoots=@())
    $roots = @(
        $PSScriptRoot,
        'C:\RAH\rah-platform',
        'C:\RAH\RAH-Platform',
        'C:\RAH\2PCProof'
    ) + $ExtraRoots
    foreach($root in $roots){
        if([string]::IsNullOrWhiteSpace($root)){ continue }
        $p = Join-Path $root $Name
        if(Test-Path -LiteralPath $p -PathType Leaf){ return [IO.Path]::GetFullPath($p) }
    }
    return $null
}

function Test-LocalPort {
    param([int]$Port)
    try {
        $client = New-Object Net.Sockets.TcpClient
        $iar = $client.BeginConnect('127.0.0.1',$Port,$null,$null)
        $ok = $iar.AsyncWaitHandle.WaitOne(350,$false)
        if($ok -and $client.Connected){ $client.EndConnect($iar); $client.Close(); return $true }
        $client.Close()
    } catch {}
    return $false
}

function Get-RahOsStatus {
    $cc = Find-RahFile 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
    $fabric = Find-RahFile 'START-RAH-AI-FABRIC.cmd'
    $grid = Find-RahFile 'START-HER-RAH-2PC-GRID.cmd'
    $verify = Find-RahFile 'VERIFY-RAH-2PC-GRID.cmd'
    $gridInstall = Find-RahFile 'INSTALL-RAH-2PC-GRID.cmd'
    $selfTest = Find-RahFile 'RAH-OS-SELFTEST.ps1'
    $repair = Find-RahFile 'REPAIR-RAH-OS.cmd'
    [pscustomobject][ordered]@{
        Version = $script:Version
        Computer = $env:COMPUTERNAME
        RavenCore18765 = Test-LocalPort 18765
        NodeAgent18766 = Test-LocalPort 18766
        CommandCenter = $cc
        AiFabric = $fabric
        Grid = $grid
        GridVerify = $verify
        GridInstaller = $gridInstall
        SelfTest = $selfTest
        RepairLauncher = $repair
        HardwareRegistry = Test-Path -LiteralPath 'C:\RAH\HardwareRegistry\registry.json' -PathType Leaf
        ProjectMemoryConfig = Test-Path -LiteralPath 'C:\RAH\CONFIGURE-RAH-PROJECT-MEMORY.cmd' -PathType Leaf
    }
}

function Format-Status {
    param($Status)
    @(
        'RAH RAVEN OS STATUS',
        '------------------------------',
        ('Version            : ' + $Status.Version),
        ('Computer           : ' + $Status.Computer),
        ('Raven Core :18765  : ' + $(if($Status.RavenCore18765){'ONLINE'}else{'OFFLINE'})),
        ('Node Agent :18766  : ' + $(if($Status.NodeAgent18766){'ONLINE'}else{'OFFLINE'})),
        ('Command Center     : ' + $(if($Status.CommandCenter){'READY'}else{'NOT FOUND'})),
        ('AI Fabric launcher : ' + $(if($Status.AiFabric){'READY'}else{'NOT FOUND'})),
        ('2-PC Grid          : ' + $(if($Status.Grid){'READY'}else{'NOT FOUND'})),
        ('2-PC Verify        : ' + $(if($Status.GridVerify){'READY'}else{'NOT FOUND'})),
        ('RAH OS Self-Test   : ' + $(if($Status.SelfTest){'READY'}else{'NOT FOUND'})),
        ('RAH OS Safe Repair : ' + $(if($Status.RepairLauncher){'READY'}else{'NOT FOUND'})),
        ('Hardware Registry  : ' + $(if($Status.HardwareRegistry){'READY'}else{'NOT BUILT'})),
        ('Project Memory cfg : ' + $(if($Status.ProjectMemoryConfig){'READY'}else{'NOT CONFIGURED'})),
        '',
        'Safety boundary:',
        ' - local fixed launchers only',
        ' - no arbitrary command input',
        ' - no background discovery',
        ' - no automatic firewall changes',
        ' - stable Node/Raven authority is unchanged'
    ) -join [Environment]::NewLine
}

function Start-FixedLauncher {
    param([Parameter(Mandatory=$true)][string]$Name,[string[]]$ExtraRoots=@())
    $path = Find-RahFile -Name $Name -ExtraRoots $ExtraRoots
    if(-not $path){ throw ('Not found: ' + $Name) }
    Write-RahOsLog ('START ' + $path)
    Start-Process -FilePath $path -WorkingDirectory (Split-Path -Parent $path)
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="RAH Raven OS" Height="650" Width="940" WindowStartupLocation="CenterScreen"
        Background="#090909" Foreground="#F3D37A" FontFamily="Segoe UI">
  <Grid Margin="18">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="0,0,0,12">
      <TextBlock Text="RAH RAVEN OS" FontSize="32" FontWeight="Bold" Foreground="#FFD76A"/>
      <TextBlock Text="Front Door v0.1 — local orchestration over stable Raven components" FontSize="15" Foreground="#C9B06A"/>
    </StackPanel>

    <WrapPanel Grid.Row="1" Margin="0,0,0,12">
      <Button Name="BtnRefresh" Content="REFRESH STATUS" Width="150" Height="40" Margin="0,0,8,8"/>
      <Button Name="BtnPrecheck" Content="PRECHECK" Width="130" Height="40" Margin="0,0,8,8"/>
      <Button Name="BtnRepair" Content="SAFE REPAIR" Width="140" Height="40" Margin="0,0,8,8"/>
      <Button Name="BtnAuto" Content="START LOCAL CORE" Width="160" Height="40" Margin="0,0,8,8"/>
      <Button Name="BtnCC" Content="COMMAND CENTER" Width="160" Height="40" Margin="0,0,8,8"/>
      <Button Name="BtnFabric" Content="RAVEN CORE / AI FABRIC" Width="190" Height="40" Margin="0,0,8,8"/>
      <Button Name="BtnGrid" Content="2-PC GRID" Width="140" Height="40" Margin="0,0,8,8"/>
      <Button Name="BtnVerify" Content="VERIFY 2-PC" Width="140" Height="40" Margin="0,0,8,8"/>
      <Button Name="BtnInstallGrid" Content="INSTALL / UPDATE 2-PC" Width="190" Height="40" Margin="0,0,8,8"/>
      <Button Name="BtnFolder" Content="OPEN C:\RAH" Width="140" Height="40" Margin="0,0,8,8"/>
    </WrapPanel>

    <Border Grid.Row="2" BorderBrush="#6D5721" BorderThickness="1" CornerRadius="5" Background="#111111" Padding="12">
      <TextBox Name="Output" Background="#111111" Foreground="#F4E4AA" BorderThickness="0" IsReadOnly="True"
               FontFamily="Consolas" FontSize="14" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
    </Border>

    <DockPanel Grid.Row="3" Margin="0,12,0,0">
      <TextBlock Text="RAH OS keeps Stable components separate: it launches them; it does not widen their permissions." Foreground="#9D8C57" VerticalAlignment="Center"/>
      <Button Name="BtnExit" Content="EXIT" Width="90" Height="34" DockPanel.Dock="Right" HorizontalAlignment="Right"/>
    </DockPanel>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$names = 'BtnRefresh','BtnPrecheck','BtnRepair','BtnAuto','BtnCC','BtnFabric','BtnGrid','BtnVerify','BtnInstallGrid','BtnFolder','BtnExit','Output'
foreach($n in $names){ Set-Variable -Name $n -Value $window.FindName($n) -Scope Script }

function Refresh-Ui {
    $s = Get-RahOsStatus
    $script:Output.Text = Format-Status $s
    Write-RahOsLog ('REFRESH Raven=' + $s.RavenCore18765 + ' Node=' + $s.NodeAgent18766)
}

$script:BtnRefresh.Add_Click({ try { Refresh-Ui } catch { $script:Output.Text = $_.Exception.Message } })
$script:BtnPrecheck.Add_Click({
    try {
        $path = Find-RahFile 'RAH-OS-SELFTEST.ps1'
        if(-not $path){ throw 'RAH OS Self-Test was not found.' }
        Write-RahOsLog ('PRECHECK ' + $path)
        Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File',$path) -WorkingDirectory (Split-Path -Parent $path)
        $script:Output.Text='RAH OS PRECHECK opened in a separate window. No repair or remote action was started.'
    } catch { $script:Output.Text=$_.Exception.Message }
})
$script:BtnRepair.Add_Click({
    try {
        Start-FixedLauncher 'REPAIR-RAH-OS.cmd'
        $script:Output.Text='Safe Repair started. It can refresh only the fixed Front Door allowlist.'
    } catch { $script:Output.Text=$_.Exception.Message }
})
$script:BtnCC.Add_Click({ try { Start-FixedLauncher 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'; $script:Output.Text='Command Center launcher started.' } catch { $script:Output.Text=$_.Exception.Message } })
$script:BtnFabric.Add_Click({ try { Start-FixedLauncher 'START-RAH-AI-FABRIC.cmd'; $script:Output.Text='Raven Core / AI Fabric launcher started.' } catch { $script:Output.Text=$_.Exception.Message } })
$script:BtnGrid.Add_Click({ try { Start-FixedLauncher 'START-HER-RAH-2PC-GRID.cmd' @('C:\RAH\2PCProof'); $script:Output.Text='RAH 2-PC Grid started.' } catch { $script:Output.Text=$_.Exception.Message } })
$script:BtnVerify.Add_Click({ try { Start-FixedLauncher 'VERIFY-RAH-2PC-GRID.cmd' @('C:\RAH\2PCProof'); $script:Output.Text='2-PC verification started.' } catch { $script:Output.Text=$_.Exception.Message } })
$script:BtnInstallGrid.Add_Click({ try { Start-FixedLauncher 'INSTALL-RAH-2PC-GRID.cmd'; $script:Output.Text='2-PC installer/updater started.' } catch { $script:Output.Text=$_.Exception.Message } })
$script:BtnFolder.Add_Click({ try { Start-Process explorer.exe -ArgumentList 'C:\RAH'; $script:Output.Text='Opened C:\RAH.' } catch { $script:Output.Text=$_.Exception.Message } })
$script:BtnAuto.Add_Click({
    try {
        $fabric = Find-RahFile 'START-RAH-AI-FABRIC.cmd'
        if(-not $fabric){ throw 'Raven Core / AI Fabric launcher not found.' }
        Start-Process -FilePath $fabric -WorkingDirectory (Split-Path -Parent $fabric)
        Write-RahOsLog ('AUTO START Raven Core: ' + $fabric)
        Start-Sleep -Milliseconds 700
        $cc = Find-RahFile 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
        if($cc){
            Start-Process -FilePath $cc -WorkingDirectory (Split-Path -Parent $cc)
            Write-RahOsLog ('AUTO START Command Center: ' + $cc)
            $script:Output.Text='Started Raven Core and Command Center. Node Agent is intentionally not auto-started.'
        } else {
            $script:Output.Text='Started Raven Core. Command Center launcher was not found. Node Agent is intentionally not auto-started.'
        }
    } catch { $script:Output.Text=$_.Exception.Message }
})
$script:BtnExit.Add_Click({ $window.Close() })

Write-RahOsLog ('OPEN RAH OS Front Door ' + $script:Version)
Refresh-Ui
[void]$window.ShowDialog()

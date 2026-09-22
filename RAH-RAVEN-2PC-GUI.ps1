param(
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Version = '1.2.1'
$script:Root = 'C:\RAH\2PCProof'
$script:Results = Join-Path $script:Root 'results'
$script:Logs = Join-Path $script:Root 'logs'
$script:RepoCache = Join-Path $script:Root 'repo'
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DefaultLenovoHost = 'DESKTOP-R2HTAGJ'
$script:LastKnownLenovoLan = '192.168.0.49'
$script:Utf8 = New-Object Text.UTF8Encoding($false)
$script:SourceRef = 'main'
$script:SourceRefFile = Join-Path $script:ScriptDir 'RAH-2PC-SOURCE-REF.txt'
if (Test-Path -LiteralPath $script:SourceRefFile -PathType Leaf) {
    try {
        $candidateRef = ([IO.File]::ReadAllText($script:SourceRefFile)).Trim()
        if ($candidateRef -eq 'main' -or $candidateRef -match '^rah-2pc-grid-v[0-9]+\.[0-9]+\.[0-9]+

function Write-RahLog {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $Message
    [IO.File]::AppendAllText((Join-Path $script:Logs 'rah-2pc-gui.log'), $line + [Environment]::NewLine, $script:Utf8)
}

function Test-TcpPort {
    param([string]$HostName,[int]$Port,[int]$TimeoutMs=1200)
    try {
        $client = New-Object Net.Sockets.TcpClient
        try {
            $ar = $client.BeginConnect($HostName,$Port,$null,$null)
            if (-not $ar.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
            $client.EndConnect($ar)
            return $true
        } finally {
            $client.Dispose()
        }
    } catch { return $false }
}

function Get-LenovoTailscaleIp {
    $ts = Get-Command tailscale.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ts) { return $null }
    try {
        $raw = & $ts.Source status --json 2>$null | Out-String
        if (-not $raw.Trim()) { return $null }
        $obj = $raw | ConvertFrom-Json
        if ($obj.Peer) {
            foreach ($prop in $obj.Peer.PSObject.Properties) {
                $peer = $prop.Value
                $name = ([string]$peer.HostName + ' ' + [string]$peer.DNSName).ToUpperInvariant()
                if ($name -match 'DESKTOP-R2HTAGJ|LENOVO') {
                    $ips = @($peer.TailscaleIPs)
                    if ($ips.Count -and $ips[0]) { return [string]$ips[0] }
                }
            }
        }
    } catch {}
    return $null
}

function Get-CachedRepoRoot {
    $fixed = Join-Path $script:RepoCache 'rah-platform-source'
    if (Test-Path -LiteralPath $fixed -PathType Container) { return $fixed }
    return $null
}

function Find-RepoFile {
    param([string]$Name)
    $candidates = @(
        (Join-Path $script:ScriptDir $Name),
        (Join-Path 'C:\RAH\rah-platform' $Name),
        (Join-Path 'C:\RAH\RAH-Platform' $Name)
    )
    $cached = Get-CachedRepoRoot
    if ($cached) { $candidates += (Join-Path $cached $Name) }
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p -PathType Leaf) { return [IO.Path]::GetFullPath($p) }
    }
    return $null
}

function Sync-RahRepo {
    $zip = Join-Path $script:RepoCache 'rah-platform-source.zip'
    $dest = Join-Path $script:RepoCache 'rah-platform-source'
    $stage = Join-Path $script:RepoCache 'stage'
    New-Item -ItemType Directory -Force -Path $script:RepoCache | Out-Null
    Write-RahLog ('Repo sync requested for ref ' + $script:SourceRef + '.')
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $stage | Out-Null

    if ($script:SourceRef -eq 'main') {
        $archiveUrl = 'https://github.com/NilsRa73/rah-platform/archive/refs/heads/main.zip'
    } elseif ($script:SourceRef -match '^rah-2pc-grid-v') {
        $archiveUrl = 'https://github.com/NilsRa73/rah-platform/archive/refs/tags/' + $script:SourceRef + '.zip'
    } else {
        $archiveUrl = 'https://github.com/NilsRa73/rah-platform/archive/' + $script:SourceRef + '.zip'
    }

    Invoke-WebRequest -UseBasicParsing -Uri $archiveUrl -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
    $expanded = Get-ChildItem -LiteralPath $stage -Directory | Select-Object -First 1
    if (-not $expanded) { throw 'RAH repo package did not extract correctly.' }
    Move-Item -LiteralPath $expanded.FullName -Destination $dest -Force
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Write-RahLog ('Repo sync PASS for ref ' + $script:SourceRef + '.')
    return $dest
}

function Ensure-RepoFile {
    param([string]$Name)
    $p = Find-RepoFile $Name
    if ($p) { return $p }
    $null = Sync-RahRepo
    $p = Find-RepoFile $Name
    if (-not $p) { throw "Required RAH file missing after repo sync: $Name" }
    return $p
}

function Write-Diagnostics {
    param([string]$Target)
    $ts = Get-LenovoTailscaleIp
    $registryPath = 'C:\RAH\HardwareRegistry\registry.json'
    $doc = [ordered]@{
        schema = 'rah-2pc-gui-diagnostics-v1'
        version = $script:Version
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
        computerName = $env:COMPUTERNAME
        target = $Target
        runtime = 'Windows PowerShell/.NET - Python not required'
        sourceRef = $script:SourceRef
        hardwareRegistry = $registryPath
        hardwareRegistryExists = (Test-Path -LiteralPath $registryPath -PathType Leaf)
        tailscaleLenovoIp = if($ts){$ts}else{'NOT_DETECTED'}
        localRaven18765 = Test-TcpPort '127.0.0.1' 18765
        localNode18766 = Test-TcpPort '127.0.0.1' 18766
        targetNode18766 = if($Target){Test-TcpPort $Target 18766}else{$false}
        tokenCollected = $false
        arbitraryShell = $false
        remoteRoute = '/raven/status'
        remoteCapability = 'system-inventory'
    }
    $path = Join-Path $script:Logs 'last-diagnostics.json'
    [IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 8), $script:Utf8)
    return $doc
}

function Update-LocalHardwareRegistry {
    $inventoryScript = Ensure-RepoFile 'RAH-HARDWARE-INVENTORY.ps1'
    $registryScript = Ensure-RepoFile 'RAH-HARDWARE-REGISTRY.ps1'
    . $inventoryScript
    . $registryScript
    $profile = Get-RahHardwareInventory
    $update = Update-RahHardwareRegistry -Profile $profile -Source '2pc-gui-local'
    Write-RahLog ('Local hardware registry updated: ' + [string]$update.deviceId + ' changed=' + [string]$update.changed)
    return $update
}

function Import-RemoteHardwareProfile {
    param($Result)
    if ($null -eq $Result.inventory -or $null -eq $Result.inventory.hardware_profile) { return $null }
    if ([string]$Result.inventory.hardware_profile.schema -ne 'rah-hardware-profile-v1') { throw 'Remote detailed hardware profile schema invalid.' }
    $registryScript = Ensure-RepoFile 'RAH-HARDWARE-REGISTRY.ps1'
    . $registryScript
    $update = Update-RahHardwareRegistry -Profile $Result.inventory.hardware_profile -Source 'remote-raven-system-inventory'
    Write-RahLog ('Remote hardware registry updated: ' + [string]$update.deviceId + ' changed=' + [string]$update.changed)
    return $update
}

function Invoke-InventoryClient {
    param([string]$Target,[string]$Token)
    if (-not $Target) { throw 'Velg Lenovo-adresse først.' }
    if (-not $Token -or $Token.Length -lt 24) { throw 'Lim inn fersk Node-token fra Lenovo.' }

    $client = Ensure-RepoFile 'RAH-2PC-CLIENT.ps1'
    . $client
    $out = Join-Path $script:Results 'last-inventory.json'
    $result = Invoke-Rah2PcInventory -TargetHost $Target -Token $Token -OutputPath $out
    if ([string]$result.status -ne 'PASS') { throw 'Inventory result did not contain PASS.' }
    $null = Import-RemoteHardwareProfile -Result $result
    Write-RahLog ('Inventory PASS from ' + [string]$result.inventory.hostname)
    return $result
}

function Invoke-FinalAcceptance {
    $validator = Ensure-RepoFile 'RAH-2PC-ACCEPTANCE.ps1'
    . $validator
    $input = Join-Path $script:Results 'last-inventory.json'
    $output = Join-Path $script:Results 'REAL-HARDWARE-ACCEPTANCE.json'
    if (-not (Test-Path -LiteralPath $input -PathType Leaf)) { throw 'Kjør SYSTEM INVENTORY først. last-inventory.json mangler.' }
    $report = Invoke-Rah2PcFinalAcceptance -SourcePath $input -DestinationPath $output -FixedExpectedHost 'DESKTOP-R2HTAGJ'
    if ([string]$report.overall -ne 'PASS') { throw 'Acceptance report did not contain PASS.' }
    Write-RahLog 'Real-hardware acceptance PASS.'
    return $report
}

function Invoke-SelfTest {
    $client = Join-Path $script:ScriptDir 'RAH-2PC-CLIENT.ps1'
    $acceptance = Join-Path $script:ScriptDir 'RAH-2PC-ACCEPTANCE.ps1'
    $inventory = Join-Path $script:ScriptDir 'RAH-HARDWARE-INVENTORY.ps1'
    $registry = Join-Path $script:ScriptDir 'RAH-HARDWARE-REGISTRY.ps1'
    foreach($path in @($client,$acceptance,$inventory,$registry)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Required self-test file missing: ' + $path) }
    }
    . $client
    . $acceptance
    . $inventory
    . $registry
    Test-Rah2PcClient
    Test-Rah2PcAcceptance
    Test-RahHardwareInventory
    Test-RahHardwareRegistry
    Write-Host 'PASS: RAH Raven 2-PC GUI launcher contract - Python free' -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

if ($env:OS -ne 'Windows_NT') { throw 'RAH Raven 2-PC GUI requires Windows.' }

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RAH Raven OS · 2-PC Grid" Width="1320" Height="820"
        MinWidth="1100" MinHeight="720" WindowStartupLocation="CenterScreen"
        Background="#07090C" Foreground="#F4E8C2" FontFamily="Segoe UI">
  <Window.Resources>
    <SolidColorBrush x:Key="Gold" Color="#D9B65B"/>
    <SolidColorBrush x:Key="Gold2" Color="#F0D989"/>
    <SolidColorBrush x:Key="Panel" Color="#10141A"/>
    <SolidColorBrush x:Key="Panel2" Color="#0B0E13"/>
    <SolidColorBrush x:Key="Muted" Color="#87909C"/>
    <SolidColorBrush x:Key="Green" Color="#6CE0A3"/>
    <SolidColorBrush x:Key="Red" Color="#FF7E7E"/>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#11161D"/>
      <Setter Property="Foreground" Value="{StaticResource Gold2}"/>
      <Setter Property="BorderBrush" Value="#6A5728"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="14,10"/>
      <Setter Property="Margin" Value="0,0,8,8"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#090C10"/>
      <Setter Property="Foreground" Value="#F5F1E7"/>
      <Setter Property="BorderBrush" Value="#4C4328"/>
      <Setter Property="Padding" Value="10"/>
    </Style>
    <Style TargetType="PasswordBox">
      <Setter Property="Background" Value="#090C10"/>
      <Setter Property="Foreground" Value="#F5F1E7"/>
      <Setter Property="BorderBrush" Value="#4C4328"/>
      <Setter Property="Padding" Value="10"/>
    </Style>
  </Window.Resources>
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="235"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <Border Grid.Column="0" Background="#090C11" BorderBrush="#3B321C" BorderThickness="0,0,1,0">
      <Grid Margin="18">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel>
          <TextBlock Text="ᚱ" FontSize="56" Foreground="{StaticResource Gold2}" HorizontalAlignment="Center"/>
          <TextBlock Text="RAH RAVEN OS" FontSize="20" FontWeight="Bold" Foreground="{StaticResource Gold2}" HorizontalAlignment="Center"/>
          <TextBlock Text="2-PC GRID · v1" FontSize="12" Foreground="{StaticResource Muted}" HorizontalAlignment="Center" Margin="0,4,0,20"/>
        </StackPanel>
        <StackPanel Grid.Row="1">
          <Button Name="BtnOverview" Content="OVERVIEW / PRECHECK"/>
          <Button Name="BtnStartRaven" Content="START RAVEN CORE"/>
          <Button Name="BtnStartNode" Content="START LENOVO NODE"/>
          <Button Name="BtnTestLink" Content="TEST 2-PC LINK"/>
          <Button Name="BtnRunInventory" Content="RUN SYSTEM INVENTORY"/>
          <Button Name="BtnDiagnostics" Content="DIAGNOSTICS"/>
          <Button Name="BtnRefreshHardware" Content="REFRESH THIS PC HARDWARE"/>
          <Button Name="BtnHardwareRegistry" Content="HARDWARE REGISTRY"/>
          <Button Name="BtnFinalAcceptance" Content="FINAL REAL-HARDWARE ACCEPTANCE"/>
          <Button Name="BtnResults" Content="OPEN RESULTS"/>
          <Button Name="BtnLogs" Content="OPEN LOGS"/>
        </StackPanel>
        <Border Grid.Row="3" BorderBrush="#3B321C" BorderThickness="1" Background="#0D1117" Padding="12">
          <StackPanel>
            <TextBlock Text="SECURITY GATE" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBlock Text="READ-ONLY" Foreground="{StaticResource Green}" FontWeight="Bold" Margin="0,4,0,0"/>
            <TextBlock Text="No shell · no arbitrary path · no token storage" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,4,0,0"/>
          </StackPanel>
        </Border>
      </Grid>
    </Border>

    <Grid Grid.Column="1" Margin="24">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock Text="RAVEN GRID CONTROL" FontSize="13" Foreground="{StaticResource Gold}"/>
          <TextBlock Text="HOVED-PC  ↔  LENOVO" FontSize="34" FontWeight="Bold" Foreground="#FFF5D8"/>
          <TextBlock Text="One-click control surface for the fixed Stable system.inventory route." Foreground="{StaticResource Muted}" FontSize="14"/>
        </StackPanel>
        <Border Grid.Column="1" Background="#111820" BorderBrush="#5D512E" BorderThickness="1" CornerRadius="18" Padding="16,9" VerticalAlignment="Top">
          <TextBlock Name="TxtOverall" Text="READY FOR PRECHECK" Foreground="{StaticResource Gold2}" FontWeight="Bold"/>
        </Border>
      </Grid>

      <UniformGrid Grid.Row="1" Columns="4" Margin="0,22,0,16">
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,10,0">
          <StackPanel><TextBlock Text="THIS PC" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtThisPc" Text="—" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,10,0">
          <StackPanel><TextBlock Text="RAVEN CORE :18765" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtRaven" Text="UNKNOWN" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,10,0">
          <StackPanel><TextBlock Text="NODE :18766" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtNode" Text="UNKNOWN" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16">
          <StackPanel><TextBlock Text="LAST INVENTORY" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtLast" Text="NONE" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
      </UniformGrid>

      <Border Grid.Row="2" Background="#0E1218" BorderBrush="#5A4B27" BorderThickness="1" CornerRadius="14" Padding="18" Margin="0,0,0,16">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="1.3*"/>
            <ColumnDefinition Width="1.4*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel Margin="0,0,12,0">
            <TextBlock Text="LENOVO TARGET" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBox Name="TxtTarget" Text="DESKTOP-R2HTAGJ" Margin="0,7,0,0"/>
            <TextBlock Name="TxtTargetHint" Text="LAN preferred · Node 1.4 Stable accepts RFC1918 requester sources" Foreground="{StaticResource Muted}" FontSize="11" Margin="0,4,0,0"/>
          </StackPanel>
          <StackPanel Grid.Column="1" Margin="0,0,12,0">
            <TextBlock Text="FRESH NODE TOKEN" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <PasswordBox Name="PwdToken" Margin="0,7,0,0"/>
            <TextBlock Text="Used in memory for HMAC proof, then cleared. Never written to disk." Foreground="{StaticResource Muted}" FontSize="11" Margin="0,4,0,0"/>
          </StackPanel>
          <Button Grid.Column="2" Name="BtnRunBig" Content="RUN SYSTEM INVENTORY" Padding="24,12" FontSize="15" VerticalAlignment="Center"/>
        </Grid>
      </Border>

      <Grid Grid.Row="3">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="1.1*"/>
          <ColumnDefinition Width="0.9*"/>
        </Grid.ColumnDefinitions>
        <Border Background="{StaticResource Panel2}" BorderBrush="#2C333C" BorderThickness="1" CornerRadius="14" Padding="18" Margin="0,0,12,0">
          <DockPanel>
            <TextBlock DockPanel.Dock="Top" Text="MISSION OUTPUT" Foreground="{StaticResource Gold}" FontWeight="Bold" Margin="0,0,0,10"/>
            <TextBox Name="TxtOutput" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" AcceptsReturn="True" FontFamily="Consolas" FontSize="12"/>
          </DockPanel>
        </Border>
        <Border Grid.Column="1" Background="{StaticResource Panel2}" BorderBrush="#2C333C" BorderThickness="1" CornerRadius="14" Padding="18">
          <StackPanel>
            <TextBlock Text="OPERATOR FLOW" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBlock Text="1 · Lenovo: START RAVEN CORE" Foreground="#ECE7DA" Margin="0,12,0,0"/>
            <TextBlock Text="2 · Lenovo: START LENOVO NODE" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <TextBlock Text="3 · Copy the fresh token shown locally" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <TextBlock Text="4 · HOVED-PC: TEST 2-PC LINK" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <TextBlock Text="5 · Paste token and RUN SYSTEM INVENTORY" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <Separator Margin="0,18,0,14" Background="#3B321C"/>
            <TextBlock Text="WHY ONE TOKEN PASTE?" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBlock Text="Node 1.4 deliberately keeps its fresh secret local. The GUI does not weaken that boundary just to remove one copy/paste." Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,7,0,0"/>
          </StackPanel>
        </Border>
      </Grid>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @('BtnOverview','BtnStartRaven','BtnStartNode','BtnTestLink','BtnRunInventory','BtnDiagnostics','BtnRefreshHardware','BtnHardwareRegistry','BtnFinalAcceptance','BtnResults','BtnLogs','BtnRunBig','TxtOverall','TxtThisPc','TxtRaven','TxtNode','TxtLast','TxtTarget','TxtTargetHint','PwdToken','TxtOutput')
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

function Set-Output {
    param([string]$Text,[switch]$Error)
    $script:TxtOutput.Text = $Text
    $script:TxtOverall.Text = if($Error){'ATTENTION REQUIRED'}else{'RAVEN GRID READY'}
    $script:TxtOverall.Foreground = if($Error){[Windows.Media.Brushes]::LightCoral}else{[Windows.Media.Brushes]::Khaki}
}

function Refresh-Overview {
    $script:TxtThisPc.Text = $env:COMPUTERNAME
    $raven = Test-TcpPort '127.0.0.1' 18765
    $nodeLocal = Test-TcpPort '127.0.0.1' 18766
    $script:TxtRaven.Text = if($raven){'ONLINE'}else{'OFFLINE'}
    $script:TxtRaven.Foreground = if($raven){[Windows.Media.Brushes]::LightGreen}else{[Windows.Media.Brushes]::LightCoral}
    $script:TxtNode.Text = if($nodeLocal){'LOCAL ONLINE'}else{'LOCAL OFFLINE'}
    $script:TxtNode.Foreground = if($nodeLocal){[Windows.Media.Brushes]::LightGreen}else{[Windows.Media.Brushes]::Gray}

    $ts = Get-LenovoTailscaleIp
    if (-not $script:TxtTarget.Text) {
        $script:TxtTarget.Text = $script:DefaultLenovoHost
    }
    if ($script:TxtTarget.Text -eq $script:DefaultLenovoHost -and -not (Test-TcpPort $script:DefaultLenovoHost 18766 700)) {
        if (Test-TcpPort $script:LastKnownLenovoLan 18766 700) {
            $script:TxtTarget.Text = $script:LastKnownLenovoLan
            $script:TxtTargetHint.Text = 'Lenovo hostname did not answer; using private LAN fallback'
        }
    }
    if ($ts -and $script:TxtTarget.Text -ne $script:LastKnownLenovoLan) {
        $script:TxtTargetHint.Text = 'Private LAN hostname preferred; Tailscale 100.64/10 stays outside Stable requester-source policy'
    }

    $last = Join-Path $script:Results 'last-inventory.json'
    if (Test-Path -LiteralPath $last) {
        try {
            $r = Get-Content -LiteralPath $last -Raw | ConvertFrom-Json
            $script:TxtLast.Text = ([string]$r.inventory.hostname + ' · PASS')
            $script:TxtLast.Foreground = [Windows.Media.Brushes]::LightGreen
        } catch {
            $script:TxtLast.Text = 'RESULT INVALID'
            $script:TxtLast.Foreground = [Windows.Media.Brushes]::LightCoral
        }
    }

    $diag = Write-Diagnostics $script:TxtTarget.Text
    $msg = @(
        'RAH RAVEN OS · 2-PC PRECHECK'
        '----------------------------------------'
        ('This PC          : ' + $diag.computerName)
        ('Runtime          : ' + $diag.runtime)
        ('Source ref       : ' + $diag.sourceRef)
        ('Hardware registry: ' + $diag.hardwareRegistryExists)
        ('Local Raven      : ' + $diag.localRaven18765)
        ('Local Node       : ' + $diag.localNode18766)
        ('Lenovo target    : ' + $diag.target)
        ('Target :18766    : ' + $diag.targetNode18766)
        ('Tailscale detect : ' + $diag.tailscaleLenovoIp)
        ''
        'Security: fixed /raven/status -> system-inventory only.'
    ) -join [Environment]::NewLine
    Set-Output $msg
}

$script:BtnOverview.Add_Click({ try { Refresh-Overview } catch { Set-Output $_.Exception.Message -Error } })

$script:BtnStartRaven.Add_Click({
    try {
        $installer = Ensure-RepoFile 'INSTALL-RAH-AI-FABRIC.ps1'
        $args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $installer + '"'),'-Mode','Install','-Ref',$script:SourceRef)
        Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory (Split-Path -Parent $installer)
        Write-RahLog ('Started RAH AI Fabric installer at ref ' + $script:SourceRef + '.')
        Set-Output ('RAH Raven Core installer started from pinned ref ' + $script:SourceRef + '.' + [Environment]::NewLine + 'Wait for PASS on 127.0.0.1:18765, then refresh overview.')
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnStartNode.Add_Click({
    try {
        $node = Ensure-RepoFile 'rah-node-agent-v1.4.py'
        $candidate = Ensure-RepoFile 'rah-node-agent-v1.4-candidate.py'
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw 'Node Agent 1.4 candidate companion file missing.' }
        $venvPython = 'C:\RAH\AI-Fabric\venv\Scripts\python.exe'
        if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
            throw 'Raven AI Fabric runtime mangler. Kjør START RAVEN CORE først; Raven installerer sin egen isolerte Python-runtime.'
        }
        $args = '/k ""{0}" "{1}" --allow-lan --name "{2}" --role "worker" --capability compute"' -f $venvPython,$node,$env:COMPUTERNAME
        Start-Process -FilePath 'cmd.exe' -ArgumentList $args -WorkingDirectory (Split-Path -Parent $node)
        Write-RahLog ('Started Node Agent 1.4 Stable with AI Fabric venv from ref ' + $script:SourceRef + '.')
        Set-Output ('Lenovo Node Agent 1.4 Stable started with Raven internal runtime.' + [Environment]::NewLine + 'Copy the fresh token from the Node console. The token is intentionally not stored.')
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnTestLink.Add_Click({
    try {
        $target = $script:TxtTarget.Text.Trim()
        if (-not $target) { throw 'Target address is empty.' }
        $ok = Test-TcpPort $target 18766 1800
        if ($ok) {
            Set-Output ('PASS: Node port 18766 reachable on ' + $target + '.' + [Environment]::NewLine + 'Next: paste fresh token and run SYSTEM INVENTORY.')
        } else {
            Set-Output ('FAIL: Cannot reach ' + $target + ':18766.' + [Environment]::NewLine + 'Check that Node Agent 1.4 is running on Lenovo and Windows/Tailscale networking allows the private connection.') -Error
        }
    } catch { Set-Output $_.Exception.Message -Error }
})

$runInventoryAction = {
    try {
        $target = $script:TxtTarget.Text.Trim()
        $token = $script:PwdToken.Password
        $script:TxtOverall.Text = 'RUNNING SYSTEM INVENTORY...'
        $script:TxtOutput.Text = 'Authenticating Node with single-use nonce + HMAC-SHA256 proof...'
        $result = Invoke-InventoryClient $target $token
        $script:PwdToken.Clear()
        $i = $result.inventory
        $lines = @(
            'RAH RAVEN 2-PC INVENTORY · PASS'
            '========================================'
            ('HOST      : ' + [string]$i.hostname)
            ('OS        : ' + [string]$i.os.system + ' ' + [string]$i.os.release + ' ' + [string]$i.os.architecture)
            ('CPU       : ' + [string]$i.cpu.name)
            ('CORES     : ' + [string]$i.cpu.logical_cores)
            ('RAM       : ' + [string]$i.ram_gb + ' GB')
            ('GPU       : ' + ((@($i.gpus) -join ', ')))
            ('MONITORS  : ' + [string]$i.monitor_count)
            ('RAVEN     : v' + [string]$i.raven_bridge.version + ' / port ' + [string]$i.raven_bridge.port)
            ''
            'SECURITY'
            'Read-only          : TRUE'
            'Arbitrary commands : FALSE'
            'Caller arguments   : FALSE'
            'Token persisted    : FALSE'
            'Local Raven hop    : TRUE'
            ''
            ('Saved: ' + (Join-Path $script:Results 'last-inventory.json'))
        )
        $script:TxtLast.Text = ([string]$i.hostname + ' · PASS')
        $script:TxtLast.Foreground = [Windows.Media.Brushes]::LightGreen
        Set-Output ($lines -join [Environment]::NewLine)
    } catch {
        $script:PwdToken.Clear()
        Set-Output $_.Exception.Message -Error
    }
}
$script:BtnRunBig.Add_Click($runInventoryAction)
$script:BtnRunInventory.Add_Click($runInventoryAction)

$script:BtnDiagnostics.Add_Click({
    try {
        $diag = Write-Diagnostics $script:TxtTarget.Text.Trim()
        Set-Output (($diag | ConvertTo-Json -Depth 8) + [Environment]::NewLine + [Environment]::NewLine + 'Saved: ' + (Join-Path $script:Logs 'last-diagnostics.json'))
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnRefreshHardware.Add_Click({
    try {
        $update = Update-LocalHardwareRegistry
        Set-Output ('PASS: This PC hardware profile refreshed.' + [Environment]::NewLine +
                    'Device: ' + [string]$update.hostname + [Environment]::NewLine +
                    'Changed: ' + [string]$update.changed + [Environment]::NewLine +
                    'Registry: ' + [string]$update.registryPath)
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnHardwareRegistry.Add_Click({
    $registryRoot = 'C:\RAH\HardwareRegistry'
    New-Item -ItemType Directory -Force -Path $registryRoot | Out-Null
    Start-Process explorer.exe $registryRoot
})

$script:BtnFinalAcceptance.Add_Click({
    try {
        $report = Invoke-FinalAcceptance
        $script:TxtOverall.Text = 'REAL-HARDWARE PASS'
        $script:TxtOverall.Foreground = [Windows.Media.Brushes]::LightGreen
        Set-Output ((
            'RAH RAVEN 2-PC GRID · REAL-HARDWARE ACCEPTANCE PASS' + [Environment]::NewLine +
            '=====================================================' + [Environment]::NewLine +
            'Lenovo host : ' + [string]$report.evidence.hostname + [Environment]::NewLine +
            'Target      : ' + [string]$report.evidence.targetHost + ':' + [string]$report.evidence.targetPort + [Environment]::NewLine +
            'Raven       : localhost:' + [string]$report.evidence.ravenPort + [Environment]::NewLine +
            'Read-only   : TRUE' + [Environment]::NewLine +
            'No shell    : TRUE' + [Environment]::NewLine +
            'Token saved : FALSE' + [Environment]::NewLine + [Environment]::NewLine +
            'Evidence: ' + (Join-Path $script:Results 'REAL-HARDWARE-ACCEPTANCE.json')
        ))
        $script:TxtOverall.Text = 'REAL-HARDWARE PASS'
        $script:TxtOverall.Foreground = [Windows.Media.Brushes]::LightGreen
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnResults.Add_Click({ Start-Process explorer.exe $script:Results })
$script:BtnLogs.Add_Click({ Start-Process explorer.exe $script:Logs })

$window.Add_ContentRendered({
    try {
        try { $null = Update-LocalHardwareRegistry } catch { Write-RahLog ('Local hardware registry startup refresh warning: ' + $_.Exception.Message) }
        Refresh-Overview
    } catch { Set-Output $_.Exception.Message -Error }
})

Write-RahLog ('GUI started on ' + $env:COMPUTERNAME)
$null = $window.ShowDialog()
 -or $candidateRef -match '^[0-9a-fA-F]{40}

function Write-RahLog {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $Message
    [IO.File]::AppendAllText((Join-Path $script:Logs 'rah-2pc-gui.log'), $line + [Environment]::NewLine, $script:Utf8)
}

function Test-TcpPort {
    param([string]$HostName,[int]$Port,[int]$TimeoutMs=1200)
    try {
        $client = New-Object Net.Sockets.TcpClient
        try {
            $ar = $client.BeginConnect($HostName,$Port,$null,$null)
            if (-not $ar.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
            $client.EndConnect($ar)
            return $true
        } finally {
            $client.Dispose()
        }
    } catch { return $false }
}

function Get-LenovoTailscaleIp {
    $ts = Get-Command tailscale.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ts) { return $null }
    try {
        $raw = & $ts.Source status --json 2>$null | Out-String
        if (-not $raw.Trim()) { return $null }
        $obj = $raw | ConvertFrom-Json
        if ($obj.Peer) {
            foreach ($prop in $obj.Peer.PSObject.Properties) {
                $peer = $prop.Value
                $name = ([string]$peer.HostName + ' ' + [string]$peer.DNSName).ToUpperInvariant()
                if ($name -match 'DESKTOP-R2HTAGJ|LENOVO') {
                    $ips = @($peer.TailscaleIPs)
                    if ($ips.Count -and $ips[0]) { return [string]$ips[0] }
                }
            }
        }
    } catch {}
    return $null
}

function Find-RepoFile {
    param([string]$Name)
    $candidates = @(
        (Join-Path $script:ScriptDir $Name),
        (Join-Path 'C:\RAH\rah-platform' $Name),
        (Join-Path 'C:\RAH\RAH-Platform' $Name),
        (Join-Path $script:RepoCache ('rah-platform-main\' + $Name))
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p -PathType Leaf) { return [IO.Path]::GetFullPath($p) }
    }
    return $null
}

function Sync-RahRepo {
    $zip = Join-Path $script:RepoCache 'rah-platform-main.zip'
    $dest = Join-Path $script:RepoCache 'rah-platform-main'
    New-Item -ItemType Directory -Force -Path $script:RepoCache | Out-Null
    Write-RahLog 'Repo sync requested.'
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/NilsRa73/rah-platform/archive/refs/heads/main.zip' -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $script:RepoCache -Force
    if (-not (Test-Path -LiteralPath $dest -PathType Container)) { throw 'RAH repo package did not extract correctly.' }
    Write-RahLog 'Repo sync PASS.'
    return $dest
}

function Ensure-RepoFile {
    param([string]$Name)
    $p = Find-RepoFile $Name
    if ($p) { return $p }
    $null = Sync-RahRepo
    $p = Find-RepoFile $Name
    if (-not $p) { throw "Required RAH file missing after repo sync: $Name" }
    return $p
}

function Write-Diagnostics {
    param([string]$Target)
    $ts = Get-LenovoTailscaleIp
    $registryPath = 'C:\RAH\HardwareRegistry\registry.json'
    $doc = [ordered]@{
        schema = 'rah-2pc-gui-diagnostics-v1'
        version = $script:Version
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
        computerName = $env:COMPUTERNAME
        target = $Target
        runtime = 'Windows PowerShell/.NET - Python not required'
        hardwareRegistry = $registryPath
        hardwareRegistryExists = (Test-Path -LiteralPath $registryPath -PathType Leaf)
        tailscaleLenovoIp = if($ts){$ts}else{'NOT_DETECTED'}
        localRaven18765 = Test-TcpPort '127.0.0.1' 18765
        localNode18766 = Test-TcpPort '127.0.0.1' 18766
        targetNode18766 = if($Target){Test-TcpPort $Target 18766}else{$false}
        tokenCollected = $false
        arbitraryShell = $false
        remoteRoute = '/raven/status'
        remoteCapability = 'system-inventory'
    }
    $path = Join-Path $script:Logs 'last-diagnostics.json'
    [IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 8), $script:Utf8)
    return $doc
}

function Update-LocalHardwareRegistry {
    $inventoryScript = Ensure-RepoFile 'RAH-HARDWARE-INVENTORY.ps1'
    $registryScript = Ensure-RepoFile 'RAH-HARDWARE-REGISTRY.ps1'
    . $inventoryScript
    . $registryScript
    $profile = Get-RahHardwareInventory
    $update = Update-RahHardwareRegistry -Profile $profile -Source '2pc-gui-local'
    Write-RahLog ('Local hardware registry updated: ' + [string]$update.deviceId + ' changed=' + [string]$update.changed)
    return $update
}

function Import-RemoteHardwareProfile {
    param($Result)
    if ($null -eq $Result.inventory -or $null -eq $Result.inventory.hardware_profile) { return $null }
    if ([string]$Result.inventory.hardware_profile.schema -ne 'rah-hardware-profile-v1') { throw 'Remote detailed hardware profile schema invalid.' }
    $registryScript = Ensure-RepoFile 'RAH-HARDWARE-REGISTRY.ps1'
    . $registryScript
    $update = Update-RahHardwareRegistry -Profile $Result.inventory.hardware_profile -Source 'remote-raven-system-inventory'
    Write-RahLog ('Remote hardware registry updated: ' + [string]$update.deviceId + ' changed=' + [string]$update.changed)
    return $update
}

function Invoke-InventoryClient {
    param([string]$Target,[string]$Token)
    if (-not $Target) { throw 'Velg Lenovo-adresse først.' }
    if (-not $Token -or $Token.Length -lt 24) { throw 'Lim inn fersk Node-token fra Lenovo.' }

    $client = Ensure-RepoFile 'RAH-2PC-CLIENT.ps1'
    . $client
    $out = Join-Path $script:Results 'last-inventory.json'
    $result = Invoke-Rah2PcInventory -TargetHost $Target -Token $Token -OutputPath $out
    if ([string]$result.status -ne 'PASS') { throw 'Inventory result did not contain PASS.' }
    $null = Import-RemoteHardwareProfile -Result $result
    Write-RahLog ('Inventory PASS from ' + [string]$result.inventory.hostname)
    return $result
}

function Invoke-FinalAcceptance {
    $validator = Ensure-RepoFile 'RAH-2PC-ACCEPTANCE.ps1'
    . $validator
    $input = Join-Path $script:Results 'last-inventory.json'
    $output = Join-Path $script:Results 'REAL-HARDWARE-ACCEPTANCE.json'
    if (-not (Test-Path -LiteralPath $input -PathType Leaf)) { throw 'Kjør SYSTEM INVENTORY først. last-inventory.json mangler.' }
    $report = Invoke-Rah2PcFinalAcceptance -SourcePath $input -DestinationPath $output -FixedExpectedHost 'DESKTOP-R2HTAGJ'
    if ([string]$report.overall -ne 'PASS') { throw 'Acceptance report did not contain PASS.' }
    Write-RahLog 'Real-hardware acceptance PASS.'
    return $report
}

function Invoke-SelfTest {
    $client = Join-Path $script:ScriptDir 'RAH-2PC-CLIENT.ps1'
    $acceptance = Join-Path $script:ScriptDir 'RAH-2PC-ACCEPTANCE.ps1'
    $inventory = Join-Path $script:ScriptDir 'RAH-HARDWARE-INVENTORY.ps1'
    $registry = Join-Path $script:ScriptDir 'RAH-HARDWARE-REGISTRY.ps1'
    foreach($path in @($client,$acceptance,$inventory,$registry)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Required self-test file missing: ' + $path) }
    }
    . $client
    . $acceptance
    . $inventory
    . $registry
    Test-Rah2PcClient
    Test-Rah2PcAcceptance
    Test-RahHardwareInventory
    Test-RahHardwareRegistry
    Write-Host 'PASS: RAH Raven 2-PC GUI launcher contract - Python free' -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

if ($env:OS -ne 'Windows_NT') { throw 'RAH Raven 2-PC GUI requires Windows.' }

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RAH Raven OS · 2-PC Grid" Width="1320" Height="820"
        MinWidth="1100" MinHeight="720" WindowStartupLocation="CenterScreen"
        Background="#07090C" Foreground="#F4E8C2" FontFamily="Segoe UI">
  <Window.Resources>
    <SolidColorBrush x:Key="Gold" Color="#D9B65B"/>
    <SolidColorBrush x:Key="Gold2" Color="#F0D989"/>
    <SolidColorBrush x:Key="Panel" Color="#10141A"/>
    <SolidColorBrush x:Key="Panel2" Color="#0B0E13"/>
    <SolidColorBrush x:Key="Muted" Color="#87909C"/>
    <SolidColorBrush x:Key="Green" Color="#6CE0A3"/>
    <SolidColorBrush x:Key="Red" Color="#FF7E7E"/>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#11161D"/>
      <Setter Property="Foreground" Value="{StaticResource Gold2}"/>
      <Setter Property="BorderBrush" Value="#6A5728"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="14,10"/>
      <Setter Property="Margin" Value="0,0,8,8"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#090C10"/>
      <Setter Property="Foreground" Value="#F5F1E7"/>
      <Setter Property="BorderBrush" Value="#4C4328"/>
      <Setter Property="Padding" Value="10"/>
    </Style>
    <Style TargetType="PasswordBox">
      <Setter Property="Background" Value="#090C10"/>
      <Setter Property="Foreground" Value="#F5F1E7"/>
      <Setter Property="BorderBrush" Value="#4C4328"/>
      <Setter Property="Padding" Value="10"/>
    </Style>
  </Window.Resources>
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="235"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <Border Grid.Column="0" Background="#090C11" BorderBrush="#3B321C" BorderThickness="0,0,1,0">
      <Grid Margin="18">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel>
          <TextBlock Text="ᚱ" FontSize="56" Foreground="{StaticResource Gold2}" HorizontalAlignment="Center"/>
          <TextBlock Text="RAH RAVEN OS" FontSize="20" FontWeight="Bold" Foreground="{StaticResource Gold2}" HorizontalAlignment="Center"/>
          <TextBlock Text="2-PC GRID · v1" FontSize="12" Foreground="{StaticResource Muted}" HorizontalAlignment="Center" Margin="0,4,0,20"/>
        </StackPanel>
        <StackPanel Grid.Row="1">
          <Button Name="BtnOverview" Content="OVERVIEW / PRECHECK"/>
          <Button Name="BtnStartRaven" Content="START RAVEN CORE"/>
          <Button Name="BtnStartNode" Content="START LENOVO NODE"/>
          <Button Name="BtnTestLink" Content="TEST 2-PC LINK"/>
          <Button Name="BtnRunInventory" Content="RUN SYSTEM INVENTORY"/>
          <Button Name="BtnDiagnostics" Content="DIAGNOSTICS"/>
          <Button Name="BtnRefreshHardware" Content="REFRESH THIS PC HARDWARE"/>
          <Button Name="BtnHardwareRegistry" Content="HARDWARE REGISTRY"/>
          <Button Name="BtnFinalAcceptance" Content="FINAL REAL-HARDWARE ACCEPTANCE"/>
          <Button Name="BtnResults" Content="OPEN RESULTS"/>
          <Button Name="BtnLogs" Content="OPEN LOGS"/>
        </StackPanel>
        <Border Grid.Row="3" BorderBrush="#3B321C" BorderThickness="1" Background="#0D1117" Padding="12">
          <StackPanel>
            <TextBlock Text="SECURITY GATE" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBlock Text="READ-ONLY" Foreground="{StaticResource Green}" FontWeight="Bold" Margin="0,4,0,0"/>
            <TextBlock Text="No shell · no arbitrary path · no token storage" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,4,0,0"/>
          </StackPanel>
        </Border>
      </Grid>
    </Border>

    <Grid Grid.Column="1" Margin="24">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock Text="RAVEN GRID CONTROL" FontSize="13" Foreground="{StaticResource Gold}"/>
          <TextBlock Text="HOVED-PC  ↔  LENOVO" FontSize="34" FontWeight="Bold" Foreground="#FFF5D8"/>
          <TextBlock Text="One-click control surface for the fixed Stable system.inventory route." Foreground="{StaticResource Muted}" FontSize="14"/>
        </StackPanel>
        <Border Grid.Column="1" Background="#111820" BorderBrush="#5D512E" BorderThickness="1" CornerRadius="18" Padding="16,9" VerticalAlignment="Top">
          <TextBlock Name="TxtOverall" Text="READY FOR PRECHECK" Foreground="{StaticResource Gold2}" FontWeight="Bold"/>
        </Border>
      </Grid>

      <UniformGrid Grid.Row="1" Columns="4" Margin="0,22,0,16">
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,10,0">
          <StackPanel><TextBlock Text="THIS PC" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtThisPc" Text="—" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,10,0">
          <StackPanel><TextBlock Text="RAVEN CORE :18765" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtRaven" Text="UNKNOWN" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,10,0">
          <StackPanel><TextBlock Text="NODE :18766" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtNode" Text="UNKNOWN" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16">
          <StackPanel><TextBlock Text="LAST INVENTORY" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtLast" Text="NONE" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
      </UniformGrid>

      <Border Grid.Row="2" Background="#0E1218" BorderBrush="#5A4B27" BorderThickness="1" CornerRadius="14" Padding="18" Margin="0,0,0,16">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="1.3*"/>
            <ColumnDefinition Width="1.4*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel Margin="0,0,12,0">
            <TextBlock Text="LENOVO TARGET" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBox Name="TxtTarget" Text="DESKTOP-R2HTAGJ" Margin="0,7,0,0"/>
            <TextBlock Name="TxtTargetHint" Text="LAN preferred · Node 1.4 Stable accepts RFC1918 requester sources" Foreground="{StaticResource Muted}" FontSize="11" Margin="0,4,0,0"/>
          </StackPanel>
          <StackPanel Grid.Column="1" Margin="0,0,12,0">
            <TextBlock Text="FRESH NODE TOKEN" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <PasswordBox Name="PwdToken" Margin="0,7,0,0"/>
            <TextBlock Text="Used in memory for HMAC proof, then cleared. Never written to disk." Foreground="{StaticResource Muted}" FontSize="11" Margin="0,4,0,0"/>
          </StackPanel>
          <Button Grid.Column="2" Name="BtnRunBig" Content="RUN SYSTEM INVENTORY" Padding="24,12" FontSize="15" VerticalAlignment="Center"/>
        </Grid>
      </Border>

      <Grid Grid.Row="3">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="1.1*"/>
          <ColumnDefinition Width="0.9*"/>
        </Grid.ColumnDefinitions>
        <Border Background="{StaticResource Panel2}" BorderBrush="#2C333C" BorderThickness="1" CornerRadius="14" Padding="18" Margin="0,0,12,0">
          <DockPanel>
            <TextBlock DockPanel.Dock="Top" Text="MISSION OUTPUT" Foreground="{StaticResource Gold}" FontWeight="Bold" Margin="0,0,0,10"/>
            <TextBox Name="TxtOutput" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" AcceptsReturn="True" FontFamily="Consolas" FontSize="12"/>
          </DockPanel>
        </Border>
        <Border Grid.Column="1" Background="{StaticResource Panel2}" BorderBrush="#2C333C" BorderThickness="1" CornerRadius="14" Padding="18">
          <StackPanel>
            <TextBlock Text="OPERATOR FLOW" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBlock Text="1 · Lenovo: START RAVEN CORE" Foreground="#ECE7DA" Margin="0,12,0,0"/>
            <TextBlock Text="2 · Lenovo: START LENOVO NODE" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <TextBlock Text="3 · Copy the fresh token shown locally" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <TextBlock Text="4 · HOVED-PC: TEST 2-PC LINK" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <TextBlock Text="5 · Paste token and RUN SYSTEM INVENTORY" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <Separator Margin="0,18,0,14" Background="#3B321C"/>
            <TextBlock Text="WHY ONE TOKEN PASTE?" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBlock Text="Node 1.4 deliberately keeps its fresh secret local. The GUI does not weaken that boundary just to remove one copy/paste." Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,7,0,0"/>
          </StackPanel>
        </Border>
      </Grid>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @('BtnOverview','BtnStartRaven','BtnStartNode','BtnTestLink','BtnRunInventory','BtnDiagnostics','BtnRefreshHardware','BtnHardwareRegistry','BtnFinalAcceptance','BtnResults','BtnLogs','BtnRunBig','TxtOverall','TxtThisPc','TxtRaven','TxtNode','TxtLast','TxtTarget','TxtTargetHint','PwdToken','TxtOutput')
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

function Set-Output {
    param([string]$Text,[switch]$Error)
    $script:TxtOutput.Text = $Text
    $script:TxtOverall.Text = if($Error){'ATTENTION REQUIRED'}else{'RAVEN GRID READY'}
    $script:TxtOverall.Foreground = if($Error){[Windows.Media.Brushes]::LightCoral}else{[Windows.Media.Brushes]::Khaki}
}

function Refresh-Overview {
    $script:TxtThisPc.Text = $env:COMPUTERNAME
    $raven = Test-TcpPort '127.0.0.1' 18765
    $nodeLocal = Test-TcpPort '127.0.0.1' 18766
    $script:TxtRaven.Text = if($raven){'ONLINE'}else{'OFFLINE'}
    $script:TxtRaven.Foreground = if($raven){[Windows.Media.Brushes]::LightGreen}else{[Windows.Media.Brushes]::LightCoral}
    $script:TxtNode.Text = if($nodeLocal){'LOCAL ONLINE'}else{'LOCAL OFFLINE'}
    $script:TxtNode.Foreground = if($nodeLocal){[Windows.Media.Brushes]::LightGreen}else{[Windows.Media.Brushes]::Gray}

    $ts = Get-LenovoTailscaleIp
    if (-not $script:TxtTarget.Text) {
        $script:TxtTarget.Text = $script:DefaultLenovoHost
    }
    if ($script:TxtTarget.Text -eq $script:DefaultLenovoHost -and -not (Test-TcpPort $script:DefaultLenovoHost 18766 700)) {
        if (Test-TcpPort $script:LastKnownLenovoLan 18766 700) {
            $script:TxtTarget.Text = $script:LastKnownLenovoLan
            $script:TxtTargetHint.Text = 'Lenovo hostname did not answer; using private LAN fallback'
        }
    }
    if ($ts -and $script:TxtTarget.Text -ne $script:LastKnownLenovoLan) {
        $script:TxtTargetHint.Text = 'Private LAN hostname preferred; Tailscale 100.64/10 stays outside Stable requester-source policy'
    }

    $last = Join-Path $script:Results 'last-inventory.json'
    if (Test-Path -LiteralPath $last) {
        try {
            $r = Get-Content -LiteralPath $last -Raw | ConvertFrom-Json
            $script:TxtLast.Text = ([string]$r.inventory.hostname + ' · PASS')
            $script:TxtLast.Foreground = [Windows.Media.Brushes]::LightGreen
        } catch {
            $script:TxtLast.Text = 'RESULT INVALID'
            $script:TxtLast.Foreground = [Windows.Media.Brushes]::LightCoral
        }
    }

    $diag = Write-Diagnostics $script:TxtTarget.Text
    $msg = @(
        'RAH RAVEN OS · 2-PC PRECHECK'
        '----------------------------------------'
        ('This PC          : ' + $diag.computerName)
        ('Runtime          : ' + $diag.runtime)
        ('Hardware registry: ' + $diag.hardwareRegistryExists)
        ('Local Raven      : ' + $diag.localRaven18765)
        ('Local Node       : ' + $diag.localNode18766)
        ('Lenovo target    : ' + $diag.target)
        ('Target :18766    : ' + $diag.targetNode18766)
        ('Tailscale detect : ' + $diag.tailscaleLenovoIp)
        ''
        'Security: fixed /raven/status -> system-inventory only.'
    ) -join [Environment]::NewLine
    Set-Output $msg
}

$script:BtnOverview.Add_Click({ try { Refresh-Overview } catch { Set-Output $_.Exception.Message -Error } })

$script:BtnStartRaven.Add_Click({
    try {
        $starter = Ensure-RepoFile 'START-RAH-AI-FABRIC.cmd'
        Start-Process -FilePath $starter -WorkingDirectory (Split-Path -Parent $starter)
        Write-RahLog 'Started RAH AI Fabric launcher.'
        Set-Output ('RAH Raven Core launcher started.' + [Environment]::NewLine + 'Wait for PASS on 127.0.0.1:18765, then refresh overview.')
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnStartNode.Add_Click({
    try {
        $starter = Ensure-RepoFile 'START-RAH-NODE-AGENT-V1.4.bat'
        $args = '/k ""{0}" --name "{1}" --role "worker" --capability compute"' -f $starter,$env:COMPUTERNAME
        Start-Process -FilePath 'cmd.exe' -ArgumentList $args -WorkingDirectory (Split-Path -Parent $starter)
        Write-RahLog 'Started Node Agent 1.4 Stable with compute capability.'
        Set-Output ('Lenovo Node Agent 1.4 Stable started with COMPUTE only.' + [Environment]::NewLine + 'Copy the fresh token from the Node console. The token is intentionally not stored.')
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnTestLink.Add_Click({
    try {
        $target = $script:TxtTarget.Text.Trim()
        if (-not $target) { throw 'Target address is empty.' }
        $ok = Test-TcpPort $target 18766 1800
        if ($ok) {
            Set-Output ('PASS: Node port 18766 reachable on ' + $target + '.' + [Environment]::NewLine + 'Next: paste fresh token and run SYSTEM INVENTORY.')
        } else {
            Set-Output ('FAIL: Cannot reach ' + $target + ':18766.' + [Environment]::NewLine + 'Check that Node Agent 1.4 is running on Lenovo and Windows/Tailscale networking allows the private connection.') -Error
        }
    } catch { Set-Output $_.Exception.Message -Error }
})

$runInventoryAction = {
    try {
        $target = $script:TxtTarget.Text.Trim()
        $token = $script:PwdToken.Password
        $script:TxtOverall.Text = 'RUNNING SYSTEM INVENTORY...'
        $script:TxtOutput.Text = 'Authenticating Node with single-use nonce + HMAC-SHA256 proof...'
        $result = Invoke-InventoryClient $target $token
        $script:PwdToken.Clear()
        $i = $result.inventory
        $lines = @(
            'RAH RAVEN 2-PC INVENTORY · PASS'
            '========================================'
            ('HOST      : ' + [string]$i.hostname)
            ('OS        : ' + [string]$i.os.system + ' ' + [string]$i.os.release + ' ' + [string]$i.os.architecture)
            ('CPU       : ' + [string]$i.cpu.name)
            ('CORES     : ' + [string]$i.cpu.logical_cores)
            ('RAM       : ' + [string]$i.ram_gb + ' GB')
            ('GPU       : ' + ((@($i.gpus) -join ', ')))
            ('MONITORS  : ' + [string]$i.monitor_count)
            ('RAVEN     : v' + [string]$i.raven_bridge.version + ' / port ' + [string]$i.raven_bridge.port)
            ''
            'SECURITY'
            'Read-only          : TRUE'
            'Arbitrary commands : FALSE'
            'Caller arguments   : FALSE'
            'Token persisted    : FALSE'
            'Local Raven hop    : TRUE'
            ''
            ('Saved: ' + (Join-Path $script:Results 'last-inventory.json'))
        )
        $script:TxtLast.Text = ([string]$i.hostname + ' · PASS')
        $script:TxtLast.Foreground = [Windows.Media.Brushes]::LightGreen
        Set-Output ($lines -join [Environment]::NewLine)
    } catch {
        $script:PwdToken.Clear()
        Set-Output $_.Exception.Message -Error
    }
}
$script:BtnRunBig.Add_Click($runInventoryAction)
$script:BtnRunInventory.Add_Click($runInventoryAction)

$script:BtnDiagnostics.Add_Click({
    try {
        $diag = Write-Diagnostics $script:TxtTarget.Text.Trim()
        Set-Output (($diag | ConvertTo-Json -Depth 8) + [Environment]::NewLine + [Environment]::NewLine + 'Saved: ' + (Join-Path $script:Logs 'last-diagnostics.json'))
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnRefreshHardware.Add_Click({
    try {
        $update = Update-LocalHardwareRegistry
        Set-Output ('PASS: This PC hardware profile refreshed.' + [Environment]::NewLine +
                    'Device: ' + [string]$update.hostname + [Environment]::NewLine +
                    'Changed: ' + [string]$update.changed + [Environment]::NewLine +
                    'Registry: ' + [string]$update.registryPath)
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnHardwareRegistry.Add_Click({
    $registryRoot = 'C:\RAH\HardwareRegistry'
    New-Item -ItemType Directory -Force -Path $registryRoot | Out-Null
    Start-Process explorer.exe $registryRoot
})

$script:BtnFinalAcceptance.Add_Click({
    try {
        $report = Invoke-FinalAcceptance
        $script:TxtOverall.Text = 'REAL-HARDWARE PASS'
        $script:TxtOverall.Foreground = [Windows.Media.Brushes]::LightGreen
        Set-Output ((
            'RAH RAVEN 2-PC GRID · REAL-HARDWARE ACCEPTANCE PASS' + [Environment]::NewLine +
            '=====================================================' + [Environment]::NewLine +
            'Lenovo host : ' + [string]$report.evidence.hostname + [Environment]::NewLine +
            'Target      : ' + [string]$report.evidence.targetHost + ':' + [string]$report.evidence.targetPort + [Environment]::NewLine +
            'Raven       : localhost:' + [string]$report.evidence.ravenPort + [Environment]::NewLine +
            'Read-only   : TRUE' + [Environment]::NewLine +
            'No shell    : TRUE' + [Environment]::NewLine +
            'Token saved : FALSE' + [Environment]::NewLine + [Environment]::NewLine +
            'Evidence: ' + (Join-Path $script:Results 'REAL-HARDWARE-ACCEPTANCE.json')
        ))
        $script:TxtOverall.Text = 'REAL-HARDWARE PASS'
        $script:TxtOverall.Foreground = [Windows.Media.Brushes]::LightGreen
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnResults.Add_Click({ Start-Process explorer.exe $script:Results })
$script:BtnLogs.Add_Click({ Start-Process explorer.exe $script:Logs })

$window.Add_ContentRendered({
    try {
        try { $null = Update-LocalHardwareRegistry } catch { Write-RahLog ('Local hardware registry startup refresh warning: ' + $_.Exception.Message) }
        Refresh-Overview
    } catch { Set-Output $_.Exception.Message -Error }
})

Write-RahLog ('GUI started on ' + $env:COMPUTERNAME)
$null = $window.ShowDialog()
) {
            $script:SourceRef = $candidateRef
        }
    } catch {}
}

New-Item -ItemType Directory -Force -Path $script:Root,$script:Results,$script:Logs | Out-Null

function Write-RahLog {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date).ToUniversalTime().ToString('o'), $Message
    [IO.File]::AppendAllText((Join-Path $script:Logs 'rah-2pc-gui.log'), $line + [Environment]::NewLine, $script:Utf8)
}

function Test-TcpPort {
    param([string]$HostName,[int]$Port,[int]$TimeoutMs=1200)
    try {
        $client = New-Object Net.Sockets.TcpClient
        try {
            $ar = $client.BeginConnect($HostName,$Port,$null,$null)
            if (-not $ar.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
            $client.EndConnect($ar)
            return $true
        } finally {
            $client.Dispose()
        }
    } catch { return $false }
}

function Get-LenovoTailscaleIp {
    $ts = Get-Command tailscale.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ts) { return $null }
    try {
        $raw = & $ts.Source status --json 2>$null | Out-String
        if (-not $raw.Trim()) { return $null }
        $obj = $raw | ConvertFrom-Json
        if ($obj.Peer) {
            foreach ($prop in $obj.Peer.PSObject.Properties) {
                $peer = $prop.Value
                $name = ([string]$peer.HostName + ' ' + [string]$peer.DNSName).ToUpperInvariant()
                if ($name -match 'DESKTOP-R2HTAGJ|LENOVO') {
                    $ips = @($peer.TailscaleIPs)
                    if ($ips.Count -and $ips[0]) { return [string]$ips[0] }
                }
            }
        }
    } catch {}
    return $null
}

function Find-RepoFile {
    param([string]$Name)
    $candidates = @(
        (Join-Path $script:ScriptDir $Name),
        (Join-Path 'C:\RAH\rah-platform' $Name),
        (Join-Path 'C:\RAH\RAH-Platform' $Name),
        (Join-Path $script:RepoCache ('rah-platform-main\' + $Name))
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p -PathType Leaf) { return [IO.Path]::GetFullPath($p) }
    }
    return $null
}

function Sync-RahRepo {
    $zip = Join-Path $script:RepoCache 'rah-platform-main.zip'
    $dest = Join-Path $script:RepoCache 'rah-platform-main'
    New-Item -ItemType Directory -Force -Path $script:RepoCache | Out-Null
    Write-RahLog 'Repo sync requested.'
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/NilsRa73/rah-platform/archive/refs/heads/main.zip' -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $script:RepoCache -Force
    if (-not (Test-Path -LiteralPath $dest -PathType Container)) { throw 'RAH repo package did not extract correctly.' }
    Write-RahLog 'Repo sync PASS.'
    return $dest
}

function Ensure-RepoFile {
    param([string]$Name)
    $p = Find-RepoFile $Name
    if ($p) { return $p }
    $null = Sync-RahRepo
    $p = Find-RepoFile $Name
    if (-not $p) { throw "Required RAH file missing after repo sync: $Name" }
    return $p
}

function Write-Diagnostics {
    param([string]$Target)
    $ts = Get-LenovoTailscaleIp
    $registryPath = 'C:\RAH\HardwareRegistry\registry.json'
    $doc = [ordered]@{
        schema = 'rah-2pc-gui-diagnostics-v1'
        version = $script:Version
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
        computerName = $env:COMPUTERNAME
        target = $Target
        runtime = 'Windows PowerShell/.NET - Python not required'
        hardwareRegistry = $registryPath
        hardwareRegistryExists = (Test-Path -LiteralPath $registryPath -PathType Leaf)
        tailscaleLenovoIp = if($ts){$ts}else{'NOT_DETECTED'}
        localRaven18765 = Test-TcpPort '127.0.0.1' 18765
        localNode18766 = Test-TcpPort '127.0.0.1' 18766
        targetNode18766 = if($Target){Test-TcpPort $Target 18766}else{$false}
        tokenCollected = $false
        arbitraryShell = $false
        remoteRoute = '/raven/status'
        remoteCapability = 'system-inventory'
    }
    $path = Join-Path $script:Logs 'last-diagnostics.json'
    [IO.File]::WriteAllText($path, ($doc | ConvertTo-Json -Depth 8), $script:Utf8)
    return $doc
}

function Update-LocalHardwareRegistry {
    $inventoryScript = Ensure-RepoFile 'RAH-HARDWARE-INVENTORY.ps1'
    $registryScript = Ensure-RepoFile 'RAH-HARDWARE-REGISTRY.ps1'
    . $inventoryScript
    . $registryScript
    $profile = Get-RahHardwareInventory
    $update = Update-RahHardwareRegistry -Profile $profile -Source '2pc-gui-local'
    Write-RahLog ('Local hardware registry updated: ' + [string]$update.deviceId + ' changed=' + [string]$update.changed)
    return $update
}

function Import-RemoteHardwareProfile {
    param($Result)
    if ($null -eq $Result.inventory -or $null -eq $Result.inventory.hardware_profile) { return $null }
    if ([string]$Result.inventory.hardware_profile.schema -ne 'rah-hardware-profile-v1') { throw 'Remote detailed hardware profile schema invalid.' }
    $registryScript = Ensure-RepoFile 'RAH-HARDWARE-REGISTRY.ps1'
    . $registryScript
    $update = Update-RahHardwareRegistry -Profile $Result.inventory.hardware_profile -Source 'remote-raven-system-inventory'
    Write-RahLog ('Remote hardware registry updated: ' + [string]$update.deviceId + ' changed=' + [string]$update.changed)
    return $update
}

function Invoke-InventoryClient {
    param([string]$Target,[string]$Token)
    if (-not $Target) { throw 'Velg Lenovo-adresse først.' }
    if (-not $Token -or $Token.Length -lt 24) { throw 'Lim inn fersk Node-token fra Lenovo.' }

    $client = Ensure-RepoFile 'RAH-2PC-CLIENT.ps1'
    . $client
    $out = Join-Path $script:Results 'last-inventory.json'
    $result = Invoke-Rah2PcInventory -TargetHost $Target -Token $Token -OutputPath $out
    if ([string]$result.status -ne 'PASS') { throw 'Inventory result did not contain PASS.' }
    $null = Import-RemoteHardwareProfile -Result $result
    Write-RahLog ('Inventory PASS from ' + [string]$result.inventory.hostname)
    return $result
}

function Invoke-FinalAcceptance {
    $validator = Ensure-RepoFile 'RAH-2PC-ACCEPTANCE.ps1'
    . $validator
    $input = Join-Path $script:Results 'last-inventory.json'
    $output = Join-Path $script:Results 'REAL-HARDWARE-ACCEPTANCE.json'
    if (-not (Test-Path -LiteralPath $input -PathType Leaf)) { throw 'Kjør SYSTEM INVENTORY først. last-inventory.json mangler.' }
    $report = Invoke-Rah2PcFinalAcceptance -SourcePath $input -DestinationPath $output -FixedExpectedHost 'DESKTOP-R2HTAGJ'
    if ([string]$report.overall -ne 'PASS') { throw 'Acceptance report did not contain PASS.' }
    Write-RahLog 'Real-hardware acceptance PASS.'
    return $report
}

function Invoke-SelfTest {
    $client = Join-Path $script:ScriptDir 'RAH-2PC-CLIENT.ps1'
    $acceptance = Join-Path $script:ScriptDir 'RAH-2PC-ACCEPTANCE.ps1'
    $inventory = Join-Path $script:ScriptDir 'RAH-HARDWARE-INVENTORY.ps1'
    $registry = Join-Path $script:ScriptDir 'RAH-HARDWARE-REGISTRY.ps1'
    foreach($path in @($client,$acceptance,$inventory,$registry)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('Required self-test file missing: ' + $path) }
    }
    . $client
    . $acceptance
    . $inventory
    . $registry
    Test-Rah2PcClient
    Test-Rah2PcAcceptance
    Test-RahHardwareInventory
    Test-RahHardwareRegistry
    Write-Host 'PASS: RAH Raven 2-PC GUI launcher contract - Python free' -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

if ($env:OS -ne 'Windows_NT') { throw 'RAH Raven 2-PC GUI requires Windows.' }

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RAH Raven OS · 2-PC Grid" Width="1320" Height="820"
        MinWidth="1100" MinHeight="720" WindowStartupLocation="CenterScreen"
        Background="#07090C" Foreground="#F4E8C2" FontFamily="Segoe UI">
  <Window.Resources>
    <SolidColorBrush x:Key="Gold" Color="#D9B65B"/>
    <SolidColorBrush x:Key="Gold2" Color="#F0D989"/>
    <SolidColorBrush x:Key="Panel" Color="#10141A"/>
    <SolidColorBrush x:Key="Panel2" Color="#0B0E13"/>
    <SolidColorBrush x:Key="Muted" Color="#87909C"/>
    <SolidColorBrush x:Key="Green" Color="#6CE0A3"/>
    <SolidColorBrush x:Key="Red" Color="#FF7E7E"/>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#11161D"/>
      <Setter Property="Foreground" Value="{StaticResource Gold2}"/>
      <Setter Property="BorderBrush" Value="#6A5728"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="14,10"/>
      <Setter Property="Margin" Value="0,0,8,8"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#090C10"/>
      <Setter Property="Foreground" Value="#F5F1E7"/>
      <Setter Property="BorderBrush" Value="#4C4328"/>
      <Setter Property="Padding" Value="10"/>
    </Style>
    <Style TargetType="PasswordBox">
      <Setter Property="Background" Value="#090C10"/>
      <Setter Property="Foreground" Value="#F5F1E7"/>
      <Setter Property="BorderBrush" Value="#4C4328"/>
      <Setter Property="Padding" Value="10"/>
    </Style>
  </Window.Resources>
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="235"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <Border Grid.Column="0" Background="#090C11" BorderBrush="#3B321C" BorderThickness="0,0,1,0">
      <Grid Margin="18">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel>
          <TextBlock Text="ᚱ" FontSize="56" Foreground="{StaticResource Gold2}" HorizontalAlignment="Center"/>
          <TextBlock Text="RAH RAVEN OS" FontSize="20" FontWeight="Bold" Foreground="{StaticResource Gold2}" HorizontalAlignment="Center"/>
          <TextBlock Text="2-PC GRID · v1" FontSize="12" Foreground="{StaticResource Muted}" HorizontalAlignment="Center" Margin="0,4,0,20"/>
        </StackPanel>
        <StackPanel Grid.Row="1">
          <Button Name="BtnOverview" Content="OVERVIEW / PRECHECK"/>
          <Button Name="BtnStartRaven" Content="START RAVEN CORE"/>
          <Button Name="BtnStartNode" Content="START LENOVO NODE"/>
          <Button Name="BtnTestLink" Content="TEST 2-PC LINK"/>
          <Button Name="BtnRunInventory" Content="RUN SYSTEM INVENTORY"/>
          <Button Name="BtnDiagnostics" Content="DIAGNOSTICS"/>
          <Button Name="BtnRefreshHardware" Content="REFRESH THIS PC HARDWARE"/>
          <Button Name="BtnHardwareRegistry" Content="HARDWARE REGISTRY"/>
          <Button Name="BtnFinalAcceptance" Content="FINAL REAL-HARDWARE ACCEPTANCE"/>
          <Button Name="BtnResults" Content="OPEN RESULTS"/>
          <Button Name="BtnLogs" Content="OPEN LOGS"/>
        </StackPanel>
        <Border Grid.Row="3" BorderBrush="#3B321C" BorderThickness="1" Background="#0D1117" Padding="12">
          <StackPanel>
            <TextBlock Text="SECURITY GATE" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBlock Text="READ-ONLY" Foreground="{StaticResource Green}" FontWeight="Bold" Margin="0,4,0,0"/>
            <TextBlock Text="No shell · no arbitrary path · no token storage" Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,4,0,0"/>
          </StackPanel>
        </Border>
      </Grid>
    </Border>

    <Grid Grid.Column="1" Margin="24">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock Text="RAVEN GRID CONTROL" FontSize="13" Foreground="{StaticResource Gold}"/>
          <TextBlock Text="HOVED-PC  ↔  LENOVO" FontSize="34" FontWeight="Bold" Foreground="#FFF5D8"/>
          <TextBlock Text="One-click control surface for the fixed Stable system.inventory route." Foreground="{StaticResource Muted}" FontSize="14"/>
        </StackPanel>
        <Border Grid.Column="1" Background="#111820" BorderBrush="#5D512E" BorderThickness="1" CornerRadius="18" Padding="16,9" VerticalAlignment="Top">
          <TextBlock Name="TxtOverall" Text="READY FOR PRECHECK" Foreground="{StaticResource Gold2}" FontWeight="Bold"/>
        </Border>
      </Grid>

      <UniformGrid Grid.Row="1" Columns="4" Margin="0,22,0,16">
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,10,0">
          <StackPanel><TextBlock Text="THIS PC" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtThisPc" Text="—" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,10,0">
          <StackPanel><TextBlock Text="RAVEN CORE :18765" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtRaven" Text="UNKNOWN" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16" Margin="0,0,10,0">
          <StackPanel><TextBlock Text="NODE :18766" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtNode" Text="UNKNOWN" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
        <Border Background="{StaticResource Panel}" BorderBrush="#2E3540" BorderThickness="1" CornerRadius="12" Padding="16">
          <StackPanel><TextBlock Text="LAST INVENTORY" Foreground="{StaticResource Muted}"/><TextBlock Name="TxtLast" Text="NONE" FontSize="18" FontWeight="Bold" Margin="0,4,0,0"/></StackPanel>
        </Border>
      </UniformGrid>

      <Border Grid.Row="2" Background="#0E1218" BorderBrush="#5A4B27" BorderThickness="1" CornerRadius="14" Padding="18" Margin="0,0,0,16">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="1.3*"/>
            <ColumnDefinition Width="1.4*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel Margin="0,0,12,0">
            <TextBlock Text="LENOVO TARGET" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBox Name="TxtTarget" Text="DESKTOP-R2HTAGJ" Margin="0,7,0,0"/>
            <TextBlock Name="TxtTargetHint" Text="LAN preferred · Node 1.4 Stable accepts RFC1918 requester sources" Foreground="{StaticResource Muted}" FontSize="11" Margin="0,4,0,0"/>
          </StackPanel>
          <StackPanel Grid.Column="1" Margin="0,0,12,0">
            <TextBlock Text="FRESH NODE TOKEN" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <PasswordBox Name="PwdToken" Margin="0,7,0,0"/>
            <TextBlock Text="Used in memory for HMAC proof, then cleared. Never written to disk." Foreground="{StaticResource Muted}" FontSize="11" Margin="0,4,0,0"/>
          </StackPanel>
          <Button Grid.Column="2" Name="BtnRunBig" Content="RUN SYSTEM INVENTORY" Padding="24,12" FontSize="15" VerticalAlignment="Center"/>
        </Grid>
      </Border>

      <Grid Grid.Row="3">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="1.1*"/>
          <ColumnDefinition Width="0.9*"/>
        </Grid.ColumnDefinitions>
        <Border Background="{StaticResource Panel2}" BorderBrush="#2C333C" BorderThickness="1" CornerRadius="14" Padding="18" Margin="0,0,12,0">
          <DockPanel>
            <TextBlock DockPanel.Dock="Top" Text="MISSION OUTPUT" Foreground="{StaticResource Gold}" FontWeight="Bold" Margin="0,0,0,10"/>
            <TextBox Name="TxtOutput" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" AcceptsReturn="True" FontFamily="Consolas" FontSize="12"/>
          </DockPanel>
        </Border>
        <Border Grid.Column="1" Background="{StaticResource Panel2}" BorderBrush="#2C333C" BorderThickness="1" CornerRadius="14" Padding="18">
          <StackPanel>
            <TextBlock Text="OPERATOR FLOW" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBlock Text="1 · Lenovo: START RAVEN CORE" Foreground="#ECE7DA" Margin="0,12,0,0"/>
            <TextBlock Text="2 · Lenovo: START LENOVO NODE" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <TextBlock Text="3 · Copy the fresh token shown locally" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <TextBlock Text="4 · HOVED-PC: TEST 2-PC LINK" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <TextBlock Text="5 · Paste token and RUN SYSTEM INVENTORY" Foreground="#ECE7DA" Margin="0,7,0,0"/>
            <Separator Margin="0,18,0,14" Background="#3B321C"/>
            <TextBlock Text="WHY ONE TOKEN PASTE?" Foreground="{StaticResource Gold}" FontWeight="Bold"/>
            <TextBlock Text="Node 1.4 deliberately keeps its fresh secret local. The GUI does not weaken that boundary just to remove one copy/paste." Foreground="{StaticResource Muted}" TextWrapping="Wrap" Margin="0,7,0,0"/>
          </StackPanel>
        </Border>
      </Grid>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @('BtnOverview','BtnStartRaven','BtnStartNode','BtnTestLink','BtnRunInventory','BtnDiagnostics','BtnRefreshHardware','BtnHardwareRegistry','BtnFinalAcceptance','BtnResults','BtnLogs','BtnRunBig','TxtOverall','TxtThisPc','TxtRaven','TxtNode','TxtLast','TxtTarget','TxtTargetHint','PwdToken','TxtOutput')
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

function Set-Output {
    param([string]$Text,[switch]$Error)
    $script:TxtOutput.Text = $Text
    $script:TxtOverall.Text = if($Error){'ATTENTION REQUIRED'}else{'RAVEN GRID READY'}
    $script:TxtOverall.Foreground = if($Error){[Windows.Media.Brushes]::LightCoral}else{[Windows.Media.Brushes]::Khaki}
}

function Refresh-Overview {
    $script:TxtThisPc.Text = $env:COMPUTERNAME
    $raven = Test-TcpPort '127.0.0.1' 18765
    $nodeLocal = Test-TcpPort '127.0.0.1' 18766
    $script:TxtRaven.Text = if($raven){'ONLINE'}else{'OFFLINE'}
    $script:TxtRaven.Foreground = if($raven){[Windows.Media.Brushes]::LightGreen}else{[Windows.Media.Brushes]::LightCoral}
    $script:TxtNode.Text = if($nodeLocal){'LOCAL ONLINE'}else{'LOCAL OFFLINE'}
    $script:TxtNode.Foreground = if($nodeLocal){[Windows.Media.Brushes]::LightGreen}else{[Windows.Media.Brushes]::Gray}

    $ts = Get-LenovoTailscaleIp
    if (-not $script:TxtTarget.Text) {
        $script:TxtTarget.Text = $script:DefaultLenovoHost
    }
    if ($script:TxtTarget.Text -eq $script:DefaultLenovoHost -and -not (Test-TcpPort $script:DefaultLenovoHost 18766 700)) {
        if (Test-TcpPort $script:LastKnownLenovoLan 18766 700) {
            $script:TxtTarget.Text = $script:LastKnownLenovoLan
            $script:TxtTargetHint.Text = 'Lenovo hostname did not answer; using private LAN fallback'
        }
    }
    if ($ts -and $script:TxtTarget.Text -ne $script:LastKnownLenovoLan) {
        $script:TxtTargetHint.Text = 'Private LAN hostname preferred; Tailscale 100.64/10 stays outside Stable requester-source policy'
    }

    $last = Join-Path $script:Results 'last-inventory.json'
    if (Test-Path -LiteralPath $last) {
        try {
            $r = Get-Content -LiteralPath $last -Raw | ConvertFrom-Json
            $script:TxtLast.Text = ([string]$r.inventory.hostname + ' · PASS')
            $script:TxtLast.Foreground = [Windows.Media.Brushes]::LightGreen
        } catch {
            $script:TxtLast.Text = 'RESULT INVALID'
            $script:TxtLast.Foreground = [Windows.Media.Brushes]::LightCoral
        }
    }

    $diag = Write-Diagnostics $script:TxtTarget.Text
    $msg = @(
        'RAH RAVEN OS · 2-PC PRECHECK'
        '----------------------------------------'
        ('This PC          : ' + $diag.computerName)
        ('Runtime          : ' + $diag.runtime)
        ('Hardware registry: ' + $diag.hardwareRegistryExists)
        ('Local Raven      : ' + $diag.localRaven18765)
        ('Local Node       : ' + $diag.localNode18766)
        ('Lenovo target    : ' + $diag.target)
        ('Target :18766    : ' + $diag.targetNode18766)
        ('Tailscale detect : ' + $diag.tailscaleLenovoIp)
        ''
        'Security: fixed /raven/status -> system-inventory only.'
    ) -join [Environment]::NewLine
    Set-Output $msg
}

$script:BtnOverview.Add_Click({ try { Refresh-Overview } catch { Set-Output $_.Exception.Message -Error } })

$script:BtnStartRaven.Add_Click({
    try {
        $starter = Ensure-RepoFile 'START-RAH-AI-FABRIC.cmd'
        Start-Process -FilePath $starter -WorkingDirectory (Split-Path -Parent $starter)
        Write-RahLog 'Started RAH AI Fabric launcher.'
        Set-Output ('RAH Raven Core launcher started.' + [Environment]::NewLine + 'Wait for PASS on 127.0.0.1:18765, then refresh overview.')
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnStartNode.Add_Click({
    try {
        $starter = Ensure-RepoFile 'START-RAH-NODE-AGENT-V1.4.bat'
        $args = '/k ""{0}" --name "{1}" --role "worker" --capability compute"' -f $starter,$env:COMPUTERNAME
        Start-Process -FilePath 'cmd.exe' -ArgumentList $args -WorkingDirectory (Split-Path -Parent $starter)
        Write-RahLog 'Started Node Agent 1.4 Stable with compute capability.'
        Set-Output ('Lenovo Node Agent 1.4 Stable started with COMPUTE only.' + [Environment]::NewLine + 'Copy the fresh token from the Node console. The token is intentionally not stored.')
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnTestLink.Add_Click({
    try {
        $target = $script:TxtTarget.Text.Trim()
        if (-not $target) { throw 'Target address is empty.' }
        $ok = Test-TcpPort $target 18766 1800
        if ($ok) {
            Set-Output ('PASS: Node port 18766 reachable on ' + $target + '.' + [Environment]::NewLine + 'Next: paste fresh token and run SYSTEM INVENTORY.')
        } else {
            Set-Output ('FAIL: Cannot reach ' + $target + ':18766.' + [Environment]::NewLine + 'Check that Node Agent 1.4 is running on Lenovo and Windows/Tailscale networking allows the private connection.') -Error
        }
    } catch { Set-Output $_.Exception.Message -Error }
})

$runInventoryAction = {
    try {
        $target = $script:TxtTarget.Text.Trim()
        $token = $script:PwdToken.Password
        $script:TxtOverall.Text = 'RUNNING SYSTEM INVENTORY...'
        $script:TxtOutput.Text = 'Authenticating Node with single-use nonce + HMAC-SHA256 proof...'
        $result = Invoke-InventoryClient $target $token
        $script:PwdToken.Clear()
        $i = $result.inventory
        $lines = @(
            'RAH RAVEN 2-PC INVENTORY · PASS'
            '========================================'
            ('HOST      : ' + [string]$i.hostname)
            ('OS        : ' + [string]$i.os.system + ' ' + [string]$i.os.release + ' ' + [string]$i.os.architecture)
            ('CPU       : ' + [string]$i.cpu.name)
            ('CORES     : ' + [string]$i.cpu.logical_cores)
            ('RAM       : ' + [string]$i.ram_gb + ' GB')
            ('GPU       : ' + ((@($i.gpus) -join ', ')))
            ('MONITORS  : ' + [string]$i.monitor_count)
            ('RAVEN     : v' + [string]$i.raven_bridge.version + ' / port ' + [string]$i.raven_bridge.port)
            ''
            'SECURITY'
            'Read-only          : TRUE'
            'Arbitrary commands : FALSE'
            'Caller arguments   : FALSE'
            'Token persisted    : FALSE'
            'Local Raven hop    : TRUE'
            ''
            ('Saved: ' + (Join-Path $script:Results 'last-inventory.json'))
        )
        $script:TxtLast.Text = ([string]$i.hostname + ' · PASS')
        $script:TxtLast.Foreground = [Windows.Media.Brushes]::LightGreen
        Set-Output ($lines -join [Environment]::NewLine)
    } catch {
        $script:PwdToken.Clear()
        Set-Output $_.Exception.Message -Error
    }
}
$script:BtnRunBig.Add_Click($runInventoryAction)
$script:BtnRunInventory.Add_Click($runInventoryAction)

$script:BtnDiagnostics.Add_Click({
    try {
        $diag = Write-Diagnostics $script:TxtTarget.Text.Trim()
        Set-Output (($diag | ConvertTo-Json -Depth 8) + [Environment]::NewLine + [Environment]::NewLine + 'Saved: ' + (Join-Path $script:Logs 'last-diagnostics.json'))
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnRefreshHardware.Add_Click({
    try {
        $update = Update-LocalHardwareRegistry
        Set-Output ('PASS: This PC hardware profile refreshed.' + [Environment]::NewLine +
                    'Device: ' + [string]$update.hostname + [Environment]::NewLine +
                    'Changed: ' + [string]$update.changed + [Environment]::NewLine +
                    'Registry: ' + [string]$update.registryPath)
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnHardwareRegistry.Add_Click({
    $registryRoot = 'C:\RAH\HardwareRegistry'
    New-Item -ItemType Directory -Force -Path $registryRoot | Out-Null
    Start-Process explorer.exe $registryRoot
})

$script:BtnFinalAcceptance.Add_Click({
    try {
        $report = Invoke-FinalAcceptance
        $script:TxtOverall.Text = 'REAL-HARDWARE PASS'
        $script:TxtOverall.Foreground = [Windows.Media.Brushes]::LightGreen
        Set-Output ((
            'RAH RAVEN 2-PC GRID · REAL-HARDWARE ACCEPTANCE PASS' + [Environment]::NewLine +
            '=====================================================' + [Environment]::NewLine +
            'Lenovo host : ' + [string]$report.evidence.hostname + [Environment]::NewLine +
            'Target      : ' + [string]$report.evidence.targetHost + ':' + [string]$report.evidence.targetPort + [Environment]::NewLine +
            'Raven       : localhost:' + [string]$report.evidence.ravenPort + [Environment]::NewLine +
            'Read-only   : TRUE' + [Environment]::NewLine +
            'No shell    : TRUE' + [Environment]::NewLine +
            'Token saved : FALSE' + [Environment]::NewLine + [Environment]::NewLine +
            'Evidence: ' + (Join-Path $script:Results 'REAL-HARDWARE-ACCEPTANCE.json')
        ))
        $script:TxtOverall.Text = 'REAL-HARDWARE PASS'
        $script:TxtOverall.Foreground = [Windows.Media.Brushes]::LightGreen
    } catch { Set-Output $_.Exception.Message -Error }
})

$script:BtnResults.Add_Click({ Start-Process explorer.exe $script:Results })
$script:BtnLogs.Add_Click({ Start-Process explorer.exe $script:Logs })

$window.Add_ContentRendered({
    try {
        try { $null = Update-LocalHardwareRegistry } catch { Write-RahLog ('Local hardware registry startup refresh warning: ' + $_.Exception.Message) }
        Refresh-Overview
    } catch { Set-Output $_.Exception.Message -Error }
})

Write-RahLog ('GUI started on ' + $env:COMPUTERNAME)
$null = $window.ShowDialog()

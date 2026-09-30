Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$script:Version = '0.7.0-gold-candidate'
$script:RahRoot = 'C:\RAH'
$script:OsRoot = 'C:\RAH\RavenOS'
$script:LogRoot = Join-Path $script:OsRoot 'logs'
$script:LogFile = Join-Path $script:LogRoot 'rah-os.log'
$script:StateRoot = Join-Path $script:OsRoot 'state'
New-Item -ItemType Directory -Force -Path $script:OsRoot,$script:LogRoot,$script:StateRoot | Out-Null

function Write-RahOsLog {
    param([string]$Message)
    $line = ('{0}  {1}' -f (Get-Date).ToString('s'), $Message)
    Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
}

function Find-RahFile {
    param([Parameter(Mandatory=$true)][string]$Name,[string[]]$ExtraRoots=@())
    $roots = @(
        $PSScriptRoot,
        'C:\RAH',
        'C:\RAH\RavenOS',
        'C:\RAH\RavenCore7',
        'C:\RAH\rah-platform',
        'C:\RAH\RAH-Platform',
        'C:\RAH\2PCProof',
        'C:\RAH\raven-command-core\desktop-bridge',
        'C:\RAH\RavenCommand\desktop-bridge'
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
        if($ok -and $client.Connected){
            $client.EndConnect($iar)
            $client.Close()
            return $true
        }
        $client.Close()
    } catch {}
    return $false
}

function Read-JsonValue {
    param([string]$Path,[string]$Property,[string]$Fallback='NOT RUN')
    if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return $Fallback }
    try {
        $doc = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
        $value = $doc.$Property
        if($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)){ return $Fallback }
        return [string]$value
    } catch { return 'INVALID' }
}

function Get-RahOsStatus {
    $cc = Find-RahFile 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
    $fabric = Find-RahFile 'START-RAH-AI-FABRIC.cmd'
    $grid = Find-RahFile 'START-HER-RAH-2PC-GRID.cmd'
    $verify = Find-RahFile 'VERIFY-RAH-2PC-GRID.cmd'
    $gridInstall = Find-RahFile 'INSTALL-RAH-2PC-GRID.cmd'
    $selfTest = Find-RahFile 'RAH-OS-SELFTEST.ps1'
    $repair = Find-RahFile 'REPAIR-RAH-OS.cmd'
    $workspace = Find-RahFile 'Start RAH Workspace.cmd' @('C:\RAH\raven-command-core\desktop-bridge','C:\RAH\RavenCommand\desktop-bridge')
    $core7 = Find-RahFile 'START-HER.cmd' @('C:\RAH')
    $core7Diag = Find-RahFile 'DIAGNOSTICS.cmd' @('C:\RAH')
    $workerProof = Find-RahFile 'WORKER-PROOF.cmd' @('C:\RAH')
    $aiSelfCheck = Find-RahFile 'RAVEN-AI-SELF-CHECK.cmd' @('C:\RAH')
    $anythingApproval = Find-RahFile 'START-HER-ANYTHINGLLM-APPROVAL.cmd' @('C:\RAH')
    $acceptance = Find-RahFile 'RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd' @('C:\RAH\RavenOS')

    $acceptanceState = Read-JsonValue 'C:\RAH\RavenOS\state\RAH-OS-ACCEPTANCE.json' 'overall' 'NOT RUN'
    $workerProofState = Read-JsonValue 'C:\RAH\RavenCore7\state\worker-proof.json' 'state' 'NOT RUN'
    $core7Fallback = if($core7){'READY / NOT RUN YET'}else{'NOT INSTALLED'}
    $core7State = Read-JsonValue 'C:\RAH\RavenCore7\state\status.json' 'overall' $core7Fallback

    [pscustomobject][ordered]@{
        Version = $script:Version
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        RavenCore18765 = Test-LocalPort 18765
        NodeAgent18766 = Test-LocalPort 18766
        DesktopBridge47824 = Test-LocalPort 47824
        LmStudio1234 = Test-LocalPort 1234
        Ollama11434 = Test-LocalPort 11434
        CommandCenter = $cc
        AiFabric = $fabric
        Grid = $grid
        GridVerify = $verify
        GridInstaller = $gridInstall
        SelfTest = $selfTest
        RepairLauncher = $repair
        RavenWorkspace = $workspace
        Core7Launcher = $core7
        Core7Diagnostics = $core7Diag
        WorkerProof = $workerProof
        WorkerProofState = $workerProofState
        AiSelfCheck = $aiSelfCheck
        AnythingApproval = $anythingApproval
        AcceptanceLauncher = $acceptance
        AcceptanceState = $acceptanceState
        Core7State = $core7State
        HardwareRegistry = Test-Path -LiteralPath 'C:\RAH\HardwareRegistry\registry.json' -PathType Leaf
        ProjectMemoryConfig = Test-Path -LiteralPath 'C:\RAH\CONFIGURE-RAH-PROJECT-MEMORY.cmd' -PathType Leaf
    }
}

function Format-Status {
    param($Status)
    @(
        'RAH RAVEN OS // GOLD STATUS',
        '==============================================',
        ('Shell              : ' + $Status.Version),
        ('Computer           : ' + $Status.Computer),
        ('User               : ' + $Status.User),
        '',
        ('Raven Core :18765  : ' + $(if($Status.RavenCore18765){'ONLINE'}else{'OFFLINE'})),
        ('Node Agent :18766  : ' + $(if($Status.NodeAgent18766){'ONLINE'}else{'OFFLINE'})),
        ('Desktop Bridge     : ' + $(if($Status.DesktopBridge47824){'ONLINE :47824'}else{'OFFLINE'})),
        ('LM Studio          : ' + $(if($Status.LmStudio1234){'ONLINE :1234'}else{'OFFLINE'})),
        ('Ollama             : ' + $(if($Status.Ollama11434){'ONLINE :11434'}else{'OFFLINE'})),
        '',
        ('Raven Core 7       : ' + $Status.Core7State),
        ('Worker Proof       : ' + $Status.WorkerProofState),
        ('RAH OS Acceptance  : ' + $Status.AcceptanceState),
        ('Command Center     : ' + $(if($Status.CommandCenter){'READY'}else{'NOT FOUND'})),
        ('Raven Workspace    : ' + $(if($Status.RavenWorkspace){'READY'}else{'NOT FOUND'})),
        ('AI Self-Check      : ' + $(if($Status.AiSelfCheck){'READY'}else{'NOT FOUND'})),
        ('AnythingLLM Gate   : ' + $(if($Status.AnythingApproval){'READY'}else{'NOT FOUND'})),
        ('2-PC Grid          : ' + $(if($Status.Grid){'READY'}else{'NOT FOUND'})),
        ('2-PC Verify        : ' + $(if($Status.GridVerify){'READY'}else{'NOT FOUND'})),
        ('Hardware Registry  : ' + $(if($Status.HardwareRegistry){'READY'}else{'NOT BUILT'})),
        ('Project Memory     : ' + $(if($Status.ProjectMemoryConfig){'READY'}else{'NOT CONFIGURED'})),
        '',
        'SAFETY BOUNDARY',
        'Fixed local launchers only. No arbitrary shell input.',
        'No background discovery. No automatic firewall changes.',
        'Node Agent still requires explicit startup.'
    ) -join [Environment]::NewLine
}

function Start-FixedLauncher {
    param([Parameter(Mandatory=$true)][string]$Name,[string[]]$ExtraRoots=@())
    $path = Find-RahFile -Name $Name -ExtraRoots $ExtraRoots
    if(-not $path){ throw ('Not found: ' + $Name) }
    Write-RahOsLog ('START ' + $path)
    Start-Process -FilePath $path -WorkingDirectory (Split-Path -Parent $path)
}

function Open-RahFolder {
    param([Parameter(Mandatory=$true)][string]$Path)
    if(-not (Test-Path -LiteralPath $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null }
    Start-Process explorer.exe -ArgumentList $Path
    Write-RahOsLog ('OPEN FOLDER ' + $Path)
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RAH Raven OS — Gold Shell"
        Height="800" Width="1260" MinHeight="690" MinWidth="1080"
        WindowStartupLocation="CenterScreen"
        Background="#050505" Foreground="#F3D98B" FontFamily="Segoe UI"
        SnapsToDevicePixels="True">
  <Window.Resources>
    <LinearGradientBrush x:Key="GoldBrush" StartPoint="0,0" EndPoint="1,0">
      <GradientStop Color="#8B681A" Offset="0"/>
      <GradientStop Color="#F2CA63" Offset="0.45"/>
      <GradientStop Color="#FFF0A8" Offset="0.62"/>
      <GradientStop Color="#B9881F" Offset="1"/>
    </LinearGradientBrush>
    <LinearGradientBrush x:Key="GoldDarkBrush" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#211806" Offset="0"/>
      <GradientStop Color="#0E0B05" Offset="1"/>
    </LinearGradientBrush>

    <Style x:Key="NavButton" TargetType="{x:Type Button}">
      <Setter Property="Foreground" Value="#CDB66D"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Padding" Value="16,11"/>
      <Setter Property="Margin" Value="0,3"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Button}">
            <Border x:Name="NavBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7" Padding="{TemplateBinding Padding}">
              <ContentPresenter VerticalAlignment="Center" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="NavBorder" Property="Background" Value="#1B1507"/>
                <Setter TargetName="NavBorder" Property="BorderBrush" Value="#5E4716"/>
                <Setter Property="Foreground" Value="#FFE69A"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="NavBorder" Property="Background" Value="#2A1F08"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="GoldButton" TargetType="{x:Type Button}">
      <Setter Property="Foreground" Value="#130F05"/>
      <Setter Property="Background" Value="{StaticResource GoldBrush}"/>
      <Setter Property="BorderBrush" Value="#F7D875"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Padding" Value="16,10"/>
      <Setter Property="Margin" Value="0,0,8,8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Button}">
            <Border x:Name="GoldBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="GoldBorder" Property="Opacity" Value="0.88"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="GoldBorder" Property="Opacity" Value="0.68"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="DarkButton" TargetType="{x:Type Button}">
      <Setter Property="Foreground" Value="#E7D79B"/>
      <Setter Property="Background" Value="#12100B"/>
      <Setter Property="BorderBrush" Value="#5D491D"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="14,9"/>
      <Setter Property="Margin" Value="0,0,8,8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Button}">
            <Border x:Name="DarkBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="DarkBorder" Property="Background" Value="#211907"/>
                <Setter TargetName="DarkBorder" Property="BorderBrush" Value="#C5962C"/>
                <Setter Property="Foreground" Value="#FFF0B0"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="DarkBorder" Property="Background" Value="#33270B"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Card" TargetType="{x:Type Border}">
      <Setter Property="Background" Value="#0D0D0D"/>
      <Setter Property="BorderBrush" Value="#3B3018"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="10"/>
      <Setter Property="Padding" Value="16"/>
      <Setter Property="Margin" Value="0,0,12,12"/>
    </Style>

    <Style x:Key="SectionTitle" TargetType="{x:Type TextBlock}">
      <Setter Property="Foreground" Value="#FFE083"/>
      <Setter Property="FontSize" Value="19"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,10"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="232"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <Border Grid.Column="0" Background="#080808" BorderBrush="#3B2D0C" BorderThickness="0,0,1,0">
      <Grid Margin="16">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="{StaticResource GoldDarkBrush}" BorderBrush="#7A5B17" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,16">
          <StackPanel>
            <TextBlock Text="RAH" FontSize="32" FontWeight="Black" Foreground="{StaticResource GoldBrush}"/>
            <TextBlock Text="RAVEN OS" FontSize="16" FontWeight="Bold" Foreground="#FFE99C"/>
            <TextBlock Text="GOLD SHELL" FontSize="11" FontWeight="SemiBold" Foreground="#9E8647" Margin="0,4,0,0"/>
          </StackPanel>
        </Border>

        <StackPanel Grid.Row="1">
          <TextBlock Text="COMMAND" Foreground="#71623A" FontSize="10" FontWeight="Bold" Margin="8,0,0,5"/>
          <Button Name="NavHome" Style="{StaticResource NavButton}" Content="◆  OVERVIEW"/>
          <Button Name="NavAI" Style="{StaticResource NavButton}" Content="◈  AI + RAVEN"/>
          <Button Name="NavGrid" Style="{StaticResource NavButton}" Content="⌁  GRID + NETWORK"/>
          <Button Name="NavSystem" Style="{StaticResource NavButton}" Content="▣  SYSTEM"/>
          <Button Name="NavTools" Style="{StaticResource NavButton}" Content="◇  TOOLS + FILES"/>
        </StackPanel>

        <StackPanel Grid.Row="3">
          <Border Background="#0D0B06" BorderBrush="#33280F" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,8,0,8">
            <StackPanel>
              <TextBlock Text="LOCAL SAFETY" Foreground="#9D8648" FontSize="10" FontWeight="Bold"/>
              <TextBlock Text="Fixed launchers only" Foreground="#CDBF8C" FontSize="11" Margin="0,4,0,0"/>
              <TextBlock Text="No hidden remote start" Foreground="#7E755B" FontSize="10" Margin="0,2,0,0"/>
            </StackPanel>
          </Border>
          <Button Name="BtnExit" Style="{StaticResource NavButton}" Content="×  EXIT RAH OS"/>
        </StackPanel>
      </Grid>
    </Border>

    <Grid Grid.Column="1" Margin="24,20,24,20">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <Grid Grid.Row="0" Margin="0,0,0,16">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock Name="PageTitle" Text="RAH RAVEN OS" Foreground="#FFF0B0" FontSize="28" FontWeight="Bold"/>
          <TextBlock Name="PageSubtitle" Text="Local command environment • v0.7 Gold candidate" Foreground="#8F8054" FontSize="12" Margin="0,4,0,0"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <CheckBox Name="AutoRefresh" Content="LIVE" IsChecked="True" Foreground="#BDAA6D" VerticalAlignment="Center" Margin="0,0,14,0"/>
          <Button Name="BtnRefresh" Style="{StaticResource DarkButton}" Content="REFRESH" Margin="0"/>
        </StackPanel>
      </Grid>

      <UniformGrid Grid.Row="1" Rows="1" Columns="4" Margin="0,0,0,16">
        <Border Style="{StaticResource Card}" Margin="0,0,10,0" Padding="12">
          <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Ellipse Name="CoreDot" Width="10" Height="10" Fill="#6A5520" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <StackPanel Grid.Column="1"><TextBlock Text="RAVEN CORE" Foreground="#86764A" FontSize="10" FontWeight="Bold"/><TextBlock Name="CoreState" Text="CHECKING" Foreground="#EAD68F" FontSize="13" FontWeight="SemiBold"/></StackPanel>
          </Grid>
        </Border>
        <Border Style="{StaticResource Card}" Margin="0,0,10,0" Padding="12">
          <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Ellipse Name="AiDot" Width="10" Height="10" Fill="#6A5520" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <StackPanel Grid.Column="1"><TextBlock Text="LOCAL AI" Foreground="#86764A" FontSize="10" FontWeight="Bold"/><TextBlock Name="AiState" Text="CHECKING" Foreground="#EAD68F" FontSize="13" FontWeight="SemiBold"/></StackPanel>
          </Grid>
        </Border>
        <Border Style="{StaticResource Card}" Margin="0,0,10,0" Padding="12">
          <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Ellipse Name="BridgeDot" Width="10" Height="10" Fill="#6A5520" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <StackPanel Grid.Column="1"><TextBlock Text="DESKTOP BRIDGE" Foreground="#86764A" FontSize="10" FontWeight="Bold"/><TextBlock Name="BridgeState" Text="CHECKING" Foreground="#EAD68F" FontSize="13" FontWeight="SemiBold"/></StackPanel>
          </Grid>
        </Border>
        <Border Style="{StaticResource Card}" Margin="0" Padding="12">
          <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Ellipse Name="NodeDot" Width="10" Height="10" Fill="#6A5520" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <StackPanel Grid.Column="1"><TextBlock Text="NODE AGENT" Foreground="#86764A" FontSize="10" FontWeight="Bold"/><TextBlock Name="NodeState" Text="CHECKING" Foreground="#EAD68F" FontSize="13" FontWeight="SemiBold"/></StackPanel>
          </Grid>
        </Border>
      </UniformGrid>

      <Grid Grid.Row="2">
        <Grid Name="PanelHome">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <Grid Grid.Row="0">
            <Grid.ColumnDefinitions><ColumnDefinition Width="1.2*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border Grid.Column="0" Style="{StaticResource Card}" Background="{StaticResource GoldDarkBrush}" BorderBrush="#7A5A18">
              <StackPanel>
                <TextBlock Text="RAVEN LAUNCH DECK" Style="{StaticResource SectionTitle}"/>
                <TextBlock Text="Start the core RAH environment with one click. Stable authority stays unchanged." Foreground="#9F9062" TextWrapping="Wrap" Margin="0,0,0,14"/>
                <WrapPanel>
                  <Button Name="BtnAuto" Style="{StaticResource GoldButton}" Content="START LOCAL CORE"/>
                  <Button Name="BtnCC" Style="{StaticResource DarkButton}" Content="COMMAND CENTER"/>
                  <Button Name="BtnWorkspace" Style="{StaticResource DarkButton}" Content="RAVEN WORKSPACE"/>
                </WrapPanel>
              </StackPanel>
            </Border>
            <Border Grid.Column="1" Style="{StaticResource Card}" Margin="0,0,0,12">
              <StackPanel>
                <TextBlock Text="ACCEPTANCE" Style="{StaticResource SectionTitle}"/>
                <TextBlock Name="AcceptanceHero" Text="NOT RUN" Foreground="#FFE08A" FontSize="22" FontWeight="Bold" Margin="0,2,0,6"/>
                <TextBlock Text="HOVED-PC v0.6 acceptance remains the stable verification gate." Foreground="#8E825F" TextWrapping="Wrap" Margin="0,0,0,12"/>
                <Button Name="BtnAcceptance" Style="{StaticResource DarkButton}" Content="RUN HOVED-PC ACCEPTANCE" HorizontalAlignment="Left"/>
              </StackPanel>
            </Border>
          </Grid>

          <Grid Grid.Row="1">
            <Grid.ColumnDefinitions><ColumnDefinition Width="1.15*"/><ColumnDefinition Width="0.85*"/></Grid.ColumnDefinitions>
            <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,12,0">
              <Grid>
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <DockPanel Grid.Row="0" Margin="0,0,0,8">
                  <TextBlock Text="LIVE SYSTEM FEED" Style="{StaticResource SectionTitle}" DockPanel.Dock="Left"/>
                  <TextBlock Name="LastRefresh" Text="" Foreground="#665E47" FontSize="10" VerticalAlignment="Center" HorizontalAlignment="Right"/>
                </DockPanel>
                <TextBox Name="Output" Grid.Row="1" Background="#080808" Foreground="#D9C98D" BorderBrush="#2A2415" BorderThickness="1"
                         IsReadOnly="True" FontFamily="Consolas" FontSize="12" TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Padding="12"/>
              </Grid>
            </Border>
            <Border Grid.Column="1" Style="{StaticResource Card}" Margin="0">
              <StackPanel>
                <TextBlock Text="QUICK ACTIONS" Style="{StaticResource SectionTitle}"/>
                <Button Name="BtnAiCheckHome" Style="{StaticResource DarkButton}" Content="AI SELF-CHECK" HorizontalAlignment="Stretch"/>
                <Button Name="BtnCore7DiagHome" Style="{StaticResource DarkButton}" Content="CORE 7 DIAGNOSTICS" HorizontalAlignment="Stretch"/>
                <Button Name="BtnPrecheckHome" Style="{StaticResource DarkButton}" Content="RAH OS PRECHECK" HorizontalAlignment="Stretch"/>
                <Button Name="BtnFolderHome" Style="{StaticResource DarkButton}" Content="OPEN C:\RAH" HorizontalAlignment="Stretch"/>
              </StackPanel>
            </Border>
          </Grid>
        </Grid>

        <Grid Name="PanelAI" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Text="AI + RAVEN" Style="{StaticResource SectionTitle}"/>
          <UniformGrid Grid.Row="1" Columns="2" Rows="2">
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="RAVEN CORE / AI FABRIC" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Starts the fixed local Raven Core / AI Fabric launcher." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnFabric" Style="{StaticResource GoldButton}" Content="START AI FABRIC" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0,0,0,12"><StackPanel><TextBlock Text="LOCAL AI HEALTH" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Checks Raven Core, LM Studio inference, AnythingLLM, memory and council readiness." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnAiCheck" Style="{StaticResource DarkButton}" Content="RUN AI SELF-CHECK" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="ANYTHINGLLM APPROVAL" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Runs the existing approval-gate launcher without widening permissions." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnAnythingApproval" Style="{StaticResource DarkButton}" Content="OPEN APPROVAL GATE" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0"><StackPanel><TextBlock Text="RAVEN WORKSPACE" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Launches the desktop bridge workspace and probes local AI endpoints." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnWorkspaceAI" Style="{StaticResource DarkButton}" Content="OPEN WORKSPACE" HorizontalAlignment="Left"/></StackPanel></Border>
          </UniformGrid>
        </Grid>

        <Grid Name="PanelGrid" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Text="GRID + NETWORK" Style="{StaticResource SectionTitle}"/>
          <UniformGrid Grid.Row="1" Columns="2" Rows="2">
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="2-PC GRID" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Starts the existing RAH 2-PC Grid through its fixed launcher." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnGrid" Style="{StaticResource GoldButton}" Content="START GRID" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0,0,0,12"><StackPanel><TextBlock Text="VERIFY GRID" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Runs the current verification flow and leaves authority boundaries unchanged." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnVerify" Style="{StaticResource DarkButton}" Content="VERIFY 2-PC" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="INSTALL / UPDATE GRID" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Uses the existing fixed installer for the 2-PC grid components." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnInstallGrid" Style="{StaticResource DarkButton}" Content="INSTALL / UPDATE" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0"><StackPanel><TextBlock Text="NODE AGENT" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Status is visible above. RAH OS intentionally does not auto-start the remote Node Agent." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><TextBlock Name="NodePolicyText" Text="EXPLICIT START REQUIRED" Foreground="#C7A84E" FontSize="13" FontWeight="Bold"/></StackPanel></Border>
          </UniformGrid>
        </Grid>

        <Grid Name="PanelSystem" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Text="SYSTEM + ACCEPTANCE" Style="{StaticResource SectionTitle}"/>
          <UniformGrid Grid.Row="1" Columns="2" Rows="2">
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="RAH OS PRECHECK" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Runs the current self-test in a separate window." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnPrecheck" Style="{StaticResource DarkButton}" Content="RUN PRECHECK" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0,0,0,12"><StackPanel><TextBlock Text="SAFE REPAIR" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Refreshes only the existing Front Door allowlist from the repository." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnRepair" Style="{StaticResource DarkButton}" Content="SAFE REPAIR" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="CORE 7 DIAGNOSTICS" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Refreshes local hardware facts and Core 7 audit/status files." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnCore7Diag" Style="{StaticResource DarkButton}" Content="RUN DIAGNOSTICS" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0"><StackPanel><TextBlock Text="WORKER PROOF + ACCEPTANCE" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Run worker evidence or the full stable HOVED-PC sequence." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><WrapPanel><Button Name="BtnWorkerProof" Style="{StaticResource DarkButton}" Content="WORKER PROOF"/><Button Name="BtnAcceptanceSystem" Style="{StaticResource GoldButton}" Content="FULL ACCEPTANCE"/></WrapPanel></StackPanel></Border>
          </UniformGrid>
        </Grid>

        <Grid Name="PanelTools" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Text="TOOLS + FILES" Style="{StaticResource SectionTitle}"/>
          <UniformGrid Grid.Row="1" Columns="2" Rows="2">
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="RAH ROOT" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Open the main C:\RAH workspace." Foreground="#8F835D" Margin="0,7,0,14"/><Button Name="BtnFolder" Style="{StaticResource GoldButton}" Content="OPEN C:\RAH" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0,0,0,12"><StackPanel><TextBlock Text="RAVEN OS LOGS" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Open the local Gold Shell / Front Door log directory." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnLogs" Style="{StaticResource DarkButton}" Content="OPEN LOGS" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}"><StackPanel><TextBlock Text="STATE FILES" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Open local RAH OS acceptance and state evidence." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnState" Style="{StaticResource DarkButton}" Content="OPEN STATE" HorizontalAlignment="Left"/></StackPanel></Border>
            <Border Style="{StaticResource Card}" Margin="0"><StackPanel><TextBlock Text="COPY STATUS" Foreground="#FFE08A" FontSize="17" FontWeight="Bold"/><TextBlock Text="Copy the current system feed so it can be pasted into ChatGPT or a support note." Foreground="#8F835D" TextWrapping="Wrap" Margin="0,7,0,14"/><Button Name="BtnCopyStatus" Style="{StaticResource DarkButton}" Content="COPY SYSTEM STATUS" HorizontalAlignment="Left"/></StackPanel></Border>
          </UniformGrid>
        </Grid>
      </Grid>

      <Grid Grid.Row="3" Margin="0,14,0,0">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <TextBlock Text="RAH Raven OS • Gold Shell • local-first control surface" Foreground="#5F5740" FontSize="10" VerticalAlignment="Center"/>
        <TextBlock Grid.Column="1" Name="MachineLabel" Text="" Foreground="#82754F" FontFamily="Consolas" FontSize="10" VerticalAlignment="Center"/>
      </Grid>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @(
    'NavHome','NavAI','NavGrid','NavSystem','NavTools','BtnExit',
    'PageTitle','PageSubtitle','AutoRefresh','BtnRefresh',
    'CoreDot','CoreState','AiDot','AiState','BridgeDot','BridgeState','NodeDot','NodeState',
    'PanelHome','PanelAI','PanelGrid','PanelSystem','PanelTools',
    'BtnAuto','BtnCC','BtnWorkspace','BtnAcceptance','AcceptanceHero','Output','LastRefresh',
    'BtnAiCheckHome','BtnCore7DiagHome','BtnPrecheckHome','BtnFolderHome',
    'BtnFabric','BtnAiCheck','BtnAnythingApproval','BtnWorkspaceAI',
    'BtnGrid','BtnVerify','BtnInstallGrid','NodePolicyText',
    'BtnPrecheck','BtnRepair','BtnCore7Diag','BtnWorkerProof','BtnAcceptanceSystem',
    'BtnFolder','BtnLogs','BtnState','BtnCopyStatus','MachineLabel'
)
foreach($n in $names){ Set-Variable -Name $n -Value $window.FindName($n) -Scope Script }

function Set-LiveIndicator {
    param($Dot,$Label,[bool]$Online,[string]$OnlineText='ONLINE',[string]$OfflineText='OFFLINE')
    if($Online){
        $Dot.Fill = [Windows.Media.Brushes]::Gold
        $Label.Text = $OnlineText
        $Label.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(255,224,131))
    } else {
        $Dot.Fill = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(83,72,40))
        $Label.Text = $OfflineText
        $Label.Foreground = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(139,128,91))
    }
}

function Refresh-Ui {
    $s = Get-RahOsStatus
    $script:Output.Text = Format-Status $s
    $script:AcceptanceHero.Text = $s.AcceptanceState
    $script:MachineLabel.Text = ($s.Computer + '  //  ' + $s.Version)
    $script:LastRefresh.Text = ('UPDATED ' + (Get-Date).ToString('HH:mm:ss'))

    Set-LiveIndicator $script:CoreDot $script:CoreState $s.RavenCore18765 'ONLINE :18765' 'OFFLINE'
    $localAi = ($s.LmStudio1234 -or $s.Ollama11434)
    $aiText = if($s.LmStudio1234){'LM STUDIO :1234'}elseif($s.Ollama11434){'OLLAMA :11434'}else{'OFFLINE'}
    Set-LiveIndicator $script:AiDot $script:AiState $localAi $aiText 'OFFLINE'
    Set-LiveIndicator $script:BridgeDot $script:BridgeState $s.DesktopBridge47824 'ONLINE :47824' 'OFFLINE'
    Set-LiveIndicator $script:NodeDot $script:NodeState $s.NodeAgent18766 'ONLINE :18766' 'OFFLINE / MANUAL'

    if($s.NodeAgent18766){ $script:NodePolicyText.Text = 'ONLINE — EXPLICIT START POLICY PRESERVED' }
    else { $script:NodePolicyText.Text = 'OFFLINE — EXPLICIT START REQUIRED' }

    Write-RahOsLog ('REFRESH Raven=' + $s.RavenCore18765 + ' Node=' + $s.NodeAgent18766 + ' AI=' + $localAi)
}

function Show-Page {
    param([Parameter(Mandatory=$true)][ValidateSet('Home','AI','Grid','System','Tools')][string]$Page)
    foreach($panel in @($script:PanelHome,$script:PanelAI,$script:PanelGrid,$script:PanelSystem,$script:PanelTools)){
        $panel.Visibility = [Windows.Visibility]::Collapsed
    }
    switch($Page){
        'Home' { $script:PanelHome.Visibility=[Windows.Visibility]::Visible; $script:PageTitle.Text='RAH RAVEN OS'; $script:PageSubtitle.Text='Local command environment • v0.7 Gold candidate' }
        'AI' { $script:PanelAI.Visibility=[Windows.Visibility]::Visible; $script:PageTitle.Text='AI + RAVEN'; $script:PageSubtitle.Text='Local models, Raven Core, AnythingLLM and workspace launchers' }
        'Grid' { $script:PanelGrid.Visibility=[Windows.Visibility]::Visible; $script:PageTitle.Text='GRID + NETWORK'; $script:PageSubtitle.Text='2-PC compute grid and explicit Node boundaries' }
        'System' { $script:PanelSystem.Visibility=[Windows.Visibility]::Visible; $script:PageTitle.Text='SYSTEM + ACCEPTANCE'; $script:PageSubtitle.Text='Diagnostics, repair, worker proof and stable acceptance' }
        'Tools' { $script:PanelTools.Visibility=[Windows.Visibility]::Visible; $script:PageTitle.Text='TOOLS + FILES'; $script:PageSubtitle.Text='Logs, state, folders and copyable status' }
    }
}

function Set-OutputMessage {
    param([string]$Message)
    $script:Output.Text = ('[' + (Get-Date).ToString('HH:mm:ss') + '] ' + $Message + [Environment]::NewLine + [Environment]::NewLine + $script:Output.Text)
}

function Invoke-UiAction {
    param([Parameter(Mandatory=$true)][scriptblock]$Action,[Parameter(Mandatory=$true)][string]$Success)
    try {
        & $Action
        Set-OutputMessage $Success
    } catch {
        Set-OutputMessage ('ERROR: ' + $_.Exception.Message)
        Write-RahOsLog ('ERROR ' + $_.Exception.Message)
    }
}

$script:NavHome.Add_Click({ Show-Page 'Home' })
$script:NavAI.Add_Click({ Show-Page 'AI' })
$script:NavGrid.Add_Click({ Show-Page 'Grid' })
$script:NavSystem.Add_Click({ Show-Page 'System' })
$script:NavTools.Add_Click({ Show-Page 'Tools' })
$script:BtnExit.Add_Click({ $window.Close() })
$script:BtnRefresh.Add_Click({ try { Refresh-Ui } catch { Set-OutputMessage ('Refresh failed: ' + $_.Exception.Message) } })

$startWorkspace = {
    Start-FixedLauncher 'Start RAH Workspace.cmd' @('C:\RAH\raven-command-core\desktop-bridge','C:\RAH\RavenCommand\desktop-bridge')
}
$runAcceptance = {
    Start-FixedLauncher 'RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd' @('C:\RAH\RavenOS')
}
$runAiCheck = { Start-FixedLauncher 'RAVEN-AI-SELF-CHECK.cmd' @('C:\RAH') }
$runCoreDiag = { Start-FixedLauncher 'DIAGNOSTICS.cmd' @('C:\RAH') }
$runPrecheck = {
    $path = Find-RahFile 'RAH-OS-SELFTEST.ps1'
    if(-not $path){ throw 'RAH OS Self-Test was not found.' }
    Write-RahOsLog ('PRECHECK ' + $path)
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File',$path) -WorkingDirectory (Split-Path -Parent $path)
}

$script:BtnAuto.Add_Click({
    Invoke-UiAction {
        $fabric = Find-RahFile 'START-RAH-AI-FABRIC.cmd'
        if(-not $fabric){ throw 'Raven Core / AI Fabric launcher not found.' }
        Start-Process -FilePath $fabric -WorkingDirectory (Split-Path -Parent $fabric)
        Write-RahOsLog ('AUTO START Raven Core: ' + $fabric)
        Start-Sleep -Milliseconds 700
        $cc = Find-RahFile 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'
        if($cc){
            Start-Process -FilePath $cc -WorkingDirectory (Split-Path -Parent $cc)
            Write-RahOsLog ('AUTO START Command Center: ' + $cc)
        }
    } 'Started Raven Core and Command Center when available. Node Agent was not auto-started.'
})
$script:BtnCC.Add_Click({ Invoke-UiAction { Start-FixedLauncher 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat' } 'Command Center launcher started.' })
$script:BtnWorkspace.Add_Click({ Invoke-UiAction $startWorkspace 'Raven Workspace started.' })
$script:BtnWorkspaceAI.Add_Click({ Invoke-UiAction $startWorkspace 'Raven Workspace started.' })
$script:BtnAcceptance.Add_Click({ Invoke-UiAction $runAcceptance 'HOVED-PC v0.6 acceptance sequence started.' })
$script:BtnAcceptanceSystem.Add_Click({ Invoke-UiAction $runAcceptance 'HOVED-PC v0.6 acceptance sequence started.' })
$script:BtnFabric.Add_Click({ Invoke-UiAction { Start-FixedLauncher 'START-RAH-AI-FABRIC.cmd' } 'Raven Core / AI Fabric launcher started.' })
$script:BtnAiCheck.Add_Click({ Invoke-UiAction $runAiCheck 'AI Self-Check started.' })
$script:BtnAiCheckHome.Add_Click({ Invoke-UiAction $runAiCheck 'AI Self-Check started.' })
$script:BtnAnythingApproval.Add_Click({ Invoke-UiAction { Start-FixedLauncher 'START-HER-ANYTHINGLLM-APPROVAL.cmd' @('C:\RAH') } 'AnythingLLM approval gate started.' })
$script:BtnGrid.Add_Click({ Invoke-UiAction { Start-FixedLauncher 'START-HER-RAH-2PC-GRID.cmd' @('C:\RAH\2PCProof') } 'RAH 2-PC Grid started.' })
$script:BtnVerify.Add_Click({ Invoke-UiAction { Start-FixedLauncher 'VERIFY-RAH-2PC-GRID.cmd' @('C:\RAH\2PCProof') } '2-PC verification started.' })
$script:BtnInstallGrid.Add_Click({ Invoke-UiAction { Start-FixedLauncher 'INSTALL-RAH-2PC-GRID.cmd' } '2-PC installer/updater started.' })
$script:BtnPrecheck.Add_Click({ Invoke-UiAction $runPrecheck 'RAH OS precheck opened in a separate window.' })
$script:BtnPrecheckHome.Add_Click({ Invoke-UiAction $runPrecheck 'RAH OS precheck opened in a separate window.' })
$script:BtnRepair.Add_Click({ Invoke-UiAction { Start-FixedLauncher 'REPAIR-RAH-OS.cmd' } 'Safe Repair started using the existing fixed Front Door allowlist.' })
$script:BtnCore7Diag.Add_Click({ Invoke-UiAction $runCoreDiag 'Raven Core 7 diagnostics started.' })
$script:BtnCore7DiagHome.Add_Click({ Invoke-UiAction $runCoreDiag 'Raven Core 7 diagnostics started.' })
$script:BtnWorkerProof.Add_Click({ Invoke-UiAction { Start-FixedLauncher 'WORKER-PROOF.cmd' @('C:\RAH') } 'Worker Proof started.' })
$script:BtnFolder.Add_Click({ Invoke-UiAction { Open-RahFolder 'C:\RAH' } 'Opened C:\RAH.' })
$script:BtnFolderHome.Add_Click({ Invoke-UiAction { Open-RahFolder 'C:\RAH' } 'Opened C:\RAH.' })
$script:BtnLogs.Add_Click({ Invoke-UiAction { Open-RahFolder $script:LogRoot } 'Opened RAH OS logs.' })
$script:BtnState.Add_Click({ Invoke-UiAction { Open-RahFolder $script:StateRoot } 'Opened RAH OS state folder.' })
$script:BtnCopyStatus.Add_Click({
    Invoke-UiAction {
        [Windows.Clipboard]::SetText($script:Output.Text)
    } 'Current RAH OS status copied to clipboard.'
})

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(5)
$timer.Add_Tick({
    try {
        if($script:AutoRefresh.IsChecked -eq $true){ Refresh-Ui }
    } catch {
        Write-RahOsLog ('AUTO REFRESH ERROR ' + $_.Exception.Message)
    }
})
$timer.Start()
$window.Add_Closed({ $timer.Stop() })

Write-RahOsLog ('OPEN RAH OS Gold Shell ' + $script:Version)
Show-Page 'Home'
Refresh-Ui
[void]$window.ShowDialog()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

$root='C:\RAH\RavenOS'
$version='0.8.0-candidate'
$gold='#D4AF37'
$gold2='#F2D675'
$bg='#090A0C'
$panel='#111318'
$muted='#9CA3AF'

function P([int]$n){try{$c=New-Object Net.Sockets.TcpClient;$a=$c.BeginConnect('127.0.0.1',$n,$null,$null);$ok=$a.AsyncWaitHandle.WaitOne(250,$false);if($ok -and $c.Connected){$c.EndConnect($a);$c.Close();return $true};$c.Close()}catch{};return $false}
function File([string]$n){Join-Path $root $n}
function LaunchPs([string]$n,[string[]]$args=@()){ $p=File $n;if(Test-Path $p){Start-Process powershell.exe -ArgumentList (@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$p+'"'))+$args) -WorkingDirectory $root}}
function LaunchCmd([string]$n){$p=File $n;if(Test-Path $p){Start-Process $p -WorkingDirectory $root}}

$x=@"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="RAH OS v0.8" Height="650" Width="980" WindowStartupLocation="CenterScreen" Background="$bg" Foreground="White">
<Grid Margin="24">
 <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="18"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel>
  <TextBlock Text="RAH OS" FontSize="38" FontWeight="Bold" Foreground="$gold2"/>
  <TextBlock Text="RAVEN DAILY DRIVER  •  v0.8 candidate" FontSize="14" Foreground="$gold" Margin="2,4,0,0"/>
 </StackPanel>
 <Border Grid.Row="2" Background="$panel" BorderBrush="$gold" BorderThickness="1" CornerRadius="14" Padding="22">
  <Grid>
   <Grid.ColumnDefinitions><ColumnDefinition Width="1.1*"/><ColumnDefinition Width="1*"/></Grid.ColumnDefinitions>
   <StackPanel Margin="0,0,24,0">
    <TextBlock Text="SYSTEM STATUS" FontSize="16" FontWeight="Bold" Foreground="$gold" Margin="0,0,0,14"/>
    <TextBlock Name="Status" FontFamily="Consolas" FontSize="14" LineHeight="25"/>
   </StackPanel>
   <StackPanel Grid.Column="1">
    <TextBlock Text="COMMANDS" FontSize="16" FontWeight="Bold" Foreground="$gold" Margin="0,0,0,14"/>
    <Button Name="Refresh" Content="Refresh status" Height="42" Margin="0,0,0,9"/>
    <Button Name="Core" Content="Start / check Raven Core" Height="42" Margin="0,0,0,9"/>
    <Button Name="AI" Content="Start AI Fabric" Height="42" Margin="0,0,0,9"/>
    <Button Name="Accept" Content="Run full acceptance" Height="42" Margin="0,0,0,9"/>
    <Button Name="Repair" Content="Safe Repair" Height="42" Margin="0,0,0,9"/>
    <Button Name="Logs" Content="Open logs + state" Height="42" Margin="0,0,0,9"/>
   </StackPanel>
  </Grid>
 </Border>
 <DockPanel Grid.Row="3" Margin="0,18,0,0">
   <TextBlock Text="RAH Raven • fixed local actions • no automatic remote node start" Foreground="$muted" VerticalAlignment="Center"/>
   <Button Name="Close" Content="Close" Width="100" Height="34" DockPanel.Dock="Right"/>
 </DockPanel>
</Grid>
</Window>
"@
$w=[Windows.Markup.XamlReader]::Parse($x)
$s=$w.FindName('Status')
function Refresh{
 $lines=@()
 $lines+='Front Door      '+$(if(Test-Path (File 'START-HER-RAH-OS.cmd')){'PASS'}else{'MISSING'})
 $lines+='Raven Core      '+$(if(P 18765){'ONLINE'}else{'OFFLINE'})
 $lines+='Node Agent      '+$(if(P 18766){'ONLINE / EXPLICIT'}else{'OFFLINE / EXPLICIT'})
 $lines+='LM Studio       '+$(if(P 1234){'ONLINE'}else{'OFFLINE'})
 $lines+='AnythingLLM     '+$(if(P 3001){'ONLINE'}else{'OFFLINE'})
 $a=File 'state\RAH-OS-v0.8-ACCEPTANCE.json'
 if(Test-Path $a){try{$j=Get-Content $a -Raw|ConvertFrom-Json;$lines+='Acceptance      '+[string]$j.overall}catch{$lines+='Acceptance      INVALID'}}else{$lines+='Acceptance      NOT RUN'}
 $lines+=''
 $lines+='Install root    '+$root
 $lines+='Version         '+$version
 $s.Text=$lines -join [Environment]::NewLine
}
$w.FindName('Refresh').Add_Click({Refresh})
$w.FindName('Core').Add_Click({LaunchPs 'RAVEN-CORE-7.ps1' @('-Mode','Start')})
$w.FindName('AI').Add_Click({LaunchCmd 'START-RAH-AI-FABRIC.cmd'})
$w.FindName('Accept').Add_Click({LaunchCmd 'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.cmd'})
$w.FindName('Repair').Add_Click({LaunchCmd 'REPAIR-RAH-OS.cmd'})
$w.FindName('Logs').Add_Click({Start-Process explorer.exe -ArgumentList ('"'+$root+'"')})
$w.FindName('Close').Add_Click({$w.Close()})
Refresh
$null=$w.ShowDialog()

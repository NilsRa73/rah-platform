param(
    [ValidateSet(20,24,28)]
    [int]$Size = 24,
    [string]$Face = 'Consolas'
)

$ErrorActionPreference = 'Stop'

$signature = @'
using System;
using System.Runtime.InteropServices;

public static class RavenConsoleFont {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CONSOLE_FONT_INFOEX {
        public uint cbSize;
        public uint nFont;
        public short FontSizeX;
        public short FontSizeY;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FaceName;
    }

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFOEX lpConsoleCurrentFontEx);
}
'@

if (-not ('RavenConsoleFont' -as [type])) {
    Add-Type -TypeDefinition $signature
}

$info = New-Object RavenConsoleFont+CONSOLE_FONT_INFOEX
$info.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($info)
$info.nFont = 0
$info.FontSizeX = 0
$info.FontSizeY = [int16]$Size
$info.FontFamily = 54
$info.FontWeight = 700
$info.FaceName = $Face
$handle = [RavenConsoleFont]::GetStdHandle(-11)
if ($handle -eq [IntPtr]::Zero -or $handle -eq [IntPtr](-1)) { exit 2 }
if (-not [RavenConsoleFont]::SetCurrentConsoleFontEx($handle, $false, [ref]$info)) { exit 3 }
exit 0

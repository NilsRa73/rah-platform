# RAH-WALL.exe

Native Windows wall app for RAH / Acer X133PWH. This version is **not HTML, not Edge, and not WebView**. It is a small WinForms/GDI+ executable targeting the built-in .NET Framework on Windows 11.

## Modes

- Dashboard
- Big Clock
- Raven Pulse
- Auto Cycle

## Controls

- `Space` or left click: next scene
- `D`: Dashboard
- `C`: Big Clock
- `P`: Raven Pulse
- `A`: Auto Cycle
- `B`: blackout
- `Esc`: exit
- Right click: scene menu
- `F11`: toggle window border for diagnostics

## Command line

```text
RAH-WALL.exe --mode dashboard
RAH-WALL.exe --mode clock
RAH-WALL.exe --mode pulse
RAH-WALL.exe --mode auto
RAH-WALL.exe --screen 1 --mode auto
```

With no `--screen`, the app chooses the first non-primary display when one exists, otherwise the primary display.

## Build

The GitHub Actions workflow compiles with the Windows .NET Framework C# compiler and runs:

```text
RAH-WALL.exe --self-test
```

before publishing the artifact.

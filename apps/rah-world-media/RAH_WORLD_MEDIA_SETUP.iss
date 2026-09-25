#define MyAppName "RAH Storm TV + Radio"
#define MyAppVersion "14.0"
#define MyPublisher "RAH AI Studios"

#ifndef SourceDir
  #define SourceDir "."
#endif

#ifndef OutputDir
  #define OutputDir ".\dist"
#endif

[Setup]
AppId={{D7D41A9F-355C-4D0D-A2B1-9F44B5DA7314}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyPublisher}
DefaultDirName={autopf}\RAH\WorldMedia\14.0
DefaultGroupName=RAH
OutputDir={#OutputDir}
OutputBaseFilename=RAH_STORM_TV_RADIO_WINDOWS_v14.0_SETUP
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Uninstallable=yes
DisableProgramGroupPage=yes
SetupLogging=yes
CreateAppDir=yes

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autodesktop}\RAH Storm TV + Radio"; Filename: "{app}\START-HER.cmd"; WorkingDir: "{app}"
Name: "{group}\RAH Storm TV + Radio"; Filename: "{app}\START-HER.cmd"; WorkingDir: "{app}"
Name: "{group}\RAH World Media Selftest"; Filename: "{app}\SELFTEST.cmd"; WorkingDir: "{app}"

[Run]
Filename: "{app}\START-HER.cmd"; Description: "Start RAH Storm TV + Radio"; Flags: postinstall nowait skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

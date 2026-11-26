; Dropit Windows x64 Installer Script (Inno Setup)

#ifndef PayloadDir
  #define PayloadDir "D:\inno"
#endif
#ifndef ResultDir
  #define ResultDir "D:\inno-result"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "1.18.2"
#endif

#define MyAppName "Dropit"
#define MyAppPublisher "Dropit"
#define MyAppExeName "dropit.exe"

[Setup]
AppId={{EC6B5BBE-4BCC-49BD-90E3-51B22B01227A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#ResultDir}
OutputBaseFilename=Dropit-{#MyAppVersion}-windows-x86-64-setup
SetupIconFile={#PayloadDir}\logo.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PayloadDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

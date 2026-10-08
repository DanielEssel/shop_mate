; Inno Setup script for the ShopMate Windows installer.
;
; Build with installer\windows\build_installer.ps1, which checks the Flutter
; Release output, locates the MSVC runtime and passes the defines below.

#ifndef AppVersion
  #error AppVersion must be defined (e.g. /DAppVersion=1.0.0)
#endif
#ifndef VCRuntimeDir
  #error VCRuntimeDir must point at the x64 Microsoft.VC14x.CRT folder
#endif

#define AppName "ShopMate"
#define AppExeName "shopmate.exe"
#define AppPublisher "KoDanX Web Services and Solutions"
#define ReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
; AppId identifies ShopMate across versions. Never change it, or upgrades
; will install side by side instead of replacing the existing install.
AppId={{3082378B-5F25-46DA-A365-74F435A6305A}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoProductName={#AppName}
VersionInfoDescription={#AppName} Setup
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=no
; Per-machine by default; the user may choose a per-user install instead.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
CloseApplications=yes
OutputDir=..\..\build\release
OutputBaseFilename={#AppName}_Setup_v{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; Clear the previous version's Flutter assets so stale files never linger.
; User data lives in %APPDATA%, never under {app}, so this is safe.
Type: filesandordirs; Name: "{app}\data"

[Files]
; The complete Flutter Release output: executable, plugin DLLs and data\.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; App-local MSVC runtime, so no separate VC++ Redistributable is needed.
Source: "{#VCRuntimeDir}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#VCRuntimeDir}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#VCRuntimeDir}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

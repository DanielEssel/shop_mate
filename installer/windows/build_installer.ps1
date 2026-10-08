# Builds build\release\ShopMate_Setup_v<version>.exe from the Flutter
# Windows Release output. Run `flutter build windows --release` first.
#
#   powershell -ExecutionPolicy Bypass -File installer\windows\build_installer.ps1

$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\..\.."
$release = Join-Path $root 'build\windows\x64\runner\Release'

# Refuse to package an incomplete Release directory.
$required = @('shopmate.exe', 'flutter_windows.dll', 'app_links_plugin.dll',
  'file_selector_windows_plugin.dll', 'printing_plugin.dll', 'pdfium.dll',
  'url_launcher_windows_plugin.dll', 'data\app.so', 'data\icudtl.dat',
  'data\flutter_assets\AssetManifest.bin')
$missing = $required | Where-Object { -not (Test-Path (Join-Path $release $_)) }
if ($missing) {
  throw "Release output is incomplete (run 'flutter build windows --release'). Missing: $($missing -join ', ')"
}

# Version comes from pubspec.yaml (build number dropped): 1.0.0+1 -> 1.0.0.
$versionLine = Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)'
if (-not $versionLine) { throw 'Could not read version from pubspec.yaml' }
$version = $versionLine.Matches[0].Groups[1].Value

# MSVC runtime DLLs from the Visual Studio install that built the app.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -property installationPath
$crt = Get-ChildItem "$vs\VC\Redist\MSVC" -Recurse -Directory -Filter 'Microsoft.VC14*.CRT' |
  Where-Object { $_.Parent.Name -eq 'x64' } |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw "MSVC x64 runtime not found under $vs\VC\Redist\MSVC" }

$iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 not found (winget install JRSoftware.InnoSetup)' }

& $iscc "/DAppVersion=$version" "/DVCRuntimeDir=$($crt.FullName)" (Join-Path $PSScriptRoot 'shopmate.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }

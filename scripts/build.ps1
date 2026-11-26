param([ValidateSet('windows','android','help')][string]$Target = 'help')
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
Push-Location $Repo
try {
  if (Get-Command fvm -ErrorAction SilentlyContinue) {
    $FlutterCmd = 'fvm'; $FlutterPrefix = @('flutter')
  } else { $FlutterCmd = 'flutter'; $FlutterPrefix = @() }
  & $FlutterCmd @FlutterPrefix pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
  Push-Location 'app'
  try {
    & $FlutterCmd @FlutterPrefix test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
    & $FlutterCmd @FlutterPrefix analyze --no-fatal-infos
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
    if ($Target -eq 'windows') { & $FlutterCmd @FlutterPrefix build windows }
    elseif ($Target -eq 'android') { & $FlutterCmd @FlutterPrefix build apk }
    else { Write-Host 'Usage: .\scripts\build.ps1 windows (or android)' }
    if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
  } finally { Pop-Location }
} finally { Pop-Location }

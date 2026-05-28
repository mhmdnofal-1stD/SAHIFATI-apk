[CmdletBinding()]
param(
  [int]$Port = 8090,
  [string]$Hostname = 'localhost'
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$sharedBuildConfigPath = Join-Path $projectRoot 'tool\build_config.json'
$sharedDefineGeneratorPath = Join-Path $projectRoot 'tool\generate_flutter_defines.dart'
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'

if (-not (Test-Path $sharedBuildConfigPath)) {
  throw "Missing shared build config at $sharedBuildConfigPath"
}

function Get-FlutterDefineArgs {
  param([string]$Profile = 'web-dev')

  $output = & dart 'run' $sharedDefineGeneratorPath "--profile=$Profile" "--config=$sharedBuildConfigPath" "--pubspec=$pubspecPath"
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to generate Flutter defines for profile '$Profile'"
  }

  $defines = @(
    $output |
      Where-Object { $_ -and $_.Trim().StartsWith('--dart-define=') } |
      ForEach-Object { $_.Trim() }
  )

  if ($defines.Count -eq 0) {
    throw "No Flutter defines were produced for profile '$Profile'"
  }

  return $defines
}

$webDevDefines = Get-FlutterDefineArgs -Profile 'web-dev'

Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Sahifati Web Development Server'
Write-Host '========================================' -ForegroundColor Cyan
Write-Host "Shared build config   : $sharedBuildConfigPath"
Write-Host "Server Address        : http://${Hostname}:${Port}"
Write-Host ''

$runArgs = @(
  'run',
  '-d', 'chrome',
  '--web-hostname', $Hostname,
  '--web-port', $Port
)

$runArgs += $webDevDefines

Push-Location $projectRoot
try {
  & flutter @runArgs
  if ($LASTEXITCODE -ne 0) {
    throw "flutter run failed with exit code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}

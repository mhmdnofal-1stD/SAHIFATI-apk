[CmdletBinding()]
param(
  [string]$GoogleServerClientId = '605484701854-h07an8isp8gr4jim786hi9tqegq62n5k.apps.googleusercontent.com',
  [switch]$SplitPerAbi = $true,
  [switch]$Obfuscate = $true
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$androidDir = Join-Path $projectRoot 'android'
$keyPropertiesPath = Join-Path $androidDir 'key.properties'
$appBuildGradlePath = Join-Path $androidDir 'app\build.gradle'

if (-not (Test-Path $keyPropertiesPath)) {
  throw "Missing Android signing config at $keyPropertiesPath"
}

if ([string]::IsNullOrWhiteSpace($GoogleServerClientId)) {
  throw 'GOOGLE_SERVER_CLIENT_ID is required for Android Google Sign-In builds.'
}

$keyProperties = @{}
Get-Content $keyPropertiesPath | ForEach-Object {
  if ($_ -match '=') {
    $parts = $_ -split '=', 2
    $keyProperties[$parts[0].Trim()] = $parts[1].Trim()
  }
}

$storeFileValue = $keyProperties['storeFile']
$keyAlias = $keyProperties['keyAlias']
$storePassword = $keyProperties['storePassword']
$keyPassword = $keyProperties['keyPassword']

if (-not $storeFileValue -or -not $keyAlias -or -not $storePassword -or -not $keyPassword) {
  throw 'Android key.properties is missing one or more required signing entries.'
}

$resolvedStorePath = Resolve-Path (Join-Path $androidDir $storeFileValue)

$applicationIdMatch = Select-String -Path $appBuildGradlePath -Pattern 'applicationId\s+"([^"]+)"' | Select-Object -First 1
if (-not $applicationIdMatch) {
  throw 'Unable to detect Android applicationId from android/app/build.gradle'
}

$applicationId = $applicationIdMatch.Matches[0].Groups[1].Value

Write-Host '========================================'
Write-Host '  Sahifati Android Release Build'
Write-Host '========================================'
Write-Host "Application ID          : $applicationId"
Write-Host "Google Server Client ID : $GoogleServerClientId"
Write-Host "Signing alias           : $keyAlias"
Write-Host "Signing store           : $resolvedStorePath"
Write-Host ''

Write-Host '[1/2] Signing fingerprints'
& keytool -list -v -keystore $resolvedStorePath -alias $keyAlias -storepass $storePassword -keypass $keyPassword |
  Select-String 'SHA1:|SHA256:' |
  ForEach-Object { Write-Host ('  ' + $_.ToString().Trim()) }

Write-Host ''
Write-Host '[2/2] Building release APK'

$buildArgs = @(
  'build',
  'apk',
  '--release',
  '--tree-shake-icons',
  "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleServerClientId"
)

if ($SplitPerAbi) {
  $buildArgs += '--split-per-abi'
}

if ($Obfuscate) {
  $buildArgs += '--obfuscate'
  $buildArgs += '--split-debug-info=build/app/outputs/symbols'
}

Push-Location $projectRoot
try {
  & flutter @buildArgs
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build apk failed with exit code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}

Write-Host ''
Write-Host 'Build completed successfully.'
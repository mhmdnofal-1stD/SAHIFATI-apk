[CmdletBinding()]
param(
  [ValidateSet('apk', 'aab')]
  [string]$Artifact = 'apk',
  [bool]$SplitPerAbi = $true,
  [string]$ApkTargetPlatform = 'android-arm64',
  [bool]$Obfuscate = $true
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$androidDir = Join-Path $projectRoot 'android'
$keyPropertiesPath = Join-Path $androidDir 'key.properties'
$appBuildGradlePath = Join-Path $androidDir 'app\build.gradle'
$agconnectServicesPath = Join-Path $androidDir 'app\agconnect-services.json'
$sharedBuildConfigPath = Join-Path $projectRoot 'tool\build_config.json'
$sharedDefineGeneratorPath = Join-Path $projectRoot 'tool\generate_flutter_defines.dart'
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'

if (-not (Test-Path $sharedBuildConfigPath)) {
  throw "Missing shared build config at $sharedBuildConfigPath"
}

function Get-FlutterDefineArgs {
  param([string]$Profile = 'release')

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

$releaseDefineArgs = Get-FlutterDefineArgs -Profile 'release'
$releaseDefineMap = @{}
foreach ($entry in $releaseDefineArgs) {
  $normalized = $entry -replace '^--dart-define=', ''
  $key, $value = $normalized.Split('=', 2)
  $releaseDefineMap[$key] = $value
}

$googleServerClientId = $releaseDefineMap['GOOGLE_SERVER_CLIENT_ID']
$facebookAppId = $releaseDefineMap['FACEBOOK_APP_ID']
$appleWebClientId = $releaseDefineMap['APPLE_WEB_CLIENT_ID']
$appleRedirectUri = $releaseDefineMap['APPLE_REDIRECT_URI']
$huaweiAppId = $releaseDefineMap['HUAWEI_APP_ID']

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
Write-Host "Artifact                : $Artifact"
Write-Host "Application ID          : $applicationId"
Write-Host "Google Server Client ID : $GoogleServerClientId"
Write-Host "Facebook App ID         : $FacebookAppId"
Write-Host "Apple Web Client ID     : $AppleWebClientId"
Write-Host "Apple Redirect URI      : $AppleRedirectUri"
if ($Artifact -eq 'apk') {
  Write-Host "APK target platform     : $ApkTargetPlatform"
}
if ([string]::IsNullOrWhiteSpace($HuaweiAppId)) {
  Write-Host 'Huawei App ID           : <not set>'
}
else {
  Write-Host "Huawei App ID           : $HuaweiAppId"
}
Write-Host "Signing alias           : $keyAlias"
Write-Host "Signing store           : $resolvedStorePath"
Write-Host ''

if (-not [string]::IsNullOrWhiteSpace($HuaweiAppId) -and -not (Test-Path $agconnectServicesPath)) {
  throw "Huawei build requested but missing AG Connect config at $agconnectServicesPath"
}

Write-Host '[1/2] Signing fingerprints'
& keytool -list -v -keystore $resolvedStorePath -alias $keyAlias -storepass $storePassword -keypass $keyPassword |
  Select-String 'SHA1:|SHA256:' |
  ForEach-Object { Write-Host ('  ' + $_.ToString().Trim()) }

Write-Host ''
if ($Artifact -eq 'aab' -and $SplitPerAbi) {
  Write-Host 'Split per ABI           : ignored for AAB builds'
}

$artifactLabel = if ($Artifact -eq 'aab') { 'AAB' } else { 'APK' }
Write-Host "[2/2] Building release $artifactLabel"

$buildArgs = @(
  'build',
  $(if ($Artifact -eq 'aab') { 'appbundle' } else { 'apk' }),
  '--release',
  '--tree-shake-icons'
)
$buildArgs += $releaseDefineArgs

if ($Artifact -eq 'apk' -and -not [string]::IsNullOrWhiteSpace($ApkTargetPlatform)) {
  $buildArgs += '--target-platform'
  $buildArgs += $ApkTargetPlatform
}

if ($Artifact -eq 'apk' -and $SplitPerAbi) {
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
    throw "flutter build $Artifact failed with exit code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}

$outputPath = if ($Artifact -eq 'aab') {
  Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab'
}
elseif ($SplitPerAbi -and $ApkTargetPlatform -eq 'android-arm64') {
  Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
}
elseif (-not $SplitPerAbi) {
  Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
}
else {
  Join-Path $projectRoot 'build\app\outputs\flutter-apk'
}

Write-Host ''
Write-Host 'Build completed successfully.'
Write-Host "Output                  : $outputPath"
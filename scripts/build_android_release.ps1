[CmdletBinding()]
param(
  [ValidateSet('apk', 'aab')]
  [string]$Artifact = 'apk',
  [string]$GoogleServerClientId = '605484701854-h07an8isp8gr4jim786hi9tqegq62n5k.apps.googleusercontent.com',
  [string]$FacebookAppId = '824178674089653',
  [string]$AppleWebClientId = 'org.sahifati.app.signin',
  [string]$AppleRedirectUri = 'https://sahifati.org/api/auth/social/apple/callback',
  [string]$HuaweiAppId = '116918405',
  [bool]$SplitPerAbi = $true,
  [bool]$Obfuscate = $true
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$androidDir = Join-Path $projectRoot 'android'
$keyPropertiesPath = Join-Path $androidDir 'key.properties'
$appBuildGradlePath = Join-Path $androidDir 'app\build.gradle'
$agconnectServicesPath = Join-Path $androidDir 'app\agconnect-services.json'

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
  '--tree-shake-icons',
  "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleServerClientId",
  "--dart-define=FACEBOOK_APP_ID=$FacebookAppId",
  "--dart-define=APPLE_WEB_CLIENT_ID=$AppleWebClientId",
  "--dart-define=APPLE_REDIRECT_URI=$AppleRedirectUri"
)

if (-not [string]::IsNullOrWhiteSpace($HuaweiAppId)) {
  $buildArgs += "--dart-define=HUAWEI_APP_ID=$HuaweiAppId"
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
else {
  Join-Path $projectRoot 'build\app\outputs\flutter-apk'
}

Write-Host ''
Write-Host 'Build completed successfully.'
Write-Host "Output                  : $outputPath"
[CmdletBinding()]
param(
  [string]$GoogleWebClientId = '821809289982-m9g7reu9a9vfju911rg3uqg009rr12rp.apps.googleusercontent.com',
  [string]$FacebookAppId = '824178674089653',
  [string]$AppleWebClientId = 'org.sahifati.app.signin',
  [string]$AppleRedirectUri = 'https://sahifati.org/api/auth/social/apple/callback',
  [int]$Port = 8090,
  [string]$Hostname = 'localhost'
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  Sahifati Web Development Server'
Write-Host '========================================' -ForegroundColor Cyan
Write-Host "Google Web Client ID  : $GoogleWebClientId"
Write-Host "Facebook App ID       : $FacebookAppId"
Write-Host "Apple Web Client ID   : $AppleWebClientId"
Write-Host "Apple Redirect URI    : $AppleRedirectUri"
Write-Host "Server Address        : http://${Hostname}:${Port}"
Write-Host ''

$runArgs = @(
  'run',
  '-d', 'chrome',
  '--web-hostname', $Hostname,
  '--web-port', $Port,
  "--dart-define=GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId",
  "--dart-define=FACEBOOK_APP_ID=$FacebookAppId",
  "--dart-define=APPLE_WEB_CLIENT_ID=$AppleWebClientId",
  "--dart-define=APPLE_REDIRECT_URI=$AppleRedirectUri"
)

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

#Requires -Version 5.0
<#
.SYNOPSIS
Build Flutter AAB (Android App Bundle) for Sahifati with all required configurations.

.DESCRIPTION
Builds a release AAB with all necessary --dart-define parameters for authentication
providers (Google, Apple, Facebook, Huawei) and API endpoints.

.PARAMETER OutputDir
Directory where AAB will be saved. Defaults to ./build/app/outputs/bundle/release/

.PARAMETER SkipClean
Skip running `flutter clean` before build. Defaults to $false.

.PARAMETER AnalyzeOnly
Run analysis without building. Defaults to $false.

.EXAMPLE
.\build-aab-release.ps1

.EXAMPLE
.\build-aab-release.ps1 -SkipClean -OutputDir "D:\releases"

.NOTES
Requires Flutter SDK and Android SDK to be installed and configured.
This script is environment-agnostic and works on Windows, macOS, and Linux.
#>

param(
    [string]$OutputDir = "./build/app/outputs/bundle/release/",
    [switch]$SkipClean,
    [switch]$AnalyzeOnly
)

# Configuration
$apiBaseUrl = "https://sahifati.org/api"
$googleWebClientId = "821809289982-m9g7reu9a9vfju911rg3uqg009rr12rp.apps.googleusercontent.com"
$googleServerClientId = "821809289982-m9g7reu9a9vfju911rg3uqg009rr12rp.apps.googleusercontent.com"
$appleWebClientId = "org.sahifati.app.signin"
$appleRedirectUri = "https://sahifati.org/api/auth/social/apple/callback"
$facebookAppId = "824178674089653"
$huaweiAppId = "116918405"

$defineParams = @(
    "API_BASE_URL=$apiBaseUrl",
    "GOOGLE_WEB_CLIENT_ID=$googleWebClientId",
    "GOOGLE_SERVER_CLIENT_ID=$googleServerClientId",
    "APPLE_WEB_CLIENT_ID=$appleWebClientId",
    "APPLE_REDIRECT_URI=$appleRedirectUri",
    "FACEBOOK_AUTH_ENABLED=true",
    "FACEBOOK_APP_ID=$facebookAppId",
    "HUAWEI_APP_ID=$huaweiAppId"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Sahifati Flutter AAB Release Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get current version from pubspec.yaml
$pubspecPath = "pubspec.yaml"
if (Test-Path $pubspecPath) {
    $version = (Select-String -Path $pubspecPath -Pattern "^version:\s+(.+)$").Matches[0].Groups[1].Value
    Write-Host "Version: $version" -ForegroundColor Green
} else {
    Write-Error "pubspec.yaml not found. Run this script from the Flutter project root."
    exit 1
}

Write-Host ""
Write-Host "Build Configuration:" -ForegroundColor Cyan
$defineParams | ForEach-Object {
    $key, $value = $_.Split('=', 2)
    if ($key -in @("GOOGLE_WEB_CLIENT_ID", "GOOGLE_SERVER_CLIENT_ID", "APPLE_WEB_CLIENT_ID")) {
        $displayValue = $value.Substring(0, 20) + "..."
    } elseif ($key -eq "API_BASE_URL") {
        $displayValue = $value
    } else {
        $displayValue = $value
    }
    Write-Host "  --dart-define=$key=$displayValue"
}
Write-Host ""

# Optional: Analysis only
if ($AnalyzeOnly) {
    Write-Host "Running analysis only (no build)..." -ForegroundColor Yellow
    $analysisArgs = @("analyze")
    & flutter @analysisArgs
    exit $LASTEXITCODE
}

# Clean if requested
if (-not $SkipClean) {
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    & flutter clean
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter clean failed"
        exit 1
    }
}

# Get dependencies
Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter pub get failed"
    exit 1
}

# Build AAB
Write-Host ""
Write-Host "Building AAB (this may take 5–10 minutes)..." -ForegroundColor Yellow
Write-Host ""

$buildArgs = @(
    "build", "aab",
    "--release"
)

# Add dart-define parameters
foreach ($param in $defineParams) {
    $buildArgs += "--dart-define=$param"
}

& flutter @buildArgs
$buildExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($buildExitCode -eq 0) {
    Write-Host "✅ AAB Build Successful!" -ForegroundColor Green
    
    $aabPath = "build/app/outputs/bundle/release/app-release.aab"
    if (Test-Path $aabPath) {
        $size = (Get-Item $aabPath).Length
        $sizeGB = [math]::Round($size / 1MB, 2)
        Write-Host "Output: $aabPath ($($sizeGB) MB)" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Upload to Google Play Console"
        Write-Host "2. Upload to Huawei AppGallery"
        Write-Host "3. Test on device before release"
    }
} else {
    Write-Host "❌ AAB Build Failed (exit code: $buildExitCode)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "• Check Flutter/Android SDK installation"
    Write-Host "• Ensure all pubspec dependencies are up-to-date"
    Write-Host "• Try: flutter pub upgrade && flutter clean"
}
Write-Host "========================================" -ForegroundColor Cyan

exit $buildExitCode

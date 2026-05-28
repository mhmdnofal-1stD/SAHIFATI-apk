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

$sharedBuildConfigPath = "tool/build_config.json"
$sharedDefineGeneratorPath = "tool/generate_flutter_defines.dart"
$pubspecPath = "pubspec.yaml"

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

$defineArgs = Get-FlutterDefineArgs -Profile 'release'

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
$defineArgs | ForEach-Object {
    $entry = $_ -replace '^--dart-define=', ''
    $key, $value = $entry.Split('=', 2)
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
Write-Host "Building AAB (this may take 5-10 minutes)..." -ForegroundColor Yellow
Write-Host ""

$buildArgs = @(
    "build", "appbundle",
    "--release"
)

$buildArgs += $defineArgs

& flutter @buildArgs
$buildExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($buildExitCode -eq 0) {
    Write-Host "AAB Build Successful!" -ForegroundColor Green
    
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
    Write-Host "AAB Build Failed (exit code: $buildExitCode)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "- Check Flutter/Android SDK installation"
    Write-Host "- Ensure all pubspec dependencies are up-to-date"
    Write-Host "- Try running flutter pub upgrade, then flutter clean"
}
Write-Host "========================================" -ForegroundColor Cyan

exit $buildExitCode

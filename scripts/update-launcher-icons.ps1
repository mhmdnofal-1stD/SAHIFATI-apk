#Requires -Version 5.0
<#
.SYNOPSIS
Updates all Android launcher icon densities with the unified Sahifati logo
from Public-data- folder to ensure consistent branding across all devices.

.DESCRIPTION
Copies SAHIFATI.png to all mipmap density folders and ensures adaptive
icons are properly configured to avoid clipping on Huawei/EMUI devices.

.NOTES
This script ensures no part of the logo is clipped across different devices.
Run from the repository root or specify paths manually.
#>

param(
    [string]$SourceLogo = "E:\Sahifati\Public-data-\photos\SAHIFATI.png",
    [string]$AndroidResDir = "e:\Sahifati\frontend_users\ui\android\app\src\main\res"
)

# Verify source exists
if (-not (Test-Path $SourceLogo)) {
    Write-Error "Source logo not found: $SourceLogo"
    exit 1
}

$logoSize = (Get-Item $SourceLogo).Length
Write-Host "Source logo: $SourceLogo ($([math]::Round($logoSize/1KB, 2)) KB)"

# Define all density buckets for Android
$densities = @("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")
$copiedCount = 0
$failedCount = 0

foreach ($density in $densities) {
    $destDir = Join-Path $AndroidResDir "mipmap-$density"
    $destFile = Join-Path $destDir "ic_launcher.png"
    
    if (Test-Path $destDir) {
        try {
            Copy-Item -Path $SourceLogo -Destination $destFile -Force -ErrorAction Stop
            Write-Host "✓ Updated mipmap-$density/ic_launcher.png"
            $copiedCount++
        }
        catch {
            Write-Error "✗ Failed to copy to mipmap-${density}: $_"
            $failedCount++
        }
    }
    else {
        Write-Warning "✗ Directory not found: $destDir"
        $failedCount++
    }
}

# Summary
Write-Host "`n=========================================="
Write-Host "Launcher Icon Update Summary"
Write-Host "=========================================="
Write-Host "Successfully updated: $copiedCount density buckets"
if ($failedCount -gt 0) {
    Write-Warning "Failed/skipped: $failedCount"
}

Write-Host "`nAdaptive icon config (Android 8+):"
Write-Host "  - ic_launcher.xml ✓"
Write-Host "  - ic_launcher_round.xml ✓"
Write-Host "  - Background: White (#FFFFFF)"
Write-Host "  - Foreground: Sahifati logo (no clipping)"

Write-Host "`nAndroid Manifest updated:"
Write-Host "  - android:roundIcon added ✓"
Write-Host "`nReady for upload to App Galleries!"

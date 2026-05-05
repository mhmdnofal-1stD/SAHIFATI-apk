param(
  [Parameter(Mandatory = $true)]
  [string]$ReportPath,

  [Parameter(Mandatory = $true)]
  [string]$AlternateZipPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [string]$EntryName = 'alternateNamesV2.txt'
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$resolvedReportPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportPath)
$resolvedZipPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($AlternateZipPath)
$resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$outputDirectory = [System.IO.Path]::GetDirectoryName($resolvedOutputPath)

if (-not [System.IO.Directory]::Exists($outputDirectory)) {
  [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}

$report = Get-Content $resolvedReportPath -Raw | ConvertFrom-Json
$targetIds = [System.Collections.Generic.HashSet[string]]::new()

foreach ($item in $report) {
  $value = [string]$item.geonameId
  if ([string]::IsNullOrWhiteSpace($value)) {
    continue
  }

  [void]$targetIds.Add($value.Trim())
}

if ($targetIds.Count -eq 0) {
  throw 'No geoname ids were found in the report.'
}

$zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedZipPath)

try {
  $entry = $zip.Entries | Where-Object { $_.FullName -eq $EntryName } | Select-Object -First 1
  if ($null -eq $entry) {
    throw "Archive entry '$EntryName' was not found in $resolvedZipPath"
  }

  $matchedLineCount = 0
  $matchedIds = [System.Collections.Generic.HashSet[string]]::new()
  $reader = [System.IO.StreamReader]::new($entry.Open())
  $writer = [System.IO.StreamWriter]::new($resolvedOutputPath, $false, [System.Text.UTF8Encoding]::new($false))

  try {
    while ($null -ne ($line = $reader.ReadLine())) {
      if ([string]::IsNullOrWhiteSpace($line)) {
        continue
      }

      $parts = $line.Split("`t")
      if ($parts.Length -lt 4) {
        continue
      }

      $geonameId = $parts[1].Trim()
      if (-not $targetIds.Contains($geonameId)) {
        continue
      }

      $writer.WriteLine($line)
      $matchedLineCount += 1
      [void]$matchedIds.Add($geonameId)
    }
  }
  finally {
    $writer.Dispose()
    $reader.Dispose()
  }

  Write-Output ("Matched alternate-name lines: " + $matchedLineCount)
  Write-Output ("Matched geoname ids: " + $matchedIds.Count + " / " + $targetIds.Count)
  Write-Output ("Output: " + $resolvedOutputPath)
}
finally {
  $zip.Dispose()
}
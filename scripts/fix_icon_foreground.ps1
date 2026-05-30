Add-Type -AssemblyName System.Drawing
$resBase = "C:\1stD\app\android\app\src\main\res"
$densities = @{ "mipmap-mdpi"=1.0; "mipmap-hdpi"=1.5; "mipmap-xhdpi"=2.0; "mipmap-xxhdpi"=3.0; "mipmap-xxxhdpi"=4.0 }
$src = [System.Drawing.Image]::FromFile("C:\1stD\app\assets\images\clean_logo.png")
foreach ($d in $densities.GetEnumerator()) {
    $c = [int](108 * $d.Value)
    $l = [int](72  * $d.Value)
    $o = [int](($c - $l) / 2)
    $bmp = New-Object System.Drawing.Bitmap($c, $c, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle($o, $o, $l, $l)))
    $g.Dispose()
    $outPath = Join-Path $resBase "$($d.Name)\ic_launcher_foreground.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "OK $($d.Name): canvas=${c}px  logo=${l}px  padding=${o}px"
}
$src.Dispose()
Write-Host "Done."

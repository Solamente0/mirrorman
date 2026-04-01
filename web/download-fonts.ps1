# MirrorMan Font Downloader (Windows PowerShell)
$FontsDir = Join-Path $PSScriptRoot "fonts"
New-Item -ItemType Directory -Force -Path $FontsDir | Out-Null

function Get-Font($Name, $Url) {
    $dest = Join-Path $FontsDir "$Name.woff2"
    if (Test-Path $dest) { Write-Host "  SKIP $Name.woff2" -ForegroundColor Yellow; return }
    Write-Host "  GET  $Name.woff2 ..." -NoNewline
    try {
        Invoke-WebRequest -Uri $Url -OutFile $dest -UserAgent "Mozilla/5.0" -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
    } catch { Write-Host " FAIL: $_" -ForegroundColor Red }
}

Write-Host "`n MirrorMan - Font Downloader`n"

$base = "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/webfonts"
Get-Font "Vazirmatn-Light"     "$base/Vazirmatn-Light.woff2"
Get-Font "Vazirmatn-Regular"   "$base/Vazirmatn-Regular.woff2"
Get-Font "Vazirmatn-Medium"    "$base/Vazirmatn-Medium.woff2"
Get-Font "Vazirmatn-SemiBold"  "$base/Vazirmatn-SemiBold.woff2"
Get-Font "Vazirmatn-Bold"      "$base/Vazirmatn-Bold.woff2"
Get-Font "Vazirmatn-ExtraBold" "$base/Vazirmatn-ExtraBold.woff2"

$jb = "https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/webfonts"
Get-Font "JetBrainsMono-Regular" "$jb/JetBrainsMono-Regular.woff2"
Get-Font "JetBrainsMono-Medium"  "$jb/JetBrainsMono-Medium.woff2"
Get-Font "JetBrainsMono-Bold"    "$jb/JetBrainsMono-Bold.woff2"

Write-Host "`n Done! Open web/index.html in your browser.`n" -ForegroundColor Green

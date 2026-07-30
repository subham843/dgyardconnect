# Strip comments and collapse blank lines in build/web/index.html (smaller first document).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$path = Join-Path (Join-Path $PSScriptRoot '..') 'build\web\index.html'
if (-not (Test-Path $path)) {
  Write-Error "Not found: $path - run flutter build web first."
}
$html = Get-Content -Raw -Encoding UTF8 $path
$html = $html -replace '<!--[\s\S]*?-->', ''
$lines = $html -split [Environment]::NewLine
$html = ($lines | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -ne '' }) -join [Environment]::NewLine
$html = $html.Trim() + [Environment]::NewLine
[System.IO.File]::WriteAllText($path, $html, [System.Text.UTF8Encoding]::new($false))
$bytes = (Get-Item $path).Length
Write-Host ('Minified index.html: {0} bytes' -f $bytes) -ForegroundColor Green

# Production web build - dart2js + CanvasKit only (NO --wasm).
# Wasm bundles the entire app into one main.dart.wasm and disables deferred splits.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

Write-Host 'Building Flutter web (dart2js + CanvasKit, deferred chunks)...' -ForegroundColor Cyan
flutter pub get
flutter build web `
  --release `
  -O4 `
  --no-source-maps `
  --tree-shake-icons `
  --no-web-resources-cdn `
  --no-wasm-dry-run

Write-Host ''
Write-Host 'Stripping sourceMappingURL references (fixes .map -> index.html SyntaxError)...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'strip-web-sourcemaps.ps1')

Write-Host ''
Write-Host 'Minifying index.html (smaller first document for PageSpeed)...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'minify-web-index.ps1')

Write-Host ''
Write-Host 'Removing unused Font Awesome assets from web bundle...' -ForegroundColor Cyan
$faWebAssets = Join-Path 'build\web\assets\packages\font_awesome_flutter' 'lib\fonts'
if (Test-Path $faWebAssets) {
  Remove-Item -Recurse -Force $faWebAssets
  Write-Host 'Removed font_awesome_flutter fonts from build/web.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Verify output (must NOT contain main.dart.wasm):' -ForegroundColor Yellow
if (Test-Path 'build\web\main.dart.wasm') {
  Write-Error 'main.dart.wasm found - remove --wasm from your build command.'
}
Select-String -Path 'build\web\flutter_bootstrap.js' -Pattern 'compileTarget|mainJsPath|mainWasmPath'
Get-ChildItem build\web\*.part.js -ErrorAction SilentlyContinue | Select-Object -First 5 Name
Write-Host ''
Write-Host 'Generating sitemap.xml from Supabase catalog...' -ForegroundColor Cyan
node (Join-Path $PSScriptRoot 'generate_sitemap.mjs')
if ($LASTEXITCODE -ne 0) {
  Write-Error 'Sitemap generation failed.'
}

# Source of truth after generation - must land in the Firebase hosting bundle.
$webSitemap = Join-Path 'web' 'sitemap.xml'
$buildSitemap = Join-Path 'build\web' 'sitemap.xml'
if (-not (Test-Path $buildSitemap)) {
  Write-Error "Missing $buildSitemap - sitemap was not written into the deploy bundle."
}
$srcHash = (Get-FileHash $webSitemap -Algorithm SHA256).Hash
$dstHash = (Get-FileHash $buildSitemap -Algorithm SHA256).Hash
if ($srcHash -ne $dstHash) {
  Write-Error 'web/sitemap.xml and build/web/sitemap.xml differ after generation.'
}
$urlCount = (Select-String -Path $buildSitemap -Pattern '<url>' -AllMatches).Matches.Count
Write-Host ('Sitemap ready for deploy: ' + $urlCount + ' URLs in build/web/sitemap.xml') -ForegroundColor Green
if (Select-String -Path $buildSitemap -Pattern 'dgyard-connect\.web\.app|/login' -Quiet) {
  Write-Error 'build/web/sitemap.xml still contains old domain or /login.'
}

Write-Host ''
Write-Host 'Copy robots.txt into deploy bundle...' -ForegroundColor Cyan
Copy-Item -Force (Join-Path 'web' 'robots.txt') (Join-Path 'build\web' 'robots.txt')

Write-Host ''
Write-Host 'Deploy: firebase deploy --only hosting' -ForegroundColor Green

# Deploy only hosting static SEO files (sitemap + robots) without a full Flutter rebuild.
# Use after: node scripts/generate_sitemap.mjs  OR  when build/web already exists.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$buildWeb = Join-Path 'build' 'web'
if (-not (Test-Path $buildWeb)) {
  Write-Error 'build/web not found. Run: powershell -File scripts/build-web-prod.ps1'
}

Write-Host 'Regenerating sitemap.xml...' -ForegroundColor Cyan
node (Join-Path $PSScriptRoot 'generate_sitemap.mjs')

Copy-Item -Force (Join-Path 'web' 'robots.txt') (Join-Path $buildWeb 'robots.txt')

$sitemap = Join-Path $buildWeb 'sitemap.xml'
$urlCount = (Select-String -Path $sitemap -Pattern '<url>' -AllMatches).Matches.Count
Write-Host "Deploying hosting bundle ($urlCount sitemap URLs)..." -ForegroundColor Cyan
firebase deploy --only hosting

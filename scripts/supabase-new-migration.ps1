# Create a new timestamped migration file.
# Usage: powershell -File scripts/supabase-new-migration.ps1 -Name "add_product_discount"
param(
  [Parameter(Mandatory = $true)]
  [string]$Name
)

$slug = $Name.ToLower() -replace '[^a-z0-9]+', '_'
$slug = $slug.Trim('_')
$ts = Get-Date -Format "yyyyMMddHHmmss"
$repoRoot = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repoRoot "supabase\migrations\${ts}_${slug}.sql"

$template = @"
-- Migration: $Name
-- Created: $(Get-Date -Format "yyyy-MM-dd HH:mm")

-- TODO: SQL here (CREATE / ALTER / INSERT seed)
-- Remember: enable RLS on new tables (see 005_rls.sql patterns)

"@

New-Item -ItemType File -Path $path -Force | Out-Null
Set-Content -Path $path -Value $template -Encoding UTF8
Write-Host "Created: $path" -ForegroundColor Green
Write-Host "Edit SQL, then run: npm run deploy:supabase" -ForegroundColor Cyan

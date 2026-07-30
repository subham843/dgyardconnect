# Single entry point for agent / developer — supabase operations

param(
  [Parameter(Position = 0)]
  [ValidateSet('deploy', 'db-push', 'new-migration', 'status', 'functions', 'login')]
  [string]$Command = 'status',

  [string]$Name = ''
)

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SupabaseDir = Join-Path $RepoRoot "supabase"
Set-Location $RepoRoot

function Invoke-Sb {
  param([Parameter(Mandatory = $true)][string[]]$SbArgs)
  & npx --yes supabase@latest --workdir $RepoRoot @SbArgs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

switch ($Command) {
  'deploy' {
    & "$PSScriptRoot\deploy-supabase.ps1"
  }
  'login' {
    Invoke-Sb -SbArgs @('login')
  }
  'db-push' {
    Write-Host "Pushing migrations..." -ForegroundColor Cyan
    Invoke-Sb -SbArgs @('db', 'push', '--yes')
    Write-Host "Done." -ForegroundColor Green
  }
  'new-migration' {
    if (-not $Name) { Write-Host "Use -Name describe_change"; exit 1 }
    & "$PSScriptRoot\supabase-new-migration.ps1" -Name $Name
  }
  'functions' {
    if (-not $env:SUPABASE_ACCESS_TOKEN) {
      $envPath = Join-Path $SupabaseDir ".env"
      if (Test-Path $envPath) {
        Get-Content $envPath -Encoding UTF8 | ForEach-Object {
          if ($_ -match '^\s*SUPABASE_ACCESS_TOKEN=(.+)$') {
            $env:SUPABASE_ACCESS_TOKEN = $matches[1].Trim().Trim('"')
          }
        }
      }
    }
    & npx --yes supabase@latest functions deploy exchange-firebase-token --project-ref xtnfmrourhzspehvhrkz --workdir $RepoRoot --no-verify-jwt
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  'status' {
    Write-Host "Project: xtnfmrourhzspehvhrkz" -ForegroundColor Cyan
    Write-Host "Migrations:" (Get-ChildItem "$SupabaseDir\migrations\*.sql").Count
    if (Test-Path "$SupabaseDir\.env") { Write-Host ".env: OK" -ForegroundColor Green }
    else { Write-Host ".env: MISSING (copy .env.example)" -ForegroundColor Yellow }
    Invoke-Sb -SbArgs @('projects', 'list')
  }
}

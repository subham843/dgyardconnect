# Deploy Supabase schema + Edge Functions (like: firebase deploy --only functions)
# Run from repo root:  npm run deploy:supabase

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SupabaseDir = Join-Path $RepoRoot "supabase"
$ProjectRef = "xtnfmrourhzspehvhrkz"
Set-Location $RepoRoot

function Import-DgyardSupabaseEnv {
  param([string]$Path)
  $vars = @{}
  if (-not (Test-Path $Path)) { return $vars }
  Get-Content $Path -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $i = $line.IndexOf('=')
    if ($i -lt 1) { return }
    $k = $line.Substring(0, $i).Trim()
    $v = $line.Substring($i + 1).Trim().Trim('"').Trim("'")
    $vars[$k] = $v
  }
  return $vars
}

function Set-SupabaseAccessTokenFromEnvFile {
  param([hashtable]$Vars)
  if ($env:SUPABASE_ACCESS_TOKEN) { return $true }
  $token = $Vars['SUPABASE_ACCESS_TOKEN']
  if ($token -and $token.Trim().Length -gt 0) {
    $env:SUPABASE_ACCESS_TOKEN = $token.Trim()
    return $true
  }
  return $false
}

function Test-SupabaseAccessTokenAvailable {
  param([hashtable]$Vars)
  if ($env:SUPABASE_ACCESS_TOKEN) { return $true }
  return Set-SupabaseAccessTokenFromEnvFile -Vars $Vars
}

# Project root must contain supabase/config.toml + supabase/migrations (not workdir=supabase/ itself).
function Invoke-Supabase {
  param([Parameter(Mandatory = $true)][string[]]$SbArgs)
  & npx --yes supabase@latest --workdir $RepoRoot @SbArgs
  if ($LASTEXITCODE -ne 0) {
    throw "supabase $($SbArgs -join ' ') failed (exit $LASTEXITCODE)"
  }
}

# Management API (secrets, functions): needs SUPABASE_ACCESS_TOKEN in this process.
# Browser login stores token in Windows Credential Manager; child npx often cannot read it.
function Invoke-SupabaseMgmt {
  param([Parameter(Mandatory = $true)][string[]]$SbArgs)
  if (-not $env:SUPABASE_ACCESS_TOKEN) {
    throw @"
SUPABASE_ACCESS_TOKEN is not set.
Add a Personal Access Token to supabase/.env (CLI only — not uploaded to Edge Functions):
  Dashboard -> Account -> Access Tokens -> Generate new token
  SUPABASE_ACCESS_TOKEN=sbp_...
See supabase/.env.example
"@
  }
  & npx --yes supabase@latest @SbArgs
  if ($LASTEXITCODE -ne 0) {
    throw "supabase $($SbArgs -join ' ') failed (exit $LASTEXITCODE)"
  }
}

function Test-SupabaseLoggedIn {
  $paths = @(
    (Join-Path $env:USERPROFILE ".supabase\access-token"),
    (Join-Path $env:APPDATA "supabase\access-token")
  )
  foreach ($p in $paths) {
    if (Test-Path $p) { return $true }
  }
  return $false
}

$envFile = Join-Path $SupabaseDir ".env"
$envVars = Import-DgyardSupabaseEnv -Path $envFile
[void](Set-SupabaseAccessTokenFromEnvFile -Vars $envVars)

Write-Host ""
Write-Host "=== DG Yard Connect - Supabase deploy ===" -ForegroundColor Cyan
Write-Host "Project ref: $ProjectRef" -ForegroundColor Gray
Write-Host ""

# 1) Login (opens browser once; optional if token is in .env)
Write-Host "[1/5] Login..." -ForegroundColor Yellow
if (Test-SupabaseAccessTokenAvailable -Vars $envVars) {
  Write-Host "  Using SUPABASE_ACCESS_TOKEN from supabase/.env" -ForegroundColor Green
} elseif (Test-SupabaseLoggedIn) {
  Write-Host "  CLI login file found (mgmt steps still need token in .env on Windows)." -ForegroundColor Gray
} else {
  Write-Host "  Opening browser for supabase login..." -ForegroundColor Gray
  Invoke-Supabase -SbArgs @("login")
  $envVars = Import-DgyardSupabaseEnv -Path $envFile
  [void](Set-SupabaseAccessTokenFromEnvFile -Vars $envVars)
}

# 2) Link project
Write-Host "[2/5] Linking project..." -ForegroundColor Yellow
$linkedRef = Join-Path $SupabaseDir ".temp\project-ref"
# Link metadata lives under supabase/.temp whether workdir is repo root or supabase folder.
if (-not (Test-Path $linkedRef)) {
  Invoke-Supabase -SbArgs @("link", "--project-ref", $ProjectRef)
} else {
  Write-Host "  Already linked." -ForegroundColor Green
}

# 3) Push database migrations (creates all tables)
Write-Host "[3/5] Pushing database migrations (tables)..." -ForegroundColor Yellow
Invoke-Supabase -SbArgs @("db", "push", "--yes")

# 4) Secrets for edge function (only function keys — never upload ACCESS_TOKEN)
Write-Host "[4/5] Setting Edge Function secrets..." -ForegroundColor Yellow
[void](Test-SupabaseAccessTokenAvailable -Vars $envVars)

$firebaseId = if ($envVars['FIREBASE_PROJECT_ID']) { $envVars['FIREBASE_PROJECT_ID'] } else { 'dgyard-connect' }
$jwtSecret = $envVars['SUPABASE_JWT_SECRET']

$secretPairs = @(
  "FIREBASE_PROJECT_ID=$firebaseId"
)
if ($jwtSecret -and $jwtSecret.Trim().Length -gt 0) {
  $secretPairs += "JWT_SECRET=$($jwtSecret.Trim())"
}
foreach ($aiKey in @('GROQ_API_KEY', 'GEMINI_API_KEY', 'OPENAI_API_KEY')) {
  $v = $envVars[$aiKey]
  if ($v -and $v.Trim().Length -gt 0) {
    $secretPairs += "$aiKey=$($v.Trim())"
  }
}
foreach ($rpKey in @('RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET')) {
  $v = $envVars[$rpKey]
  if ($v -and $v.Trim().Length -gt 0) {
    $secretPairs += "$rpKey=$($v.Trim())"
  }
}
$textProvider = $envVars['TEXT_AI_PROVIDER']
if ($textProvider -and $textProvider.Trim().Length -gt 0) {
  $secretPairs += "TEXT_AI_PROVIDER=$($textProvider.Trim())"
}

$hasJwt = $jwtSecret -and $jwtSecret.Trim().Length -gt 0
$hasAi = $secretPairs.Count -gt 1 -and ($secretPairs | Where-Object { $_ -match '^(GROQ|GEMINI|OPENAI|TEXT_AI)' }).Count -gt 0

if ($hasJwt -and $secretPairs.Count -ge 2) {
  Invoke-SupabaseMgmt -SbArgs @(
    'secrets', 'set',
    '--project-ref', $ProjectRef
  ) + $secretPairs
  Write-Host "  Edge secrets set ($($secretPairs.Count) keys)" -ForegroundColor Green
} elseif ($hasAi) {
  $aiOnly = $secretPairs | Where-Object { $_ -notmatch '^FIREBASE_PROJECT_ID=' }
  Invoke-SupabaseMgmt -SbArgs @(
    'secrets', 'set',
    '--project-ref', $ProjectRef
  ) + $aiOnly
  Write-Host "  AI secrets updated ($($aiOnly.Count) keys)" -ForegroundColor Green
} elseif ($hasJwt) {
  Invoke-SupabaseMgmt -SbArgs @(
    'secrets', 'set',
    '--project-ref', $ProjectRef,
    "FIREBASE_PROJECT_ID=$firebaseId",
    "JWT_SECRET=$($jwtSecret.Trim())"
  )
  Write-Host "  Edge secrets set (FIREBASE_PROJECT_ID, JWT_SECRET)" -ForegroundColor Green
} else {
  Write-Host "  WARNING: SUPABASE_JWT_SECRET missing in supabase/.env" -ForegroundColor Red
  Write-Host '  Copy supabase/.env.example to supabase/.env and set JWT Secret from Dashboard -> API' -ForegroundColor Red
  $jwt = Read-Host "  Paste JWT Secret now (or Enter to skip)"
  if ($jwt -and $jwt.Trim().Length -gt 0) {
    Invoke-SupabaseMgmt -SbArgs @(
      'secrets', 'set',
      '--project-ref', $ProjectRef,
      "FIREBASE_PROJECT_ID=$firebaseId",
      "JWT_SECRET=$($jwt.Trim())"
    )
  }
}

# 5) Deploy edge functions
Write-Host "[5/5] Deploying Edge Functions..." -ForegroundColor Yellow
[void](Test-SupabaseAccessTokenAvailable -Vars $envVars)
$fnDeploy = @(
  @('functions', 'deploy', 'exchange-firebase-token', '--project-ref', $ProjectRef, '--workdir', $RepoRoot, '--no-verify-jwt'),
  @('functions', 'deploy', 'shop-razorpay', '--project-ref', $ProjectRef, '--workdir', $RepoRoot, '--no-verify-jwt'),
  @('functions', 'deploy', 'platform-text-assist', '--project-ref', $ProjectRef, '--workdir', $RepoRoot),
  @('functions', 'deploy', 'platform-datasheet-extract', '--project-ref', $ProjectRef, '--workdir', $RepoRoot),
  @('functions', 'deploy', 'platform-product-import', '--project-ref', $ProjectRef, '--workdir', $RepoRoot),
  @('functions', 'deploy', 'platform-image-generate', '--project-ref', $ProjectRef, '--workdir', $RepoRoot)
)
foreach ($args in $fnDeploy) {
  Invoke-SupabaseMgmt -SbArgs $args
}

Write-Host ""
Write-Host "Done. Check Supabase Dashboard: Table Editor and Edge Functions." -ForegroundColor Green
Write-Host ""

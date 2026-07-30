# Remove //# sourceMappingURL= lines from deployed JS so Firebase SPA rewrite
# does not return index.html for missing .map files (SyntaxError: Unexpected token '<').
param(
  [string]$WebDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'build\web')
)

if (-not (Test-Path $WebDir)) {
  Write-Error "Directory not found: $WebDir (run flutter build web first)"
}

$pattern = '(?m)(^\s*//[#@]\s*sourceMappingURL=.*(\r?\n)?|//[#@]\s*sourceMappingURL=[^\r\n]*)'
$files = Get-ChildItem -Path $WebDir -Recurse -File -Include *.js,*.mjs
$stripped = 0

foreach ($file in $files) {
  $content = [IO.File]::ReadAllText($file.FullName)
  $updated = [regex]::Replace($content, $pattern, '')
  if ($updated -ne $content) {
    [IO.File]::WriteAllText($file.FullName, $updated)
    $stripped++
    Write-Host "Stripped source map reference: $($file.Name)"
  }
}

# Delete orphan .map files from release output (we build with --no-source-maps).
Get-ChildItem -Path $WebDir -Recurse -File -Filter *.map -ErrorAction SilentlyContinue |
  ForEach-Object {
    Remove-Item $_.FullName -Force
    Write-Host "Removed: $($_.Name)"
  }

Write-Host "Done. Processed $($files.Count) JS files; stripped $stripped."

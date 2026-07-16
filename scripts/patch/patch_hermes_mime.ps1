param(
    [Parameter(Mandatory=$true)]
    [string]$RepoDir
)

$ErrorActionPreference = "Stop"

$webServerPath = Join-Path (Join-Path $RepoDir "hermes_cli") "web_server.py"

if (-not (Test-Path $webServerPath)) {
    Write-Error "File not found: $webServerPath"
    exit 2
}

$content = Get-Content -Path $webServerPath -Raw -Encoding UTF8

# Check if already patched
if ($content -match 'mimetypes\.add_type\("application/javascript"') {
    Write-Host "[INFO] Already patched." -ForegroundColor Cyan
    exit 1
}

# Find existing "import mimetypes" line and add types after it
$lines = $content -split "`r?`n"
$newLines = @()
$patched = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $newLines += $lines[$i]
    
    # After "import mimetypes" line, add our types (only once)
    if (-not $patched -and $lines[$i].Trim() -eq "import mimetypes") {
        $newLines += 'mimetypes.add_type("application/javascript", ".js")'
        $newLines += 'mimetypes.add_type("text/css", ".css")'
        $newLines += 'mimetypes.add_type("application/json", ".json")'
        $patched = $true
    }
}

if (-not $patched) {
    # Fallback: no "import mimetypes" found, insert at top
    $insertIdx = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -and -not $lines[$i].Trim().StartsWith("#")) {
            $insertIdx = $i
            break
        }
    }
    $patchLines = @("import mimetypes", 'mimetypes.add_type("application/javascript", ".js")', 'mimetypes.add_type("text/css", ".css")', 'mimetypes.add_type("application/json", ".json")', "")
    $before = $lines[0..($insertIdx - 1)]
    $after = $lines[$insertIdx..($lines.Count - 1)]
    $newLines = $before + $patchLines + $after
}

Set-Content -Path $webServerPath -Value ($newLines -join "`n") -Encoding UTF8 -NoNewline

Write-Host "[OK] Patched: $webServerPath" -ForegroundColor Green
exit 0
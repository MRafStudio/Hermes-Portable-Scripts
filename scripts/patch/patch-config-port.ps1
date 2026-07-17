# scripts\patch\patch-config-port.ps1
# Правка порта в config.yaml (только для local-model)

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,
    [Parameter(Mandatory=$true)]
    [int]$NewPort
)

if (-not (Test-Path $ConfigPath)) {
    Write-Host "  !   config.yaml not found: $ConfigPath" -ForegroundColor Yellow
    exit 1
}

$lines = Get-Content $ConfigPath -Encoding UTF8
$result = @()
$modified = $false
$inModelBlock = $false
$modelBaseIndent = -1
$isLocalModel = $false
$baseUrlDone = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.TrimStart()
    $indent = $line.Length - $trimmed.Length
    
    # Определяем блок model:
    if (-not $inModelBlock -and $trimmed -match '^model:\s*$') {
        $inModelBlock = $true
        $modelBaseIndent = $indent
        $result += $line
        continue
    }
    
    if ($inModelBlock) {
        # Проверяем выход из блока
        if ($indent -le $modelBaseIndent -and $trimmed -ne '' -and -not $trimmed.StartsWith('#')) {
            $inModelBlock = $false
            $result += $line
            continue
        }
        
        # Проверяем что это local-model
        if ($trimmed -match '^default:\s*"local-model"') {
            $isLocalModel = $true
        }
        
        # Меняем порт только если local-model
        if ($isLocalModel -and -not $baseUrlDone -and $trimmed -match '^base_url:\s*"http://127\.0\.0\.1:\d+/v1"') {
            $line = (' ' * ($modelBaseIndent + 2)) + "base_url: `"http://127.0.0.1:$NewPort/v1`""
            $baseUrlDone = $true
            $modified = $true
        }
        
        $result += $line
        continue
    }
    
    $result += $line
}

if ($modified) {
    $result | Set-Content $ConfigPath -Encoding UTF8
    Write-Host "  +   The port in config.yaml has been updated: $NewPort" -ForegroundColor Green
    exit 0
} elseif ($isLocalModel) {
    Write-Host "  .   The port in config.yaml is already up to date." -ForegroundColor Green
    exit 0
} else {
    Write-Host "  .   Not a local-model configuration, we’re not changing the port." -ForegroundColor Yellow
    exit 1
}
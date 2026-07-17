# scripts\patch\config-kobold.ps1
# Патч config.yaml для KoboldCpp

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,
    [int]$ContextLength = 65536
)

if (-not (Test-Path $ConfigPath)) {
    Write-Host "  !   config.yaml not found. Skipping the patch." -ForegroundColor Yellow
    exit 0
}

# === БЭКАП ===
$BackupPath = "$ConfigPath.bak"
if (-not (Test-Path $BackupPath)) {
    Copy-Item $ConfigPath $BackupPath -Force
    Write-Host "  +   Backup created: $BackupPath" -ForegroundColor DarkGray
}

# === ПРЕДВАРИТЕЛЬНЫЙ ПРОХОД: проверяем, есть ли уже параметры в блоке model: ===
$allLines = Get-Content $ConfigPath -Encoding UTF8
$inModelBlockScan = $false
$modelBaseIndentScan = -1
$contextFileExists = $false
$contextLengthExists = $false
$maxTokensExists = $false

for ($i = 0; $i -lt $allLines.Count; $i++) {
    $line = $allLines[$i]
    $trimmed = $line.TrimStart()
    $indent = $line.Length - $trimmed.Length
    
    if (-not $inModelBlockScan -and $trimmed -match '^model:\s*$') {
        $inModelBlockScan = $true
        $modelBaseIndentScan = $indent
        continue
    }
    
    if ($inModelBlockScan) {
        if ($indent -le $modelBaseIndentScan -and $trimmed -ne '' -and -not $trimmed.StartsWith('#')) {
            $inModelBlockScan = $false
            continue
        }
        if ($trimmed -match '^context_file_max_chars:') {
            $contextFileExists = $true
        }
        if ($trimmed -match '^context_length:') {
            $contextLengthExists = $true
        }
        if ($trimmed -match '^max_tokens:') {
            $maxTokensExists = $true
        }
    }
}

# Читаем построчно для патча
$lines = $allLines
$result = @()
$modified = $false

# Состояния
$inModelBlock = $false
$modelBaseIndent = -1
$providerDone = $false
$baseUrlDone = $false
$defaultDone = $false
$contextFileDone = $contextFileExists
$maxTokensDone = $maxTokensExists
$contextLengthDone = $contextLengthExists
$maxSessionsDone = $false
$insertAfterBaseUrl = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.TrimStart()
    $indent = $line.Length - $trimmed.Length
    
    # === Определяем блок model: ===
    if (-not $inModelBlock -and $trimmed -match '^model:\s*$') {
        $inModelBlock = $true
        $modelBaseIndent = $indent
        $result += $line
        continue
    }
    
    # === Внутри блока model: ===
    if ($inModelBlock) {
        # Проверяем, не вышли ли из блока
        if ($indent -le $modelBaseIndent -and $trimmed -ne '' -and -not $trimmed.StartsWith('#')) {
            $inModelBlock = $false
            # === ВСТАВКА ПРИ ВЫХОДЕ ИЗ БЛОКА ===
            # Если base_url был обработан, но параметры не вставились — вставляем ПЕРЕД выходом
            if ($insertAfterBaseUrl) {
                if (-not $contextLengthDone) {
                    $result += (' ' * ($modelBaseIndent + 2)) + "context_length: $ContextLength"
                    $contextLengthDone = $true
                    $modified = $true
                }
                if (-not $maxTokensDone) {
                    $result += (' ' * ($modelBaseIndent + 2)) + 'max_tokens: 4096'
                    $maxTokensDone = $true
                    $modified = $true
                }
                if (-not $contextFileDone) {
                    $result += (' ' * ($modelBaseIndent + 2)) + 'context_file_max_chars: 80000'
                    $contextFileDone = $true
                    $modified = $true
                }
                $insertAfterBaseUrl = $false
            }
            $result += $line
            continue
        }
        
        # provider: auto/openrouter/custom → custom (с кавычками или без)
        if (-not $providerDone -and $trimmed -match '^provider:\s*"?auto"?') {
            $line = (' ' * ($modelBaseIndent + 2)) + 'provider: "custom"'
            $providerDone = $true
            $modified = $true
        }
        elseif (-not $providerDone -and $trimmed -match '^provider:\s*"?openrouter"?') {
            $line = (' ' * ($modelBaseIndent + 2)) + 'provider: "custom"'
            $providerDone = $true
            $modified = $true
        }
        elseif (-not $providerDone -and $trimmed -match '^provider:\s*"?custom"?') {
            $providerDone = $true
        }
        
        # default: claude → local-model (с кавычками или без)
        if (-not $defaultDone -and $trimmed -match '^default:\s*"?anthropic/claude-opus-4\.6"?') {
            $line = (' ' * ($modelBaseIndent + 2)) + 'default: "local-model"'
            $defaultDone = $true
            $modified = $true
        }
        elseif (-not $defaultDone -and $trimmed -match '^default:\s*"?local-model"?') {
            $defaultDone = $true
        }
        
        # base_url: openrouter → localhost (с кавычками или без)
        if (-not $baseUrlDone -and $trimmed -match '^base_url:\s*"?https://openrouter\.ai/api/v1"?') {
            $line = (' ' * ($modelBaseIndent + 2)) + 'base_url: "http://127.0.0.1:5001/v1"'
            $baseUrlDone = $true
            $modified = $true
            $insertAfterBaseUrl = $true
        }
        elseif (-not $baseUrlDone -and $trimmed -match '^base_url:\s*"?http://127\.0\.0\.1:5001/v1"?') {
            $baseUrlDone = $true
            $insertAfterBaseUrl = $true
        }
        
        # === context_length: раскомментированная или закомментированная с цифрой ===
        if (-not $contextLengthDone -and $trimmed -match '^context_length:\s*\d+') {
            $line = (' ' * ($modelBaseIndent + 2)) + "context_length: $ContextLength"
            $contextLengthDone = $true
            $modified = $true
        }
        elseif (-not $contextLengthDone -and $trimmed -match '^#\s*context_length:\s*\d+') {
            $line = (' ' * ($modelBaseIndent + 2)) + "context_length: $ContextLength"
            $contextLengthDone = $true
            $modified = $true
        }
        
        # === max_tokens: раскомментированная или закомментированная с цифрой ===
        if (-not $maxTokensDone -and $trimmed -match '^max_tokens:\s*\d+') {
            $line = (' ' * ($modelBaseIndent + 2)) + 'max_tokens: 4096'
            $maxTokensDone = $true
            $modified = $true
        }
        elseif (-not $maxTokensDone -and $trimmed -match '^#\s*max_tokens:\s*\d+') {
            $line = (' ' * ($modelBaseIndent + 2)) + 'max_tokens: 4096'
            $maxTokensDone = $true
            $modified = $true
        }
        
        # === context_file_max_chars уже есть? ===
        if ($trimmed -match '^context_file_max_chars:') {
            $contextFileDone = $true
        }
        
        # === Вставка после base_url ===
        if ($insertAfterBaseUrl) {
            $result += $line
            if (-not $contextLengthDone) {
                $result += (' ' * ($modelBaseIndent + 2)) + "context_length: $ContextLength"
                $contextLengthDone = $true
                $modified = $true
            }
            if (-not $maxTokensDone) {
                $result += (' ' * ($modelBaseIndent + 2)) + 'max_tokens: 4096'
                $maxTokensDone = $true
                $modified = $true
            }
            if (-not $contextFileDone) {
                $result += (' ' * ($modelBaseIndent + 2)) + 'context_file_max_chars: 80000'
                $contextFileDone = $true
                $modified = $true
            }
            $insertAfterBaseUrl = $false
            continue
        }
        
        $result += $line
        continue
    }
    
    # === Вне блока model: ===
    # Закомментировать max_concurrent_sessions: null
    if (-not $maxSessionsDone -and $trimmed -match '^max_concurrent_sessions:\s*null') {
        $line = (' ' * $indent) + '# max_concurrent_sessions: null'
        $maxSessionsDone = $true
        $modified = $true
    }
    
    $result += $line
}

# Сохраняем
if ($modified) {
    while ($result.Count -gt 0 -and $result[-1].Trim() -eq '') {
        $result = $result[0..($result.Count - 2)]
    }
    
    $result | Set-Content $ConfigPath -Encoding UTF8
    
    Write-Host "    +   config.yaml success patched for KoboldCpp." -ForegroundColor Green
    Write-Host "        provider: custom" -ForegroundColor DarkGray
    Write-Host "        base_url: http://127.0.0.1:5001/v1" -ForegroundColor DarkGray
    Write-Host "        default: local-model" -ForegroundColor DarkGray
    if ($contextFileDone) {
        Write-Host "        context_file_max_chars: 80000" -ForegroundColor DarkGray
    }
    Write-Host "        max_tokens: 4096" -ForegroundColor DarkGray
    Write-Host "        context_length: $ContextLength" -ForegroundColor DarkGray
} else {
    Write-Host "    +   config.yaml already configured for KoboldCpp." -ForegroundColor Green
}

exit 0
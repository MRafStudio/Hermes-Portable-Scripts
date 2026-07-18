# scripts\patch\patch_config_llm_yaml.ps1
# Патч config.yaml для KoboldCpp
# Параметры:
#   ConfigPath     — путь к config.yaml (обязательный)
#   ContextLength  — context_length в блоке model: (по умолчанию 65536)
#   MaxTokens      — max_tokens; 0 или не передан — НЕ ДОБАВЛЯТЬ и НЕ ИЗМЕНЯТЬ
#
# Семантика: ENFORCE с идемпотентностью. Ключи, принадлежащие патчу
# (provider, default, base_url, context_length), ПРИВОДЯТСЯ к целевым
# значениям: отличается — исправляем, совпадает — не трогаем (и тогда
# честный "already configured"), ДУБЛИКАТ — удаляем.
# max_tokens патчу НЕ принадлежит (только по явному -MaxTokens > 0).

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,
    [int]$ContextLength = 65536,
    [int]$MaxTokens = 0
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

# === ПРЕДВАРИТЕЛЬНЫЙ ПРОХОД: что вообще есть в блоке model: ===
# (для ВСТАВКИ: не плодить новые строки, если параметр уже существует —
#  активный ИЛИ закомментированный; enforce существующих — ниже в цикле)
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
        if ($trimmed -match '^#?\s*context_length:\s*\d+') {
            $contextLengthExists = $true
        }
        if ($trimmed -match '^#?\s*max_tokens:\s*\d+') {
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
$contextLengthDone = $false
$maxSessionsDone = $false
$insertAfterBaseUrl = $false

# === max_tokens: КЛЮЧЕВАЯ СТРОКА ===
# Не передан (0) — все операции с max_tokens пропускаются (done = true).
# Передан (> 0) — enforce: обновляем / раскомментируем / добавляем.
$maxTokensDone = ($MaxTokens -le 0)

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
            if ($insertAfterBaseUrl) {
                if (-not $contextLengthDone -and -not $contextLengthExists) {
                    $result += (' ' * ($modelBaseIndent + 2)) + "context_length: $ContextLength"
                    $contextLengthDone = $true
                    $modified = $true
                }
                if (-not $maxTokensDone -and -not $maxTokensExists) {
                    $result += (' ' * ($modelBaseIndent + 2)) + "max_tokens: $MaxTokens"
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

        # provider: ЛЮБОЕ значение != custom → custom (enforce)
        if (-not $providerDone -and $trimmed -match '^provider:\s*"?([^"\s]+)"?') {
            if ($matches[1] -ne 'custom') {
                $line = (' ' * ($modelBaseIndent + 2)) + 'provider: "custom"'
                $modified = $true
            }
            $providerDone = $true
        }

        # default: ЛЮБОЕ значение != local-model → local-model (enforce)
        if (-not $defaultDone -and $trimmed -match '^default:\s*"?([^"\s]+)"?') {
            if ($matches[1] -ne 'local-model') {
                $line = (' ' * ($modelBaseIndent + 2)) + 'default: "local-model"'
                $modified = $true
            }
            $defaultDone = $true
        }

        # base_url: ЛЮБОЕ значение != localhost:5001 → localhost (enforce)
        if (-not $baseUrlDone -and $trimmed -match '^base_url:\s*"?([^"\s]+)"?') {
            if ($matches[1] -ne 'http://127.0.0.1:5001/v1') {
                $line = (' ' * ($modelBaseIndent + 2)) + 'base_url: "http://127.0.0.1:5001/v1"'
                $modified = $true
            }
            $baseUrlDone = $true
            $insertAfterBaseUrl = $true
        }

        # === context_length: enforce — любое число != $ContextLength исправляем ===
        if (-not $contextLengthDone -and $trimmed -match '^context_length:\s*(\d+)') {
            if ($matches[1] -ne "$ContextLength") {
                $line = (' ' * ($modelBaseIndent + 2)) + "context_length: $ContextLength"
                $modified = $true
            }
            $contextLengthDone = $true
        }
        elseif (-not $contextLengthDone -and $trimmed -match '^#\s*context_length:\s*\d+') {
            $line = (' ' * ($modelBaseIndent + 2)) + "context_length: $ContextLength"
            $contextLengthDone = $true
            $modified = $true
        }
        elseif ($contextLengthDone -and $trimmed -match '^context_length:\s*\d+') {
            # ДУБЛИКАТ активной строки — удаляем (не кладём в результат)
            $modified = $true
            continue
        }

        # === max_tokens: ТОЛЬКО если передан извне (> 0), тоже enforce ===
        if (-not $maxTokensDone -and $trimmed -match '^max_tokens:\s*(\d+)') {
            if ($matches[1] -ne "$MaxTokens") {
                $line = (' ' * ($modelBaseIndent + 2)) + "max_tokens: $MaxTokens"
                $modified = $true
            }
            $maxTokensDone = $true
        }
        elseif (-not $maxTokensDone -and $trimmed -match '^#\s*max_tokens:\s*\d+') {
            $line = (' ' * ($modelBaseIndent + 2)) + "max_tokens: $MaxTokens"
            $maxTokensDone = $true
            $modified = $true
        }
        elseif ($maxTokensDone -and $MaxTokens -gt 0 -and $trimmed -match '^max_tokens:\s*\d+') {
            # ДУБЛИКАТ активной строки — удаляем (только при enforce-режиме)
            $modified = $true
            continue
        }

        # === context_file_max_chars уже есть? ===
        if ($trimmed -match '^context_file_max_chars:') {
            $contextFileDone = $true
        }

        # === Вставка после base_url ===
        if ($insertAfterBaseUrl) {
            $result += $line
            if (-not $contextLengthDone -and -not $contextLengthExists) {
                $result += (' ' * ($modelBaseIndent + 2)) + "context_length: $ContextLength"
                $contextLengthDone = $true
                $modified = $true
            }
            if (-not $maxTokensDone -and -not $maxTokensExists) {
                $result += (' ' * ($modelBaseIndent + 2)) + "max_tokens: $MaxTokens"
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
    if ($MaxTokens -gt 0) {
        Write-Host "        max_tokens: $MaxTokens" -ForegroundColor DarkGray
    }
    Write-Host "        context_length: $ContextLength" -ForegroundColor DarkGray
} else {
    Write-Host "    +   config.yaml already configured for KoboldCpp." -ForegroundColor Green
}

exit 0
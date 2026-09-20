# patch_install_ps1.ps1 -- portable-layer patches for the upstream repo's
# scripts/install.ps1 inside $HERMES_HOME\hermes-agent.
#
# Why: the wrapper resets that repo to origin/main on every update, so any edit
# made directly in the file is lost. This script re-applies the two patches from
# the durable side (D:\NEURO\Hermes\scripts\ps1), and is wired into
# InstallOrUpdate-Desktop.bat / InstallOrUpdate-Web.bat right before install.ps1
# is launched.
#
#   1) Drops the leaked `$env:UV_NO_CONFIG = "1"` from
#      Initialize-ManagedPythonEnvironment. That export survived into the later
#      `uv sync --extra all --locked`, hid pyproject's [tool.uv] exclude-newer, so
#      uv had to re-resolve and --locked refused -> the SHA256 hash-verified tier
#      ALWAYS failed and the installer fell back to a lock-free PyPI resolve that
#      ignores the 14-day quarantine (~51 packages drift off the lock).
#      Every `uv python find/install` call in that file already passes
#      --no-config explicitly, so the env export was redundant.
#
#   2) Replaces the Start-Process -PassThru launcher in _Invoke-NativeWithTimeout
#      with the .NET ProcessStartInfo pattern. On Windows PowerShell 5.1 a
#      Start-Process -PassThru object returns $null from .ExitCode, so every
#      npm / Playwright step printed "failed -- exit code " with an empty value
#      and the `if ($browserNpmOk)` gate never opened (Playwright Chromium was
#      never installed).
#
# Idempotent. EOL-aware: .gitattributes pins *.ps1 to CRLF, but an LF checkout
# must not make the patch silently skip. Validates the result with the PowerShell
# parser and reverts in memory if it no longer parses.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File patch_install_ps1.ps1 -RepoDir "D:\...\hermes-agent"

param(
    [Parameter(Mandatory = $true)][string]$RepoDir
)

$ErrorActionPreference = "Stop"

$target = Join-Path $RepoDir "scripts\install.ps1"
if (-not (Test-Path -LiteralPath $target)) {
    Write-Host "  .   install.ps1 not found ($target) -- patcher skipped"
    exit 0
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$original = $utf8NoBom.GetString([System.IO.File]::ReadAllBytes($target))
$text = $original
if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }

# Match the file's own newline style.
$eol = "`n"
if ($text.Contains("`r`n")) { $eol = "`r`n" }

$applied = New-Object System.Collections.ArrayList
$skipped = New-Object System.Collections.ArrayList

# === Patch 1: the UV_NO_CONFIG leak =========================================
$leakOld = '    $env:UV_MANAGED_PYTHON = "1"' + $eol + '    $env:UV_NO_CONFIG = "1"'
$leakNew = '    $env:UV_MANAGED_PYTHON = "1"' + $eol +
           '    # [portable patch] UV_NO_CONFIG is deliberately NOT exported here: it leaked' + $eol +
           '    # into the later `uv sync --extra all --locked`, hid [tool.uv] exclude-newer,' + $eol +
           '    # forced a re-resolve and made the hash-verified tier fail. Every `uv python`' + $eol +
           '    # call below already passes --no-config explicitly, so the export is redundant.' + $eol +
           '    # Re-applied by scripts/ps1/patch_install_ps1.ps1 after each repo reset.'

if ($text.Contains($leakOld)) {
    $text = $text.Replace($leakOld, $leakNew)
    [void]$applied.Add("uv-no-config-leak")
} elseif ($text.Contains("[portable patch] UV_NO_CONFIG")) {
    [void]$skipped.Add("uv-no-config-leak (already patched)")
} else {
    [void]$skipped.Add("uv-no-config-leak (PATTERN NOT FOUND -- upstream changed, review manually)")
}

# === Patch 2: unreadable exit code ==========================================
$launcherOld = '        $proc = Start-Process -FilePath $env:ComSpec -ArgumentList $cmdLine `' + $eol +
               '            -WorkingDirectory $workDir -NoNewWindow -PassThru'
$launcherNew = '        # [portable patch] Start-Process -PassThru returns a Process object whose' + $eol +
               '        # .ExitCode reads as $null on Windows PowerShell 5.1, so every npm/Playwright' + $eol +
               '        # step was reported as "failed -- exit code " with an empty value and the' + $eol +
               '        # `if ($browserNpmOk)` gate never opened. Same .NET launch pattern as' + $eol +
               '        # Resolve-AvailablePythonVersion above.' + $eol +
               '        $psi = New-Object System.Diagnostics.ProcessStartInfo' + $eol +
               '        $psi.FileName = $env:ComSpec' + $eol +
               '        $psi.Arguments = $cmdLine' + $eol +
               '        $psi.WorkingDirectory = $workDir' + $eol +
               '        $psi.UseShellExecute = $false' + $eol +
               '        $psi.CreateNoWindow = $true' + $eol +
               '        $proc = [System.Diagnostics.Process]::Start($psi)'

if ($text.Contains($launcherOld)) {
    $text = $text.Replace($launcherOld, $launcherNew)
    [void]$applied.Add("exit-code-launcher")
} elseif ($text.Contains("[portable patch] Start-Process -PassThru")) {
    [void]$skipped.Add("exit-code-launcher (already patched)")
} else {
    [void]$skipped.Add("exit-code-launcher (PATTERN NOT FOUND -- upstream changed, review manually)")
}

# === validate + write =======================================================
if ($applied.Count -eq 0) {
    Write-Host "  .   install.ps1 already patched -- nothing to do"
    foreach ($s in $skipped) { Write-Host "      $s" }
    exit 0
}

[System.IO.File]::WriteAllBytes($target, $utf8NoBom.GetBytes($text))

$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$parseErrors)
if ($parseErrors -and $parseErrors.Count -gt 0) {
    [System.IO.File]::WriteAllBytes($target, $utf8NoBom.GetBytes($original))
    Write-Host "  !   patched install.ps1 did not parse ($($parseErrors.Count) error(s)) -- reverted"
    foreach ($e in $parseErrors | Select-Object -First 3) { Write-Host "      $($e.Message)" }
    exit 1
}

foreach ($a in $applied) { Write-Host "  +   install.ps1 patched: $a" }
foreach ($s in $skipped) { Write-Host "      $s" }
exit 0

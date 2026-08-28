# -*- coding: utf-8 -*-
# Запись HF_HOME + WORKSPACE_DIR в AppEnvironmentExtra службы Headroom.
# Вызывается из InstallOrUpdate-HeadRoom.bat (от админа).
# Выход: 0 = записано и проверено, 1 = ошибка.

param(
    [string]$HeadroomDir = "C:\NEURO\Hermes\data\HeadRoom",
    [string]$HfHome = "C:\NEURO\Hermes\data\huggingface"
)

$ErrorActionPreference = "Stop"
$svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Headroom\Parameters"

try {
    $existing = @()
    $cur = Get-ItemProperty -Path $svcPath -Name AppEnvironmentExtra -ErrorAction SilentlyContinue
    if ($cur -and $cur.AppEnvironmentExtra) {
        $existing = @($cur.AppEnvironmentExtra)
    }

    # Убираем старые HF_HOME/WORKSPACE, добавляем актуальные
    $clean = @($existing | Where-Object {
        $_ -notlike "HF_HOME=*" -and $_ -notlike "HEADROOM_WORKSPACE_DIR=*"
    })
    $final = [string[]]@($clean + @(
        "HEADROOM_WORKSPACE_DIR=$HeadroomDir\workspace",
        "HF_HOME=$HfHome"
    ))

    Set-ItemProperty -Path $svcPath -Name AppEnvironmentExtra -Value $final -Type MultiString

    # Проверка обратным чтением
    $check = Get-ItemProperty -Path $svcPath -Name AppEnvironmentExtra
    $joined = [string]::Join("`n", @($check.AppEnvironmentExtra))
    if (-not $joined.Contains("HF_HOME=$HfHome")) {
        Write-Output "FAIL: HF_HOME не найден после записи"
        exit 1
    }
    Write-Output "OK: HF_HOME=$HfHome"
    exit 0
} catch {
    Write-Output "FAIL: $_"
    exit 1
}

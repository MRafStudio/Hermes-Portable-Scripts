<#
.SYNOPSIS
    Возвращает HERMES_DASHBOARD_SESSION_TOKEN из окружения службы Hermes.

.DESCRIPTION
    У старой установки в portable_start.ini поле REMOTE_TOKEN пустое, хотя
    токен уже прописан службе. Ветка Parameters\AppEnvironmentExtra читается
    без прав администратора, поэтому лаунчер может подхватить токен сам.

.PARAMETER ServiceName
    Имя службы, например "HermesGateway (D:_NEURO_Hermes)".

.OUTPUTS
    Токен в stdout и код возврата 0, либо код 1, если токен не найден.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ServiceName
)

$ErrorActionPreference = 'Stop'

$keyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName\Parameters"

try
{
    $raw = (Get-ItemProperty -Path $keyPath -Name 'AppEnvironmentExtra' -ErrorAction Stop).'AppEnvironmentExtra'
}
catch
{
    exit 1
}

if ($null -eq $raw)
{
    exit 1
}

$flat = ($raw -join "`n")
$match = [regex]::Match($flat, 'HERMES_DASHBOARD_SESSION_TOKEN=([0-9a-fA-F]{32,})')

if (-not $match.Success)
{
    exit 1
}

Write-Output $match.Groups[1].Value
exit 0

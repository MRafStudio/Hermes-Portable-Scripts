<#
.SYNOPSIS
    Управление службами инстанса Hermes Portable (dashboard + messenger gateway).

.DESCRIPTION
    Останавливает службы ЭТОГО инстанса перед обновлением, дожидается реального
    STOPPED, снимает оставшиеся процессы из venv и возвращает службы обратно
    после установки. Без остановки службы держат venv\Scripts\*.exe, из-за чего
    uv падает с os error 32, а rmdir оставляет нерабочее окружение.

.PARAMETER Action
    Stop | Start | Status.

.PARAMETER RootDir
    Корень инстанса (например, D:\NEURO\Hermes). По нему определяются службы.

.NOTES
    Требует прав администратора: при их отсутствии скрипт сам вызывает UAC.
    Код возврата: 0 — действие выполнено и проверено, 1 — не удалось.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Stop', 'Start', 'Status')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$RootDir
)

$ErrorActionPreference = 'Stop'

# --- Права администратора: без них действия с службами невозможны ------------
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and $Action -ne 'Status') {
    Write-Host "  Требуются права администратора — запрашиваю UAC..." -ForegroundColor Yellow
    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', ('"' + $PSCommandPath + '"'),
        '-Action', $Action,
        '-RootDir', ('"' + $RootDir + '"')
    )
    try {
        $child = Start-Process -FilePath 'powershell' -Verb RunAs -ArgumentList $arguments -Wait -PassThru
        exit $child.ExitCode
    }
    catch {
        Write-Host "[ОШИБКА] UAC отклонён — действие отменено." -ForegroundColor Red
        exit 1
    }
}

$stateFile = Join-Path $RootDir 'data\temp\hermes-services-state.txt'
$suffix = $RootDir.Replace('\', '_')

function Get-InstanceServices {
    <# Службы инстанса: по суффиксу имени, при неудаче — по описанию с RootDir. #>
    $found = @(Get-Service | Where-Object { $_.Name -like "*($suffix)" })
    if ($found.Count -gt 0) { return $found }

    $byDescription = @()
    foreach ($service in (Get-Service | Where-Object { $_.Name -like '*Hermes*' })) {
        $description = (& sc.exe qdescription $service.Name) -join ' '
        if ($description -like "*$RootDir*") { $byDescription += $service }
    }
    return $byDescription
}

function Stop-InstanceServices {
    $services = @(Get-InstanceServices)
    if ($services.Count -eq 0) {
        Write-Host "  .   Службы Hermes не установлены — останавливать нечего." -ForegroundColor DarkGray
        return 0
    }

    $wasRunning = @()
    foreach ($service in $services) {
        $current = (Get-Service -Name $service.Name).Status
        if ($current -ne 'Stopped') { $wasRunning += $service.Name }
    }

    # Состояние нужно, чтобы после установки поднять только то, что работало
    $wasRunning | Set-Content -Path $stateFile -Encoding UTF8

    foreach ($service in $services) {
        $current = (Get-Service -Name $service.Name).Status
        if ($current -eq 'Stopped') {
            Write-Host ("  .   {0}: уже остановлена." -f $service.Name) -ForegroundColor DarkGray
            continue
        }

        Write-Host ("  -   {0}: останавливаю ({1})..." -f $service.Name, $current) -ForegroundColor Yellow
        & sc.exe stop $service.Name | Out-Null

        $deadline = (Get-Date).AddSeconds(60)
        while ((Get-Date) -lt $deadline) {
            if ((Get-Service -Name $service.Name).Status -eq 'Stopped') { break }
            Start-Sleep -Milliseconds 500
        }
    }

    # Служба могла оставить дочерние процессы (hermes.exe/python.exe из venv):
    # они держат файлы окружения и ломают uv sync.
    $stuck = @(Get-CimInstance Win32_Process | Where-Object {
        $_.ExecutablePath -and $_.ExecutablePath -like '*hermes-agent\venv\*'
    })
    foreach ($process in $stuck) {
        Write-Host ("  -   снимаю процесс {0} (PID {1})." -f $process.Name, $process.ProcessId) -ForegroundColor Yellow
        try { Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop } catch { }
    }
    if ($stuck.Count -gt 0) { Start-Sleep -Seconds 2 }

    # Проверка результата — обновление продолжается только при реальном STOPPED
    $stillAlive = @()
    foreach ($service in $services) {
        $current = (Get-Service -Name $service.Name).Status
        if ($current -ne 'Stopped') { $stillAlive += ("{0} = {1}" -f $service.Name, $current) }
    }
    if ($stillAlive.Count -gt 0) {
        Write-Host "[ОШИБКА] Не удалось остановить службы:" -ForegroundColor Red
        foreach ($item in $stillAlive) { Write-Host ("         " + $item) -ForegroundColor Red }
        return 1
    }

    Write-Host "  +   Все службы Hermes остановлены." -ForegroundColor Green
    return 0
}

function Start-InstanceServices {
    $services = @(Get-InstanceServices)
    if ($services.Count -eq 0) {
        Write-Host "  .   Службы Hermes не установлены — запускать нечего." -ForegroundColor DarkGray
        return 0
    }

    $targets = @()
    if (Test-Path -LiteralPath $stateFile) {
        $targets = @(Get-Content -LiteralPath $stateFile -Encoding UTF8 | Where-Object { $_.Trim() -ne '' })
    }
    if ($targets.Count -eq 0) {
        Write-Host "  .   До обновления службы не работали — не запускаю." -ForegroundColor DarkGray
        return 0
    }

    $failed = @()
    foreach ($name in $targets) {
        if (-not (Get-Service -Name $name -ErrorAction SilentlyContinue)) { continue }

        $current = (Get-Service -Name $name).Status
        try {
            if ($current -eq 'Paused') { Resume-Service -Name $name -ErrorAction Stop }
            elseif ($current -ne 'Running') { Start-Service -Name $name -ErrorAction Stop }
        }
        catch {
            Write-Host ("  !   {0}: не запустилась — {1}" -f $name, $_.Exception.Message) -ForegroundColor Yellow
        }

        $deadline = (Get-Date).AddSeconds(60)
        while ((Get-Date) -lt $deadline) {
            $state = (Get-Service -Name $name).Status
            if ($state -eq 'Running') { break }
            if ($state -eq 'Paused') { try { Resume-Service -Name $name -ErrorAction SilentlyContinue } catch { } }
            Start-Sleep -Milliseconds 500
        }

        $final = (Get-Service -Name $name).Status
        if ($final -eq 'Running') {
            Write-Host ("  +   {0}: работает." -f $name) -ForegroundColor Green
        }
        else {
            $failed += ("{0} = {1}" -f $name, $final)
        }
    }

    if ($failed.Count -gt 0) {
        Write-Host "[ОШИБКА] Не удалось запустить службы (запустите Start-Hermes-Service.bat):" -ForegroundColor Red
        foreach ($item in $failed) { Write-Host ("         " + $item) -ForegroundColor Red }
        return 1
    }

    Remove-Item -LiteralPath $stateFile -ErrorAction SilentlyContinue
    return 0
}

function Show-InstanceServices {
    $services = @(Get-InstanceServices)
    if ($services.Count -eq 0) {
        Write-Host "  .   Службы Hermes не установлены." -ForegroundColor DarkGray
        return 0
    }

    $running = 0
    foreach ($service in $services) {
        $current = (Get-Service -Name $service.Name).Status
        Write-Host ("  {0} = {1}" -f $service.Name, $current)
        if ($current -ne 'Stopped') { $running++ }
    }
    if ($running -gt 0) { return 1 }
    return 0
}

switch ($Action) {
    'Stop' { exit (Stop-InstanceServices) }
    'Start' { exit (Start-InstanceServices) }
    'Status' { exit (Show-InstanceServices) }
}

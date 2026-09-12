<#
.SYNOPSIS
  Предохранитель перед запуском Hermes Desktop: снимает процессы-пустышки и
  сбрасывает отравленный маркер Chromium-песочницы.

.DESCRIPTION
  Hermes держит single-instance lock на профиль (userData). Вторая копия при
  живом инстансе молча выходит, НО успевает записать в профиль маркер
  windows-sandbox-fallback.json со state=booting. Две такие "оборванные
  загрузки" подряд приложение читает как boot-loop и залипает в режиме
  --no-sandbox (reason=boot-loop; sticky в пределах версии приложения) — окно
  в этом состоянии не появляется, и запуск из Start.bat выглядит как "ничего
  не произошло". Лечится убийством пустышки (процесс нашего профиля без окна —
  именно он держит lock) и удалением маркера.

  Скрипт вызывается из Start-Hermes-Desktop.bat и
  Start-Hermes-Desktop-Console.bat ДО старта приложения.

  Коды возврата:
    0  — можно запускать;
    10 — Hermes уже запущен (окно на экране), новый старт не нужен.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ps1\guard-hermes-desktop.ps1 -RootDir "D:\NEURO\Hermes"
#>
[CmdletBinding()]
param(
    # Корень портативной сборки (каталог, где лежит Start.bat).
    [Parameter(Mandatory = $true)][string]$RootDir,

    # Профиль (userData). По умолчанию — как его видит Electron: %USERPROFILE%\AppData\Roaming\Hermes.
    # При запуске из Start.bat USERPROFILE уже подменён на data\home, поэтому путь получается портативным.
    [string]$UserDataDir,

    # Процессы без окна моложе этого возраста считаются стартующими и не трогаются.
    [int]$MinAgeSeconds = 60
)

$ErrorActionPreference = 'Continue'
$tag = '[guard]'

# Консоль .bat работает в chcp 65001 — печатаем в UTF-8, иначе русский текст
# в окне запуска виден кракозябрами.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if ([string]::IsNullOrWhiteSpace($UserDataDir)) {
    $UserDataDir = Join-Path $env:USERPROFILE 'AppData\Roaming\Hermes'
}

$profilePath = $UserDataDir.TrimEnd('\')
$targetProfile = $profilePath.ToLowerInvariant()
$markerPath = Join-Path $profilePath 'windows-sandbox-fallback.json'

Write-Host "$tag профиль: $profilePath" -ForegroundColor DarkGray

# --- видимые top-level окна (надёжнее MainWindowHandle, который врёт для чужих сессий) ---
$winApi = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class HermesWinApi {
  private delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
  [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] private static extern int GetWindowThreadProcessId(IntPtr hWnd, out int pid);
  [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);

  public static int[] VisibleWindowPids() {
    var list = new List<int>();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (IsWindowVisible(h)) {
        int pid; GetWindowThreadProcessId(h, out pid);
        if (pid != 0) { list.Add(pid); }
      }
      return true;
    }, IntPtr.Zero);
    return list.ToArray();
  }

  public static IntPtr FirstVisibleWindowOf(int pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      int p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }

  public static void Raise(IntPtr h) {
    if (h == IntPtr.Zero) { return; }
    ShowWindow(h, 9);            // SW_RESTORE
    SetForegroundWindow(h);
  }
}
'@

$visiblePids = @()
try {
    Add-Type -TypeDefinition $winApi -Language CSharp -ErrorAction Stop
    $visiblePids = @([HermesWinApi]::VisibleWindowPids())
} catch {
    Write-Host "$tag не удалось получить список окон: $($_.Exception.Message)" -ForegroundColor DarkGray
}

# --- процессы Desktop и их профиль (Chromium отдаёт --user-data-dir детям) ---
$procs = @(Get-CimInstance Win32_Process -Filter "Name='Hermes.exe'" -ErrorAction SilentlyContinue)
# Корень = процесс Desktop, чей родитель НЕ наш же exe (его запустили лаунчер/
# проводник/служба). Дети Chromium (renderer/gpu/utility) в корни не попадают.
$procIds = @($procs | ForEach-Object { $_.ProcessId })
$roots = @($procs | Where-Object { $procIds -notcontains $_.ParentProcessId })

function Get-ProcProfile([int]$procId) {
    $level = @($procs | Where-Object { $_.ParentProcessId -eq $procId })
    for ($depth = 0; $depth -lt 2; $depth++) {
        foreach ($p in $level) {
            if ($p.CommandLine -match '--user-data-dir=(?:"([^"]+)"|([^\s"]+))') {
                $v = $Matches[1]; if (-not $v) { $v = $Matches[2] }
                return $v.TrimEnd('\').ToLowerInvariant()
            }
        }
        $level = @(foreach ($p in $level) { $procs | Where-Object { $_.ParentProcessId -eq $p.ProcessId } })
    }
    return $null
}

function Stop-Tree([int]$procId) {
    foreach ($k in @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$procId" -ErrorAction SilentlyContinue)) {
        Stop-Tree -procId $k.ProcessId
    }
    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
}

$mine = @()
foreach ($r in $roots) {
    $prof = Get-ProcProfile -procId $r.ProcessId
    if ($prof -and $prof -eq $targetProfile) {
        $mine += [pscustomobject]@{
            Pid       = [int]$r.ProcessId
            HasWindow = ($visiblePids -contains [int]$r.ProcessId)
            AgeSec    = [int]((Get-Date) - $r.CreationDate).TotalSeconds
        }
    }
}

# --- 1. Живой инстанс с окном → запуск не нужен ---
$alive = @($mine | Where-Object { $_.HasWindow })
if ($alive.Count -gt 0) {
    $p = $alive[0]
    Write-Host "$tag Hermes уже запущен (pid=$($p.Pid), окно на экране) — второй старт не нужен." -ForegroundColor Yellow
    try { [HermesWinApi]::Raise([HermesWinApi]::FirstVisibleWindowOf($p.Pid)) } catch { }
    exit 10
}

# --- 2. Пустышки: наш профиль, окна нет, возраст больше порога → снимаем ---
$fresh = @($mine | Where-Object { -not $_.HasWindow -and $_.AgeSec -le $MinAgeSeconds })
$husks = @($mine | Where-Object { -not $_.HasWindow -and $_.AgeSec -gt $MinAgeSeconds })

if ($husks.Count -eq 0) {
    if ($fresh.Count -gt 0) {
        Write-Host "$tag процесс без окна (pid=$($fresh[0].Pid)) моложе $MinAgeSeconds с — возможно, ещё стартует, не трогаю." -ForegroundColor DarkGray
    } else {
        Write-Host "$tag залипших процессов Hermes нет." -ForegroundColor DarkGray
    }
} else {
    foreach ($h in $husks) {
        Write-Host "$tag пустышка без окна (pid=$($h.Pid), возраст $($h.AgeSec) с) — снимаю: она держит single-instance lock." -ForegroundColor Yellow
        Stop-Tree -procId $h.Pid
        Start-Sleep -Milliseconds 500
    }
}

# --- 3. Маркер песочницы: любой state кроме ok означал оборванный старт ---
if ($fresh.Count -gt 0) {
    Write-Host "$tag маркер не трогаю: есть процесс в процессе старта." -ForegroundColor DarkGray
    exit 0
}

if (Test-Path -LiteralPath $markerPath) {
    $state = $null
    try { $state = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop | ConvertFrom-Json).state } catch { }
    if ($state -eq 'ok') {
        Write-Host "$tag маркер песочницы здоров (state=ok)." -ForegroundColor DarkGray
    } else {
        Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
        Write-Host "$tag сброшен маркер песочницы (state=$state) — Chromium снова пройдёт пробу с песочницей." -ForegroundColor Yellow
    }
} else {
    Write-Host "$tag маркера песочницы нет — старт будет чистой пробой." -ForegroundColor DarkGray
}

exit 0

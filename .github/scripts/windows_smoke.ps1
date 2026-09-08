param(
  [Parameter(Mandatory = $true)][string]$ExeDir,
  [int]$WaitSeconds = 15,
  [string]$OutDir = "smoke-out"
)

$ErrorActionPreference = "Continue"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$exe = Join-Path $ExeDir "pharmacy_pos.exe"
$results = [ordered]@{}
$results.exe = $exe
$results.exeExists = Test-Path $exe

# --- Visual capture helpers (best-effort; headless sessions may yield black) ---
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class NWin {
  [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hwnd, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

function Capture-Screen($path) {
  try {
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    return $true
  } catch { Write-Output "screen capture failed: $_"; return $false }
}

function Capture-Window($hwnd, $path) {
  try {
    $r = New-Object NWin+RECT
    if (-not [NWin]::GetWindowRect($hwnd, [ref]$r)) { return $false }
    $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [NWin]::PrintWindow($hwnd, $hdc, 2) | Out-Null
    $g.ReleaseHdc($hdc); $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return $true
  } catch { Write-Output "window capture failed: $_"; return $false }
}

function Stat($path) {
  if (-not (Test-Path $path)) { return "absent" }
  $f = Get-Item $path
  return "size=$($f.Length) bytes"
}

# --- Launch ---
$proc = $null
if ($results.exeExists) {
  $proc = Start-Process -FilePath $exe -WorkingDirectory $ExeDir -PassThru -WindowStyle Normal
  $results.pid = $proc.Id
} else {
  $results.error = "exe not found; nothing to launch"
  $results | ConvertTo-Json -Depth 4 | Out-File (Join-Path $OutDir "results.json")
  exit 1
}

# --- Poll for the app's main window handle ---
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt $WaitSeconds * 10; $i++) {
  Start-Sleep -Milliseconds 100
  $proc.Refresh()
  if ($proc.HasExited) { break }
  $hwnd = $proc.MainWindowHandle
  if ($hwnd -ne [IntPtr]::Zero) { break }
}
$results.windowFound = ($hwnd -ne [IntPtr]::Zero)
$results.windowRect = $null
if ($hwnd -ne [IntPtr]::Zero) {
  $r = New-Object NWin+RECT
  if ([NWin]::GetWindowRect($hwnd, [ref]$r)) {
    $results.windowRect = "L=$($r.Left) T=$($r.Top) R=$($r.Right) B=$($r.Bottom)"
  }
}

# --- Wait remaining time ---
Start-Sleep -Seconds $WaitSeconds
$proc.Refresh()
$results.aliveAfterWait = (-not $proc.HasExited)
$results.exitCode = if ($proc.HasExited) { $proc.ExitCode } else { $null }
$results.cpuSeconds = [math]::Round($proc.TotalProcessorTime.TotalSeconds, 2)
$results.workingSetMB = [math]::Round($proc.WorkingSet64 / 1MB, 1)

# --- Window title check ---
if ($hwnd -ne [IntPtr]::Zero) {
  $sb = New-Object System.Text.StringBuilder 256
  [NWin]::GetWindowText($hwnd, $sb, 256) | Out-Null
  $results.windowTitle = $sb.ToString()
}

# --- Capture screen + window ---
$results.screenShot = Capture-Screen (Join-Path $OutDir "screen.png")
$results.windowCaptured = if ($hwnd -ne [IntPtr]::Zero) { Capture-Window $hwnd (Join-Path $OutDir "window.png") } else { $false }

# --- Temporary startup checkpoint log (Phase 16 black-screen diagnostics) ---
$startupLog = Join-Path $env:TEMP "pharmacy_pos_startup.log"
$results.startupLog = $null
if (Test-Path $startupLog) {
  $results.startupLog = (Get-Content $startupLog -Raw -ErrorAction SilentlyContinue)
}

# --- Did the DB get touched? (fresh run would create the sqlite in Documents) ---
$docsDb = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "pharmacy_pos.sqlite"
$results.sqliteInDocuments = Stat $docsDb
$localData = Join-Path $env:LOCALAPPDATA "com.abmaster\pharmacy-pos\pharmacy_pos.sqlite"
$results.sqliteInLocalAppData = Stat $localData

# --- Windows error reporting minidumps / manifest state ---
$crashDumps = Join-Path $env:LOCALAPPDATA "CrashDumps"
if (Test-Path $crashDumps) {
  $results.crashDumps = @(Get-ChildItem $crashDumps -File | Select-Object -ExpandProperty Name)
} else { $results.crashDumps = @() }

# --- System event log errors mentioning the app (SxS, bad image, etc.) ---
try {
  $events = Get-WinEvent -FilterHashtable @{ LogName = "Application"; StartTime = (Get-Date).AddMinutes(-10) } -ErrorAction Stop |
    Where-Object { $_.Message -match "pharmacy_pos" -and $_.LevelDisplayName -match "Error|Warning" } |
    Select-Object -First 5 -Property TimeCreated, ProviderName, LevelDisplayName, @{n = 'Msg'; e = { $_.Message.Substring(0, [Math]::Min(300, $_.Message.Length)) } }
  $results.eventLogEntries = @($events)
} catch { $results.eventLogEntries = @() }

# --- Windows version + GPU adapter (correlates with D3D black-screen reports) ---
try {
  $os = Get-CimInstance Win32_OperatingSystem
  $results.os = "$($os.Caption) build $($os.BuildNumber)"
} catch { $results.os = "unknown" }
try {
  $results.gpu = @(Get-CimInstance Win32_VideoController |
    Select-Object -ExpandProperty Name)
} catch { $results.gpu = @("unknown") }

# --- Kill the process if still running ---
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue; $results.killed = $true } else { $results.killed = $false }

$results | ConvertTo-Json -Depth 5 | Out-File (Join-Path $OutDir "results.json") -Encoding utf8
Write-Output "SMOKE DONE"
$results | ConvertTo-Json -Depth 5 | Write-Output
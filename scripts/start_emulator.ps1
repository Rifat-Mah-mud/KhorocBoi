# Permanent KhorocBoi emulator launcher
# - Low RAM settings (from AVD config)
# - Always opens on-screen at a fixed position
# - Cold boot (no bad snapshot restore)
#
# Usage: right-click -> Run with PowerShell
# Or from terminal:  powershell -File E:\cursor\Khoroc\khoroboi\scripts\start_emulator.ps1

$ErrorActionPreference = "SilentlyContinue"
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$env:Path = "$sdk\platform-tools;$sdk\emulator;" + $env:Path
$avdName = "Pixel_10_Pro"
$avdDir = "$env:USERPROFILE\.android\avd\$avdName.avd"

# Keep window on primary monitor every launch
@"
window.x = 100
window.y = 60
window.scale = 0.35
"@ | Set-Content -Encoding ascii "$avdDir\emulator-user.ini"

# Stop previous instance if stuck
adb emu kill 2>$null
Start-Sleep -Seconds 1
Get-Process qemu-system-x86_64, emulator -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "Starting $avdName (low RAM, on-screen)..."
$args = @(
  "-avd", $avdName,
  "-no-snapshot-load",
  "-no-snapshot-save",
  "-gpu", "swiftshader_indirect",
  "-memory", "1536",
  "-cores", "2",
  "-scale", "0.35"
)
Start-Process -FilePath "$sdk\emulator\emulator.exe" -ArgumentList $args

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class EmuWin {
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
}
"@

for ($i = 0; $i -lt 45; $i++) {
  Start-Sleep -Seconds 2
  $p = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
    Select-Object -First 1
  if (-not $p) {
    Write-Host "[$i] waiting for emulator window..."
    continue
  }
  $h = $p.MainWindowHandle
  [EmuWin]::ShowWindow($h, 9) | Out-Null
  [EmuWin]::MoveWindow($h, 100, 60, 380, 780, $true) | Out-Null
  [EmuWin]::SetForegroundWindow($h) | Out-Null
  $r = New-Object EmuWin+RECT
  [EmuWin]::GetWindowRect($h, [ref]$r) | Out-Null
  Write-Host "[$i] window at $($r.L),$($r.T) size $(($r.R)-($r.L))x$(($r.B)-($r.T))"
  if ($r.T -ge 0 -and (($r.R) - ($r.L)) -gt 120) {
    Write-Host "Emulator is on-screen (top-left)."
    break
  }
}

adb wait-for-device
Start-Sleep -Seconds 2
adb devices -l
Write-Host ""
Write-Host "Then run:  cd E:\cursor\Khoroc\khoroboi ; flutter run"

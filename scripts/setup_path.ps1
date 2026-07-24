# Sets Flutter + Android SDK environment variables for the current user.
# Run once in PowerShell after installing Flutter and Android Studio:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#   .\scripts\setup_path.ps1

$ErrorActionPreference = "Stop"

$flutterBin = "C:\src\flutter\bin"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"

if (-not (Test-Path "$flutterBin\flutter.bat")) {
  Write-Host "Flutter not found at $flutterBin. Install Flutter first." -ForegroundColor Yellow
} else {
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -notlike "*$flutterBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterBin", "User")
    Write-Host "Added Flutter to User PATH"
  } else {
    Write-Host "Flutter already on User PATH"
  }
}

[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdk, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdk, "User")
Write-Host "ANDROID_HOME = $sdk"

if (Test-Path $sdk) {
  $extras = @(
    "$sdk\platform-tools",
    "$sdk\cmdline-tools\latest\bin",
    "$sdk\emulator"
  )
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  foreach ($p in $extras) {
    if ((Test-Path $p) -and ($userPath -notlike "*$p*")) {
      $userPath = "$userPath;$p"
    }
  }
  [Environment]::SetEnvironmentVariable("Path", $userPath, "User")
  Write-Host "SDK tool paths updated"
} else {
  Write-Host "SDK folder not found yet. Open Android Studio once to install the SDK, then re-run this script." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Close this terminal, open a new one, then run: flutter doctor -v"

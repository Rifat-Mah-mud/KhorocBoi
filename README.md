# KhorocBoi

Personal expense tracker with natural-language Bangla / English / Banglish input.

**Developed by Rifat Mahmud**


## Features

- Free-form daily notes → auto-parsed expenses (`bus vara 20 tk`)
- Local dictionary + regex amount extraction (offline-first)
- Optional free AI fallback (Groq) for unknown words, cached locally
- Home, daily tab, drawer history, analytics charts
- Light / dark mode, Bangla-capable fonts (Noto Sans Bengali)

## Quick start (after tooling is installed)

```powershell
cd E:\cursor\Khoroc\khoroboi
flutter pub get
flutter test
flutter run
```

## Free AI API key (Groq)

This app uses **Groq** (free Llama API). Put your key in:

`lib/config/api_config.dart`

```dart
static const String groqApiKey = 'gsk_...';
```

Get a key at: https://console.groq.com/keys

Without a key, the app still works offline using the dictionary.

## Android force update (GitHub Releases)

On **Android sideload APKs**, the app checks GitHub’s latest release after startup. If the release tag is newer than `pubspec.yaml` `version`, the UI is replaced with a mandatory update screen (download APK → system installer). Offline or API errors **fail open** — the app keeps working.

### Release signing (required for updates)

All release APKs must be signed with the **same** upload keystore. Otherwise Android reports conflicting signatures and force update fails.

1. Copy `android/key.properties.example` → `android/key.properties` and fill in passwords.
2. Keep `android/upload-keystore.jks` + `android/key.properties` backed up privately (both are gitignored).
3. Always build releases on a machine that has those files.

### Publish a release

1. Edit `lib/config/release_config.dart` — set `githubOwner` and `githubRepo` (public repo with Releases).
2. Bump `version:` in `pubspec.yaml` (both name and `+build` number).
3. `flutter build apk --release`
4. Create GitHub Release tag `vX.Y.Z` (leading `v` is stripped) and attach the `.apk`.

**One-time migration:** users who installed an older debug-signed APK must uninstall once, then install the new release-signed APK.

## Android Studio + SDK + PATH setup

### 1. Install locations (typical)

| Tool | Path |
|------|------|
| Flutter SDK | `C:\src\flutter` |
| Android Studio | `C:\Program Files\Android\Android Studio` |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| JDK 17 | `C:\Program Files\Microsoft\jdk-17*` |

### 2. Set user PATH (PowerShell as user)

```powershell
# Flutter
[Environment]::SetEnvironmentVariable(
  "Path",
  $env:Path + ";C:\src\flutter\bin",
  "User"
)

# Android SDK platform-tools + cmdline-tools
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdk, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdk, "User")

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$extras = @(
  "$sdk\platform-tools",
  "$sdk\cmdline-tools\latest\bin",
  "$sdk\emulator"
) -join ";"
[Environment]::SetEnvironmentVariable("Path", "$userPath;$extras", "User")
```

Close and reopen the terminal after changing PATH.

### 3. Install SDK packages (sdkmanager)

After Android Studio first launch finishes (or cmdline-tools are installed):

```powershell
# If sdkmanager is on PATH:
sdkmanager --list

sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "cmdline-tools;latest"

# Accept licenses
flutter doctor --android-licenses
```

Or in **Android Studio → Settings → Languages & Frameworks → Android SDK**:

- SDK Platforms: Android 14/15 (API 34/35)
- SDK Tools: Android SDK Build-Tools, Platform-Tools, Command-line Tools

### 4. Verify

```powershell
flutter doctor -v
```

Fix anything marked `[!]` or `[X]` before running on a device/emulator.

## Project layout

```
lib/
  models/       ExpenseEntry, DailyTab
  data/         (seed JSON under assets/data)
  services/     parser, dictionary, storage, AI
  providers/    Riverpod
  screens/      home, daily tab, analytics, settings
  widgets/      drawer, cards, summary bar
  theme/        Stitch "Lush Systematic" tokens
assets/data/dictionary.json
test/expense_parser_test.dart
```

## Extend the dictionary

Edit `assets/data/dictionary.json`:

```json
"peyara": { "en": "guava", "category": "food" }
```

AI translations are cached in Hive (`learned_dictionary`) so repeated unknown words stay offline.

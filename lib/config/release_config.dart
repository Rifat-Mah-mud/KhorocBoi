/// GitHub Releases — source of truth for Android force updates.
///
/// Requires `android/key.properties` + upload keystore so every release APK
/// shares the same signature (otherwise force-update install fails).
///
/// 1. Bump `version` in pubspec.yaml (name and +build).
/// 2. Build: `flutter build apk --release`
/// 3. Create a GitHub Release with tag `vX.Y.Z` and attach the APK.
abstract final class ReleaseConfig {
  static const githubOwner = 'Rifat-Mah-mud';
  static const githubRepo = 'KhorocBoi';

  static const githubLatestReleaseApi =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
}

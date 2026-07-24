/// GitHub Releases — source of truth for Android force updates.
///
/// 1. Bump `version` in pubspec.yaml (must match what users install).
/// 2. Build: `flutter build apk --release`
/// 3. Create a GitHub Release with tag `vX.Y.Z` and attach the APK.
abstract final class ReleaseConfig {
  static const githubOwner = 'Rifat-Mah-mud';
  static const githubRepo = 'KhorocBoi';

  static const githubLatestReleaseApi =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
}

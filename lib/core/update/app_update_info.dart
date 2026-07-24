/// Latest APK update available from GitHub Releases.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.apkDownloadUrl,
    required this.apkFileName,
    this.releaseNotes,
    this.fileSizeBytes,
  });

  final String latestVersion;
  final String currentVersion;
  final String apkDownloadUrl;
  final String apkFileName;
  final String? releaseNotes;
  final int? fileSizeBytes;
}

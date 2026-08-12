import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:khoroboi/config/release_config.dart';
import 'package:khoroboi/core/update/app_update_info.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Checks GitHub Releases and downloads/installs the latest APK (Android only).
class AppUpdateService {
  AppUpdateService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;

  /// Semantic compare: [latest] > [current].
  /// Supports optional build suffixes: `1.0.1+2`.
  static bool isNewerVersion(String latest, String current) {
    final latestParts = _splitVersionAndBuild(latest);
    final currentParts = _splitVersionAndBuild(current);

    final versionCmp = _compareDotParts(latestParts.version, currentParts.version);
    if (versionCmp != 0) return versionCmp > 0;

    // Same X.Y.Z — newer if build number is higher (when provided).
    if (latestParts.build != null && currentParts.build != null) {
      return latestParts.build! > currentParts.build!;
    }
    if (latestParts.build != null && currentParts.build == null) {
      return latestParts.build! > 0;
    }
    return false;
  }

  static ({List<int> version, int? build}) _splitVersionAndBuild(String raw) {
    final cleaned = raw.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    final plus = cleaned.split('+');
    final version = _parseVersion(plus.first);
    final build = plus.length > 1 ? int.tryParse(plus[1].trim()) : null;
    return (version: version, build: build);
  }

  static int _compareDotParts(List<int> latest, List<int> current) {
    final length =
        latest.length > current.length ? latest.length : current.length;
    for (var i = 0; i < length; i++) {
      final l = i < latest.length ? latest[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (l > c) return 1;
      if (l < c) return -1;
    }
    return 0;
  }

  static List<int> _parseVersion(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList(growable: false);
  }

  /// Returns update info when the GitHub latest release is newer than installed.
  /// Fail-open: `null` on error, offline, or not Android.
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      return await _checkForUpdate().timeout(const Duration(seconds: 20));
    } catch (error) {
      debugPrint('App update check failed: $error');
      return null;
    }
  }

  Future<AppUpdateInfo?> _checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    // Compare name (+ optional build from tag). Installed build used when tag has +N.
    final currentVersion = packageInfo.buildNumber.isNotEmpty
        ? '${packageInfo.version}+${packageInfo.buildNumber}'
        : packageInfo.version;

    final response = await _dio.get<dynamic>(
      ReleaseConfig.githubLatestReleaseApi,
      options: Options(
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'KhorocBoi-Android',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode != 200 || response.data is! Map) {
      debugPrint(
        'App update check skipped: HTTP ${response.statusCode}',
      );
      return null;
    }

    final json = Map<String, dynamic>.from(response.data as Map);
    final tagName = (json['tag_name'] as String? ?? '').trim();
    if (tagName.isEmpty) return null;

    final latestVersion =
        tagName.replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    if (!isNewerVersion(latestVersion, currentVersion)) {
      debugPrint(
        'App update not needed: installed=$currentVersion latest=$latestVersion',
      );
      return null;
    }

    final assets = json['assets'];
    if (assets is! List || assets.isEmpty) {
      debugPrint('GitHub release $tagName has no assets.');
      return null;
    }

    Map<String, dynamic>? apkAsset;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkAsset = Map<String, dynamic>.from(asset);
        break;
      }
    }
    apkAsset ??= assets.first is Map
        ? Map<String, dynamic>.from(assets.first as Map)
        : null;

    final downloadUrl = apkAsset?['browser_download_url'] as String?;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      return null;
    }

    final fileName = (apkAsset?['name'] as String?)?.trim();
    final size = apkAsset?['size'];

    return AppUpdateInfo(
      latestVersion: latestVersion,
      currentVersion: packageInfo.version,
      apkDownloadUrl: downloadUrl,
      apkFileName: (fileName == null || fileName.isEmpty)
          ? 'khorocboi_update.apk'
          : fileName,
      releaseNotes: (json['body'] as String?)?.trim(),
      fileSizeBytes: size is int ? size : null,
    );
  }

  Future<String> downloadApk(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, update.apkFileName);

    final response = await _dio.download(
      update.apkDownloadUrl,
      path,
      cancelToken: cancelToken,
      options: Options(
        headers: const {
          'Accept': 'application/octet-stream',
          'User-Agent': 'KhorocBoi-Android',
        },
        followRedirects: true,
        maxRedirects: 5,
        receiveTimeout: const Duration(minutes: 10),
        validateStatus: (status) => status != null && status < 500,
      ),
      onReceiveProgress: (received, total) {
        if (total <= 0) {
          onProgress?.call(0);
          return;
        }
        onProgress?.call((received / total).clamp(0.0, 1.0));
      },
    );

    final code = response.statusCode ?? 0;
    if (code != 200 && code != 206) {
      throw StateError('APK download failed (HTTP $code).');
    }

    final file = File(path);
    if (!await file.exists() || await file.length() < 1024) {
      throw StateError('Downloaded APK is missing or too small.');
    }

    return path;
  }

  Future<void> installApk(String path) async {
    final status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      final requested = await Permission.requestInstallPackages.request();
      if (!requested.isGranted) {
        throw StateError(
          'Install permission denied. Allow “Install unknown apps” for '
          'KhorocBoi, then try again.',
        );
      }
    }

    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );

    if (result.type != ResultType.done) {
      throw StateError(
        result.message.isEmpty
            ? 'Could not open the APK installer.'
            : result.message,
      );
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_brand.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import 'app_update_info.dart';
import 'app_update_service.dart';

/// Full-screen mandatory update — no back / dismiss.
class ForceUpdatePage extends StatefulWidget {
  const ForceUpdatePage({
    super.key,
    required this.update,
    required this.updateService,
  });

  final AppUpdateInfo update;
  final AppUpdateService updateService;

  @override
  State<ForceUpdatePage> createState() => _ForceUpdatePageState();
}

class _ForceUpdatePageState extends State<ForceUpdatePage> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  String? _downloadedPath;
  CancelToken? _cancelToken;

  AppUpdateInfo get _update => widget.update;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    if (_downloading) return;

    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      var path = _downloadedPath;
      if (path == null) {
        setState(() => _progress = 0);
        _cancelToken = CancelToken();
        path = await widget.updateService.downloadApk(
          _update,
          cancelToken: _cancelToken,
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value);
          },
        );
        _downloadedPath = path;
      }

      if (!mounted) return;
      setState(() => _progress = 1);

      await widget.updateService.installApk(path);
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = 1;
      });
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return;
      if (!mounted) return;
      setState(() {
        _error =
            'Download failed. Check your internet connection and try again.';
        _downloading = false;
        _downloadedPath = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('StateError: ', '');
        _downloading = false;
      });
    }
  }

  String get _progressLabel {
    final percent = (_progress * 100).clamp(0, 100).round();
    if (_progress >= 1) return 'Download complete. Opening installer…';
    return 'Downloading update… $percent%';
  }

  @override
  Widget build(BuildContext context) {
    final notes = _update.releaseNotes?.trim();

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const AppLogo(size: 120),
                          const SizedBox(height: 28),
                          Text(
                            'Update required',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'A new version (${_update.latestVersion}) is available.\n'
                            'You are on ${_update.currentVersion}. '
                            'Please update to continue using ${AppBrand.name}.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (notes != null && notes.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "What's new",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                notes,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                          if (_downloading) ...[
                            const SizedBox(height: 28),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _progress <= 0 ? null : _progress,
                                minHeight: 10,
                                backgroundColor: AppColors.surfaceContainer,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _progressLabel,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 20),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _downloading ? null : _startDownload,
                      child: _downloading && _progress < 1
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _downloading
                                  ? 'Downloading…'
                                  : (_error != null
                                      ? 'Retry download'
                                      : (_progress >= 1
                                          ? 'Install update'
                                          : 'Download update')),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const DevelopedByLabel(compact: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

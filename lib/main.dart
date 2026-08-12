import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/update/app_update_info.dart';
import 'core/update/force_update_page.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'services/ai_service.dart';
import 'services/dictionary_service.dart';
import 'services/google_backup_service.dart';
import 'services/storage_service.dart';
import 'theme/app_brand.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  final dictionary = DictionaryService();
  await dictionary.init();

  final ai = AiService();
  await ai.init();

  final backup = GoogleBackupService(storage);
  await backup.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        dictionaryServiceProvider.overrideWithValue(dictionary),
        aiServiceProvider.overrideWithValue(ai),
        googleBackupServiceProvider.overrideWithValue(backup),
      ],
      child: const KhorocboiApp(),
    ),
  );
}

class KhorocboiApp extends ConsumerStatefulWidget {
  const KhorocboiApp({super.key});

  @override
  ConsumerState<KhorocboiApp> createState() => _KhorocboiAppState();
}

class _KhorocboiAppState extends ConsumerState<KhorocboiApp> {
  AppUpdateInfo? _pendingUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForForceUpdate());
      unawaited(_autoBackupSync());
    });
  }

  Future<void> _checkForForceUpdate() async {
    try {
      final update = await ref.read(appUpdateServiceProvider).checkForUpdate();
      if (!mounted || update == null) return;
      setState(() => _pendingUpdate = update);
    } catch (error) {
      debugPrint('Force update gate failed: $error');
    }
  }

  Future<void> _autoBackupSync() async {
    try {
      await ref.read(googleBackupServiceProvider).maybeAutoSync();
      if (!mounted) return;
      ref.read(tabsVersionProvider.notifier).state++;
    } catch (error) {
      debugPrint('Auto backup sync failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      builder: (context, child) {
        final pending = _pendingUpdate;
        if (pending != null) {
          return ForceUpdatePage(
            update: pending,
            updateService: ref.read(appUpdateServiceProvider),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

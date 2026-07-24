import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'services/ai_service.dart';
import 'services/dictionary_service.dart';
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

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        dictionaryServiceProvider.overrideWithValue(dictionary),
        aiServiceProvider.overrideWithValue(ai),
      ],
      child: const KhorocboiApp(),
    ),
  );
}

class KhorocboiApp extends StatelessWidget {
  const KhorocboiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

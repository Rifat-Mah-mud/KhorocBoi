import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_tab.dart';
import '../models/dictionary_entry.dart';
import '../models/expense_entry.dart';
import '../core/update/app_update_service.dart';
import '../services/ai_service.dart';
import '../services/dictionary_service.dart';
import '../services/expense_parser_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/storage_service.dart';

final dictionaryServiceProvider = Provider<DictionaryService>((ref) {
  throw UnimplementedError('Override in main()');
});

final aiServiceProvider = Provider<AiService>((ref) {
  throw UnimplementedError('Override in main()');
});

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Override in main()');
});

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  throw UnimplementedError('Override in main()');
});

final _backupStateStreamProvider = StreamProvider<BackupState>((ref) {
  return ref.watch(cloudSyncServiceProvider).stateStream;
});

/// Latest backup/connect state for UI.
final backupStateProvider = Provider<BackupState>((ref) {
  final async = ref.watch(_backupStateStreamProvider);
  return async.asData?.value ??
      ref.watch(cloudSyncServiceProvider).state;
});

final parserServiceProvider = Provider<ExpenseParserService>((ref) {
  return ExpenseParserService(
    dictionary: ref.watch(dictionaryServiceProvider),
    aiService: ref.watch(aiServiceProvider),
  );
});

/// Tick incremented whenever tabs are mutated so UI rebuilds.
final tabsVersionProvider = StateProvider<int>((ref) => 0);

final tabsProvider = Provider<List<DailyTab>>((ref) {
  ref.watch(tabsVersionProvider);
  return ref.watch(storageServiceProvider).getAllTabs();
});

final tabByIdProvider = Provider.family<DailyTab?, String>((ref, id) {
  ref.watch(tabsVersionProvider);
  return ref.watch(storageServiceProvider).getTab(id);
});

final monthTotalProvider = Provider<double>((ref) {
  final tabs = ref.watch(tabsProvider);
  final now = DateTime.now();
  return tabs
      .where((t) => t.date.year == now.year && t.date.month == now.month)
      .fold(0.0, (sum, t) => sum + t.total);
});

class AnalyticsState {
  final DateRange range;
  final List<DailyTab> tabs;

  const AnalyticsState({required this.range, required this.tabs});

  double get total => tabs.fold(0.0, (s, t) => s + t.total);

  DailyTab? get highestDay {
    if (tabs.isEmpty) return null;
    final totals = dailyTotals;
    if (totals.isEmpty) return null;
    final bestDate =
        totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return tabs
        .where((t) => t.dateOnly == bestDate)
        .reduce((a, b) => a.total >= b.total ? a : b);
  }

  double get highestDayTotal {
    final day = highestDay;
    if (day == null) return 0;
    return dailyTotals[day.dateOnly] ?? day.total;
  }

  Map<DateTime, double> get dailyTotals {
    final map = <DateTime, double>{};
    for (final tab in tabs) {
      map[tab.dateOnly] = (map[tab.dateOnly] ?? 0) + tab.total;
    }
    return map;
  }

  Map<String, double> get categoryTotals {
    final map = <String, double>{
      'transport': 0,
      'food': 0,
      'snacks': 0,
      'other': 0,
    };
    for (final tab in tabs) {
      for (final e in tab.entries) {
        final cat = e.category ?? 'other';
        map[cat] = (map[cat] ?? 0) + e.amount;
      }
    }
    return map;
  }
}

final analyticsRangeProvider = StateProvider<DateRange>((ref) {
  return DateRange.thisMonth();
});

final analyticsProvider = Provider<AnalyticsState>((ref) {
  final range = ref.watch(analyticsRangeProvider);
  ref.watch(tabsVersionProvider);
  final tabs = ref.watch(storageServiceProvider).tabsForSelection(
        start: range.start,
        end: range.end,
        selectedDays: range.selectedDays,
      );
  return AnalyticsState(range: range, tabs: tabs);
});

class TabControllerNotifier extends StateNotifier<AsyncValue<void>> {
  TabControllerNotifier(this.ref) : super(const AsyncData(null));

  final Ref ref;

  StorageService get _storage => ref.read(storageServiceProvider);
  ExpenseParserService get _parser => ref.read(parserServiceProvider);
  CloudSyncService get _backup => ref.read(cloudSyncServiceProvider);
  int _enrichEpoch = 0;

  void _bump() {
    ref.read(tabsVersionProvider.notifier).state++;
  }

  Future<DailyTab> createToday() async {
    final tab = await _storage.createTodayTab();
    _bump();
    return tab;
  }

  Future<DailyTab> createAnotherToday() async {
    final tab = await _storage.createAdditionalTabForDate(DateTime.now());
    _bump();
    return tab;
  }

  DailyTab? latestTodayTab() => _storage.getTabByDate(DateTime.now());

  List<DailyTab> todayTabs() => _storage.tabsForDate(DateTime.now());

  bool get hasTodayTab => _storage.tabsForDate(DateTime.now()).isNotEmpty;

  Future<DailyTab> createForDate(DateTime date) async {
    final tab = await _storage.createTabForDate(date);
    _bump();
    return tab;
  }

  Future<void> deleteTab(String tabId) async {
    await _storage.deleteTab(tabId);
    _bump();
    _backup.scheduleUploadAfterEdit();
  }

  /// Save a renamed tab without re-parsing notes or calling AI.
  Future<void> saveTabTitle({
    required String tabId,
    required String customTitle,
  }) async {
    final existing = _storage.getTab(tabId);
    if (existing == null || existing.customTitle == customTitle) return;

    await _storage.updateTabNotesAndEntries(
      tabId: tabId,
      notesText: existing.notesText,
      entries: existing.entries,
      customTitle: customTitle,
    );
    _bump();
    _backup.scheduleUploadAfterEdit();
  }

  /// Fast local save, then optional AI enrichment in the background.
  Future<void> autoSaveTab({
    required String tabId,
    required String notesText,
    String? customTitle,
    bool backgroundAi = true,
  }) async {
    try {
      final existing = _storage.getTab(tabId);
      final title = customTitle ?? existing?.customTitle ?? '';
      final unchanged = existing != null &&
          existing.notesText == notesText &&
          existing.customTitle == title;
      if (unchanged) return;

      await _saveParsedTab(
        tabId: tabId,
        notesText: notesText,
        customTitle: customTitle,
      );

      if (backgroundAi) {
        _backup.scheduleUploadAfterEdit();
        unawaited(
          _enrichTabInBackground(
            tabId: tabId,
            notesText: notesText,
            customTitle: customTitle,
          ),
        );
        return;
      }

      await _enrichTabInBackground(
        tabId: tabId,
        notesText: notesText,
        customTitle: customTitle,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> _saveParsedTab({
    required String tabId,
    required String notesText,
    String? customTitle,
  }) async {
    final syncParsed = _parser.parseNotesSync(notesText);
    final entries = syncParsed
        .map(
          (p) => ExpenseEntry(
            rawText: p.originalText,
            cleanedItem: p.item,
            amount: p.amount,
            category: p.category,
            timestamp: p.timestamp,
          ),
        )
        .toList();

    await _storage.updateTabNotesAndEntries(
      tabId: tabId,
      notesText: notesText,
      entries: entries,
      customTitle: customTitle,
    );
    _bump();
  }

  Future<void> _enrichTabInBackground({
    required String tabId,
    required String notesText,
    String? customTitle,
  }) async {
    final epoch = ++_enrichEpoch;
    try {
      final enriched = await _parser.parseNotes(notesText);
      if (epoch != _enrichEpoch) return;

      final entries = enriched
          .map(
            (p) => ExpenseEntry(
              rawText: p.originalText,
              cleanedItem: p.item,
              amount: p.amount,
              category: p.category,
              timestamp: p.timestamp,
            ),
          )
          .toList();

      await _storage.updateTabNotesAndEntries(
        tabId: tabId,
        notesText: notesText,
        entries: entries,
        customTitle: customTitle,
      );
      if (epoch != _enrichEpoch) return;
      _bump();
      _backup.scheduleUploadAfterEdit();
    } catch (e, st) {
      debugPrint('Background AI enrichment failed: $e\n$st');
      if (epoch == _enrichEpoch) {
        _backup.scheduleUploadAfterEdit();
      }
    }
  }
}

final tabControllerProvider =
    StateNotifierProvider<TabControllerNotifier, AsyncValue<void>>(
  (ref) => TabControllerNotifier(ref),
);

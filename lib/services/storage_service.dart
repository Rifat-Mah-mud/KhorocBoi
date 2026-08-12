import 'package:hive_flutter/hive_flutter.dart';

import '../models/daily_tab.dart';
import '../models/expense_entry.dart';

class StorageService {
  static const tabsBoxName = 'daily_tabs';

  late Box<DailyTab> _tabsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExpenseEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DailyTabAdapter());
    }
    _tabsBox = await Hive.openBox<DailyTab>(tabsBoxName);
  }

  List<DailyTab> getAllTabs() {
    final tabs = _tabsBox.values.toList();
    tabs.sort((a, b) {
      final byDate = b.dateOnly.compareTo(a.dateOnly);
      if (byDate != 0) return byDate;
      return b.slot.compareTo(a.slot);
    });
    return tabs;
  }

  DailyTab? getTab(String id) => _tabsBox.get(id);

  String dateKey(DateTime d) => _dateKey(d);

  List<DailyTab> tabsForDate(DateTime date) {
    final key = _dateKey(date);
    final list = _tabsBox.values
        .where((tab) => _dateKey(tab.date) == key)
        .toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    return list;
  }

  int sameDayCount(DailyTab tab) => tabsForDate(tab.date).length;

  DailyTab? getTabByDate(DateTime date) {
    final tabs = tabsForDate(date);
    return tabs.isEmpty ? null : tabs.last;
  }

  Future<DailyTab> createTabForDate(DateTime date) async {
    final existing = tabsForDate(date);
    if (existing.isNotEmpty) return existing.last;

    final tab = DailyTab(
      date: DateTime(date.year, date.month, date.day),
      slot: 1,
    );
    await _tabsBox.put(tab.id, tab);
    return tab;
  }

  /// Always creates another tab for [date], numbering 1, 2, 3…
  Future<DailyTab> createAdditionalTabForDate(DateTime date) async {
    final existing = tabsForDate(date);
    if (existing.isEmpty) return createTabForDate(date);

    final first = existing.first;
    if (existing.length == 1 && first.slot != 1) {
      await _tabsBox.put(first.id, first.copyWith(slot: 1));
    }

    final nextSlot =
        existing.map((t) => t.slot).reduce((a, b) => a > b ? a : b) + 1;
    final tab = DailyTab(
      date: DateTime(date.year, date.month, date.day),
      slot: nextSlot,
    );
    await _tabsBox.put(tab.id, tab);
    return tab;
  }

  Future<DailyTab> createTodayTab() => createTabForDate(DateTime.now());

  Future<void> saveTab(DailyTab tab) async {
    await _tabsBox.put(tab.id, tab);
  }

  Future<void> updateTabNotesAndEntries({
    required String tabId,
    required String notesText,
    required List<ExpenseEntry> entries,
    String? customTitle,
  }) async {
    final existing = _tabsBox.get(tabId);
    if (existing == null) return;
    final updated = existing.copyWith(
      notesText: notesText,
      entries: entries,
      customTitle: customTitle,
    );
    await _tabsBox.put(tabId, updated);
  }

  Future<void> deleteTab(String id) async {
    await _tabsBox.delete(id);
  }

  Stream<BoxEvent> watchTabs() => _tabsBox.watch();

  List<DailyTab> tabsInRange(DateTime start, DateTime end) {
    return getAllTabs().where((tab) {
      final d = tab.dateOnly;
      return !d.isBefore(DateTime(start.year, start.month, start.day)) &&
          !d.isAfter(DateTime(end.year, end.month, end.day));
    }).toList();
  }

  List<DailyTab> tabsForSelection({
    required DateTime start,
    required DateTime end,
    Set<DateTime>? selectedDays,
  }) {
    if (selectedDays != null && selectedDays.isNotEmpty) {
      final keys = selectedDays
          .map((d) => _dateKey(DateTime(d.year, d.month, d.day)))
          .toSet();
      return getAllTabs()
          .where((tab) => keys.contains(_dateKey(tab.dateOnly)))
          .toList();
    }
    return tabsInRange(start, end);
  }

  Map<String, List<DailyTab>> tabsGroupedByMonth() {
    final grouped = <String, List<DailyTab>>{};
    for (final tab in getAllTabs()) {
      final key =
          '${tab.date.year}-${tab.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(tab);
    }
    return grouped;
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Full local snapshot for cloud backup.
  Map<String, dynamic> exportBackup() {
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tabs': getAllTabs().map((t) => t.toJson()).toList(),
    };
  }

  bool get hasAnyTabs => _tabsBox.isNotEmpty;

  /// Exact restore — clears local tabs and writes cloud snapshot as-is.
  Future<void> replaceAllFromBackup(Map<String, dynamic> backup) async {
    final rawTabs = backup['tabs'] as List<dynamic>? ?? const [];
    final cloudTabs = rawTabs
        .map((e) => DailyTab.fromJson(e as Map<String, dynamic>))
        .toList();

    await _tabsBox.clear();
    for (final tab in cloudTabs) {
      await _tabsBox.put(tab.id, tab);
    }
  }

  /// Merge cloud tabs with local by tab id (supports multiple tabs per day).
  Future<int> mergeFromBackup(Map<String, dynamic> backup) async {
    final rawTabs = backup['tabs'] as List<dynamic>? ?? const [];
    final cloudTabs = rawTabs
        .map((e) => DailyTab.fromJson(e as Map<String, dynamic>))
        .toList();

    var changed = 0;
    for (final cloud in cloudTabs) {
      final local = _tabsBox.get(cloud.id);
      if (local == null) {
        await _tabsBox.put(cloud.id, cloud);
        changed++;
        continue;
      }

      final preferCloud = _isRicher(cloud, local);
      if (!preferCloud) continue;

      final merged = local.copyWith(
        notesText: cloud.notesText,
        entries: cloud.entries,
        slot: cloud.slot,
        customTitle: cloud.customTitle,
      );
      await _tabsBox.put(local.id, merged);
      changed++;
    }
    return changed;
  }

  bool _isRicher(DailyTab a, DailyTab b) {
    if (a.notesText.length != b.notesText.length) {
      return a.notesText.length > b.notesText.length;
    }
    if (a.entries.length != b.entries.length) {
      return a.entries.length > b.entries.length;
    }
    return a.total > b.total;
  }
}

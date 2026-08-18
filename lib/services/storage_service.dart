import 'package:hive_flutter/hive_flutter.dart';

import '../models/daily_tab.dart';
import '../models/expense_entry.dart';
import '../models/recycled_tab.dart';

class StorageService {
  static const tabsBoxName = 'daily_tabs';
  static const recycledTabsBoxName = 'recycled_tabs';
  static const recycleRetention = Duration(days: 30);

  late Box<DailyTab> _tabsBox;
  late Box<RecycledTab> _recycledTabsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExpenseEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DailyTabAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(RecycledTabAdapter());
    }
    _tabsBox = await Hive.openBox<DailyTab>(tabsBoxName);
    _recycledTabsBox = await Hive.openBox<RecycledTab>(recycledTabsBoxName);
    await purgeExpiredRecycledTabs();
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
    final resolvedTitle = ensureUniqueTitle(
      requested: tab.customTitle,
      excludeTabId: tab.id,
    );
    final normalized =
        resolvedTitle == tab.customTitle ? tab : tab.copyWith(customTitle: resolvedTitle);
    await _tabsBox.put(normalized.id, normalized);
  }

  Future<void> updateTabNotesAndEntries({
    required String tabId,
    required String notesText,
    required List<ExpenseEntry> entries,
    String? customTitle,
  }) async {
    final existing = _tabsBox.get(tabId);
    if (existing == null) return;
    final requestedTitle = customTitle ?? existing.customTitle;
    final resolvedTitle = ensureUniqueTitle(
      requested: requestedTitle,
      excludeTabId: tabId,
    );
    final updated = existing.copyWith(
      notesText: notesText,
      entries: entries,
      customTitle: resolvedTitle,
    );
    await _tabsBox.put(tabId, updated);
  }

  Future<void> deleteTab(String id) async {
    final existing = _tabsBox.get(id);
    if (existing == null) return;
    final recycled = RecycledTab(
      id: existing.id,
      tab: existing,
      deletedAt: DateTime.now(),
    );
    await _recycledTabsBox.put(recycled.id, recycled);
    await _tabsBox.delete(id);
  }

  List<RecycledTab> getRecycledTabs() {
    final now = DateTime.now();
    final items = _recycledTabsBox.values.where((item) {
      final expiresAt = item.deletedAt.add(recycleRetention);
      return expiresAt.isAfter(now);
    }).toList();
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  Future<int> purgeExpiredRecycledTabs() async {
    final now = DateTime.now();
    final expiredIds = _recycledTabsBox.values
        .where((item) => !item.deletedAt.add(recycleRetention).isAfter(now))
        .map((item) => item.id)
        .toList();
    for (final id in expiredIds) {
      await _recycledTabsBox.delete(id);
    }
    return expiredIds.length;
  }

  Future<void> permanentlyDeleteRecycledTab(String id) async {
    await _recycledTabsBox.delete(id);
  }

  Future<DailyTab?> restoreRecycledTab(String id) async {
    final recycled = _recycledTabsBox.get(id);
    if (recycled == null) return null;
    final restoredTitle = _resolveRestoredTitle(recycled.tab.customTitle);
    final restored = recycled.tab.copyWith(customTitle: restoredTitle);
    await _tabsBox.put(restored.id, restored);
    await _recycledTabsBox.delete(id);
    return restored;
  }

  Stream<BoxEvent> watchTabs() => _tabsBox.watch();
  Stream<BoxEvent> watchRecycledTabs() => _recycledTabsBox.watch();

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

  String ensureUniqueTitle({
    required String requested,
    String? excludeTabId,
  }) {
    final base = requested.trim();
    if (base.isEmpty) return '';
    final existing = _tabsBox.values
        .where((t) => t.id != excludeTabId)
        .map((t) => t.customTitle.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();
    if (!existing.contains(base.toLowerCase())) return base;

    var i = 2;
    while (true) {
      final candidate = '$base ($i)';
      if (!existing.contains(candidate.toLowerCase())) return candidate;
      i++;
    }
  }

  String _resolveRestoredTitle(String original) {
    final title = original.trim();
    if (title.isEmpty) return '';
    final withSuffix = '$title (restored)';
    return ensureUniqueTitle(requested: withSuffix);
  }
}

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
    tabs.sort((a, b) => b.dateOnly.compareTo(a.dateOnly));
    return tabs;
  }

  DailyTab? getTab(String id) => _tabsBox.get(id);

  DailyTab? getTabByDate(DateTime date) {
    final key = _dateKey(date);
    for (final tab in _tabsBox.values) {
      if (_dateKey(tab.date) == key) return tab;
    }
    return null;
  }

  Future<DailyTab> createTabForDate(DateTime date) async {
    final existing = getTabByDate(date);
    if (existing != null) return existing;

    final tab = DailyTab(
      date: DateTime(date.year, date.month, date.day),
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
  }) async {
    final existing = _tabsBox.get(tabId);
    if (existing == null) return;
    final updated = existing.copyWith(
      notesText: notesText,
      entries: entries,
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
}

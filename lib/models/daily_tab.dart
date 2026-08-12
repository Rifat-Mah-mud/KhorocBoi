import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'expense_entry.dart';

class DailyTab {
  final String id;
  final DateTime date;
  final List<ExpenseEntry> entries;
  final String notesText;
  /// Same-day index: 1, 2, 3… when multiple tabs exist for one date.
  final int slot;
  /// User-editable name. Date stays separate for finding the tab.
  final String customTitle;

  DailyTab({
    String? id,
    required this.date,
    List<ExpenseEntry>? entries,
    this.notesText = '',
    this.slot = 1,
    this.customTitle = '',
  })  : id = id ?? const Uuid().v4(),
        entries = entries ?? [];

  double get total => entries.fold(0.0, (sum, e) => sum + e.amount);

  int get transactionCount => entries.length;

  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  bool get hasCustomTitle => customTitle.trim().isNotEmpty;

  String get tabLabel => 'Tab $slot';

  bool isNumbered(int sameDayCount) => sameDayCount > 1 || slot > 1;

  String headline({
    int sameDayCount = 1,
    String pattern = 'MMMM d, yyyy',
  }) {
    if (hasCustomTitle) return customTitle.trim();
    return displayTitle(sameDayCount: sameDayCount, pattern: pattern);
  }

  String dateLabel({String pattern = 'MMMM d, yyyy'}) {
    return DateFormat(pattern).format(date);
  }

  /// Date, plus `Tab 1` / `Tab 2` when there are multiple tabs that day.
  String displayTitle({
    int sameDayCount = 1,
    String pattern = 'MMMM d, yyyy',
  }) {
    final base = dateLabel(pattern: pattern);
    if (isNumbered(sameDayCount)) return '$base $tabLabel';
    return base;
  }

  DailyTab copyWith({
    String? id,
    DateTime? date,
    List<ExpenseEntry>? entries,
    String? notesText,
    int? slot,
    String? customTitle,
  }) {
    return DailyTab(
      id: id ?? this.id,
      date: date ?? this.date,
      entries: entries ?? this.entries,
      notesText: notesText ?? this.notesText,
      slot: slot ?? this.slot,
      customTitle: customTitle ?? this.customTitle,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'notesText': notesText,
        'slot': slot,
        'customTitle': customTitle,
      };

  factory DailyTab.fromJson(Map<String, dynamic> json) => DailyTab(
        id: json['id'] as String?,
        date: DateTime.parse(json['date'] as String),
        entries: (json['entries'] as List<dynamic>?)
                ?.map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        notesText: json['notesText'] as String? ?? '',
        slot: json['slot'] as int? ?? 1,
        customTitle: json['customTitle'] as String? ?? '',
      );
}

class DailyTabAdapter extends TypeAdapter<DailyTab> {
  @override
  final int typeId = 1;

  @override
  DailyTab read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyTab(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      entries: (fields[2] as List).cast<ExpenseEntry>(),
      notesText: fields[3] as String? ?? '',
      slot: fields[4] as int? ?? 1,
      customTitle: fields[5] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, DailyTab obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.entries)
      ..writeByte(3)
      ..write(obj.notesText)
      ..writeByte(4)
      ..write(obj.slot)
      ..writeByte(5)
      ..write(obj.customTitle);
  }
}

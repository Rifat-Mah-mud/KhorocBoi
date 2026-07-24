import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'expense_entry.dart';

class DailyTab {
  final String id;
  final DateTime date;
  final List<ExpenseEntry> entries;
  final String notesText;

  DailyTab({
    String? id,
    required this.date,
    List<ExpenseEntry>? entries,
    this.notesText = '',
  })  : id = id ?? const Uuid().v4(),
        entries = entries ?? [];

  double get total => entries.fold(0.0, (sum, e) => sum + e.amount);

  int get transactionCount => entries.length;

  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  DailyTab copyWith({
    String? id,
    DateTime? date,
    List<ExpenseEntry>? entries,
    String? notesText,
  }) {
    return DailyTab(
      id: id ?? this.id,
      date: date ?? this.date,
      entries: entries ?? this.entries,
      notesText: notesText ?? this.notesText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'notesText': notesText,
      };

  factory DailyTab.fromJson(Map<String, dynamic> json) => DailyTab(
        id: json['id'] as String?,
        date: DateTime.parse(json['date'] as String),
        entries: (json['entries'] as List<dynamic>?)
                ?.map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        notesText: json['notesText'] as String? ?? '',
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
    );
  }

  @override
  void write(BinaryWriter writer, DailyTab obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.entries)
      ..writeByte(3)
      ..write(obj.notesText);
  }
}

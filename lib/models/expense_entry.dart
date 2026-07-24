import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class ExpenseEntry {
  final String id;
  final String rawText;
  final String cleanedItem;
  final double amount;
  final String? category;
  final DateTime timestamp;

  ExpenseEntry({
    String? id,
    required this.rawText,
    required this.cleanedItem,
    required this.amount,
    this.category,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ExpenseEntry copyWith({
    String? id,
    String? rawText,
    String? cleanedItem,
    double? amount,
    String? category,
    DateTime? timestamp,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      rawText: rawText ?? this.rawText,
      cleanedItem: cleanedItem ?? this.cleanedItem,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawText': rawText,
        'cleanedItem': cleanedItem,
        'amount': amount,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) => ExpenseEntry(
        id: json['id'] as String?,
        rawText: json['rawText'] as String,
        cleanedItem: json['cleanedItem'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class ExpenseEntryAdapter extends TypeAdapter<ExpenseEntry> {
  @override
  final int typeId = 0;

  @override
  ExpenseEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseEntry(
      id: fields[0] as String,
      rawText: fields[1] as String,
      cleanedItem: fields[2] as String,
      amount: fields[3] as double,
      category: fields[4] as String?,
      timestamp: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.rawText)
      ..writeByte(2)
      ..write(obj.cleanedItem)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.timestamp);
  }
}

import 'package:hive/hive.dart';

import 'daily_tab.dart';

class RecycledTab {
  final String id;
  final DailyTab tab;
  final DateTime deletedAt;

  RecycledTab({
    required this.id,
    required this.tab,
    required this.deletedAt,
  });
}

class RecycledTabAdapter extends TypeAdapter<RecycledTab> {
  @override
  final int typeId = 2;

  @override
  RecycledTab read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecycledTab(
      id: fields[0] as String,
      tab: fields[1] as DailyTab,
      deletedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecycledTab obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tab)
      ..writeByte(2)
      ..write(obj.deletedAt);
  }
}

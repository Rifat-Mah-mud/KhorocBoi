class DictionaryEntry {
  final String english;
  final String category;

  const DictionaryEntry({
    required this.english,
    required this.category,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      english: json['en'] as String,
      category: json['category'] as String? ?? 'other',
    );
  }

  Map<String, dynamic> toJson() => {
        'en': english,
        'category': category,
      };
}

class ParsedExpense {
  final String item;
  final double amount;
  final String originalText;
  final DateTime timestamp;
  final String? category;
  final bool usedAiFallback;

  const ParsedExpense({
    required this.item,
    required this.amount,
    required this.originalText,
    required this.timestamp,
    this.category,
    this.usedAiFallback = false,
  });
}

enum DateRangePreset {
  thisMonth,
  last3Months,
  last6Months,
  custom,
}

class DateRange {
  final DateTime start;
  final DateTime end;
  final DateRangePreset preset;

  /// When set (custom multi-day pick), analytics uses only these dates
  /// instead of every day between [start] and [end].
  final Set<DateTime>? selectedDays;

  const DateRange({
    required this.start,
    required this.end,
    required this.preset,
    this.selectedDays,
  });

  factory DateRange.thisMonth() {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      preset: DateRangePreset.thisMonth,
    );
  }

  factory DateRange.lastMonths(int months) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    return DateRange(
      start: start,
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      preset: months == 3
          ? DateRangePreset.last3Months
          : DateRangePreset.last6Months,
    );
  }

  factory DateRange.customDays(Set<DateTime> days) {
    final normalized = days
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();
    if (normalized.isEmpty) {
      final now = DateTime.now();
      return DateRange(
        start: now,
        end: now,
        preset: DateRangePreset.custom,
        selectedDays: {},
      );
    }
    return DateRange(
      start: normalized.first,
      end: DateTime(
        normalized.last.year,
        normalized.last.month,
        normalized.last.day,
        23,
        59,
        59,
      ),
      preset: DateRangePreset.custom,
      selectedDays: normalized.toSet(),
    );
  }

  factory DateRange.customRange(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final from = s.isBefore(e) ? s : e;
    final to = s.isBefore(e) ? e : s;
    return DateRange(
      start: from,
      end: DateTime(to.year, to.month, to.day, 23, 59, 59),
      preset: DateRangePreset.custom,
    );
  }

  bool get hasSpecificDays =>
      selectedDays != null && selectedDays!.isNotEmpty;
}


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dictionary_entry.dart';
import '../theme/app_theme.dart';

enum _PickMode { range, individual }

/// Bottom sheet calendar: pick a start–end range OR individual days.
Future<DateRange?> showCustomAnalyticsPicker(
  BuildContext context, {
  DateRange? initial,
}) {
  return showModalBottomSheet<DateRange>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CustomAnalyticsPicker(initial: initial),
  );
}

class _CustomAnalyticsPicker extends StatefulWidget {
  const _CustomAnalyticsPicker({this.initial});

  final DateRange? initial;

  @override
  State<_CustomAnalyticsPicker> createState() => _CustomAnalyticsPickerState();
}

class _CustomAnalyticsPickerState extends State<_CustomAnalyticsPicker> {
  late _PickMode _mode;
  late DateTime _visibleMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  late Set<DateTime> _pickedDays;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final hasDays =
        initial?.selectedDays != null && initial!.selectedDays!.isNotEmpty;
    _mode = hasDays ? _PickMode.individual : _PickMode.range;
    _pickedDays = {
      if (hasDays) ...initial!.selectedDays!,
    };
    if (initial != null && initial.preset == DateRangePreset.custom && !hasDays) {
      _rangeStart = DateTime(
        initial.start.year,
        initial.start.month,
        initial.start.day,
      );
      _rangeEnd = DateTime(
        initial.end.year,
        initial.end.month,
        initial.end.day,
      );
    }
    final anchor = _pickedDays.isNotEmpty
        ? _pickedDays.first
        : (_rangeStart ?? DateTime.now());
    _visibleMonth = DateTime(anchor.year, anchor.month);
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _onDayTap(DateTime day) {
    final d = _dayOnly(day);
    setState(() {
      if (_mode == _PickMode.individual) {
        if (_pickedDays.any((x) => _sameDay(x, d))) {
          _pickedDays.removeWhere((x) => _sameDay(x, d));
        } else {
          _pickedDays.add(d);
        }
      } else {
        if (_rangeStart == null || (_rangeStart != null && _rangeEnd != null)) {
          _rangeStart = d;
          _rangeEnd = null;
        } else {
          _rangeEnd = d;
        }
      }
    });
  }

  bool _isSelected(DateTime day) {
    final d = _dayOnly(day);
    if (_mode == _PickMode.individual) {
      return _pickedDays.any((x) => _sameDay(x, d));
    }
    if (_rangeStart != null && _rangeEnd == null) {
      return _sameDay(_rangeStart!, d);
    }
    if (_rangeStart != null && _rangeEnd != null) {
      final a = _rangeStart!.isBefore(_rangeEnd!) ? _rangeStart! : _rangeEnd!;
      final b = _rangeStart!.isBefore(_rangeEnd!) ? _rangeEnd! : _rangeStart!;
      return !d.isBefore(a) && !d.isAfter(b);
    }
    return false;
  }

  bool _isRangeEdge(DateTime day) {
    if (_mode != _PickMode.range) return false;
    final d = _dayOnly(day);
    if (_rangeStart != null && _sameDay(_rangeStart!, d)) return true;
    if (_rangeEnd != null && _sameDay(_rangeEnd!, d)) return true;
    return false;
  }

  String get _summary {
    final fmt = DateFormat('d MMM');
    if (_mode == _PickMode.individual) {
      if (_pickedDays.isEmpty) return 'Tap days to select';
      final sorted = _pickedDays.toList()..sort();
      if (sorted.length <= 3) {
        return sorted.map(fmt.format).join(', ');
      }
      return '${sorted.length} days selected';
    }
    if (_rangeStart == null) return 'Tap start date';
    if (_rangeEnd == null) return 'Start: ${fmt.format(_rangeStart!)} · tap end date';
    final a = _rangeStart!.isBefore(_rangeEnd!) ? _rangeStart! : _rangeEnd!;
    final b = _rangeStart!.isBefore(_rangeEnd!) ? _rangeEnd! : _rangeStart!;
    return '${fmt.format(a)} → ${fmt.format(b)}';
  }

  bool get _canApply {
    if (_mode == _PickMode.individual) return _pickedDays.isNotEmpty;
    return _rangeStart != null && _rangeEnd != null;
  }

  void _apply() {
    if (!_canApply) return;
    if (_mode == _PickMode.individual) {
      Navigator.pop(context, DateRange.customDays(_pickedDays));
    } else {
      Navigator.pop(
        context,
        DateRange.customRange(_rangeStart!, _rangeEnd!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_visibleMonth);
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Monday-based: weekday 1=Mon ... 7=Sun
    final leadingEmpty = (firstOfMonth.weekday - 1) % 7;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Custom dates',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<_PickMode>(
            segments: const [
              ButtonSegment(
                value: _PickMode.range,
                label: Text('Range'),
                icon: Icon(Icons.date_range, size: 18),
              ),
              ButtonSegment(
                value: _PickMode.individual,
                label: Text('Pick days'),
                icon: Icon(Icons.event_available, size: 18),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() {
                _mode = s.first;
                if (_mode == _PickMode.range) {
                  _pickedDays.clear();
                } else {
                  _rangeStart = null;
                  _rangeEnd = null;
                }
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            _mode == _PickMode.range
                ? 'Tap a start day, then an end day'
                : 'Tap any days (e.g. 5 May, 12 May, 15 May)',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (d) => Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmpty + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmpty) {
                return const SizedBox.shrink();
              }
              final dayNum = index - leadingEmpty + 1;
              final date =
                  DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
              final selected = _isSelected(date);
              final edge = _isRangeEdge(date);
              final today = _sameDay(date, DateTime.now());

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _onDayTap(date),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? (edge || _mode == _PickMode.individual
                            ? AppColors.primaryContainer
                            : AppColors.primaryContainer.withValues(alpha: 0.35))
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    border: today && !selected
                        ? Border.all(color: AppColors.primary)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected
                              ? AppColors.onPrimaryContainer
                              : null,
                        ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canApply ? _apply : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

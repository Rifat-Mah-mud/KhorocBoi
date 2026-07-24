import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/dictionary_entry.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_analytics_picker.dart';
import '../widgets/spending_summary_bar.dart';
import 'daily_tab_screen.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider);
    final range = ref.watch(analyticsRangeProvider);
    final money = NumberFormat('#,##0', 'en_US');
    final highest = analytics.highestDay;
    final daily = analytics.dailyTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxY = daily.isEmpty
        ? 100.0
        : daily.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        titleTextStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Date range',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresetChip(
                label: 'This Month',
                selected: range.preset == DateRangePreset.thisMonth,
                onTap: () {
                  ref.read(analyticsRangeProvider.notifier).state =
                      DateRange.thisMonth();
                },
              ),
              _PresetChip(
                label: 'Last 3 Months',
                selected: range.preset == DateRangePreset.last3Months,
                onTap: () {
                  ref.read(analyticsRangeProvider.notifier).state =
                      DateRange.lastMonths(3);
                },
              ),
              _PresetChip(
                label: 'Last 6 Months',
                selected: range.preset == DateRangePreset.last6Months,
                onTap: () {
                  ref.read(analyticsRangeProvider.notifier).state =
                      DateRange.lastMonths(6);
                },
              ),
              _PresetChip(
                label: 'Custom',
                selected: range.preset == DateRangePreset.custom,
                onTap: () async {
                  final picked = await showCustomAnalyticsPicker(
                    context,
                    initial: range.preset == DateRangePreset.custom
                        ? range
                        : null,
                  );
                  if (picked != null) {
                    ref.read(analyticsRangeProvider.notifier).state = picked;
                  }
                },
              ),
            ],
          ),
          if (range.preset == DateRangePreset.custom) ...[
            const SizedBox(height: 8),
            Text(
              range.hasSpecificDays
                  ? '${range.selectedDays!.length} selected day${range.selectedDays!.length == 1 ? '' : 's'}'
                  : '${DateFormat('d MMM yyyy').format(range.start)} → ${DateFormat('d MMM yyyy').format(range.end)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: () async {
                final picked = await showCustomAnalyticsPicker(
                  context,
                  initial: range,
                );
                if (picked != null) {
                  ref.read(analyticsRangeProvider.notifier).state = picked;
                }
              },
              child: const Text('Change custom dates'),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: const Border(
                top: BorderSide(color: AppColors.primary, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL SPENDING',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '৳ ${money.format(analytics.total)}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Daily spending trend',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: daily.isEmpty
                ? Center(
                    child: Text(
                      'No data in this range',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY == 0 ? 100 : maxY,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (v, _) => Text(
                              v >= 1000
                                  ? '${(v / 1000).toStringAsFixed(0)}k'
                                  : v.toInt().toString(),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= daily.length) {
                                return const SizedBox.shrink();
                              }
                              // Show sparse labels.
                              if (daily.length > 10 && i % 3 != 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat('d/M').format(daily[i].key),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < daily.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: daily[i].value,
                                width: daily.length > 20 ? 4 : 10,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                                color: AppColors.primaryContainer,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          if (highest != null)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('MMMM d, yyyy')
                                    .format(highest.date),
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              SpendingSummaryBar(
                                total: highest.total,
                                entries: highest.entries,
                                expanded: true,
                                onToggle: () {},
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DailyTabScreen(tabId: highest.id),
                                    ),
                                  );
                                },
                                child: const Text('Open full day tab'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.trending_up,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Highest Spending Day',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              DateFormat('EEEE, MMM d').format(highest.date),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '৳ ${money.format(highest.total)}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Category breakdown',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          ...analytics.categoryTotals.entries.map((e) {
            final total = analytics.total;
            final pct = total == 0 ? 0.0 : e.value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(categoryIcon(e.key), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key[0].toUpperCase() + e.key.substring(1),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Text(
                        '৳ ${money.format(e.value)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceContainer,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? AppColors.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

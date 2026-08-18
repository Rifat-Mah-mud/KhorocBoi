import 'package:flutter/material.dart';

import '../models/expense_entry.dart';
import '../theme/app_theme.dart';

IconData categoryIcon(String? category) {
  switch (category) {
    case 'transport':
      return Icons.directions_bus;
    case 'food':
      return Icons.restaurant;
    case 'snacks':
      return Icons.local_cafe;
    default:
      return Icons.payments_outlined;
  }
}

class SpendingSummaryBar extends StatelessWidget {
  const SpendingSummaryBar({
    super.key,
    required this.total,
    required this.entries,
    required this.expanded,
    required this.onToggle,
    this.label,
  });

  final double total;
  final List<ExpenseEntry> entries;
  final bool expanded;
  final VoidCallback onToggle;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.surfaceLowest,
      elevation: 8,
      shadowColor: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Padding(
        // Lift above system nav / gesture bar on phones with buttons.
        padding: EdgeInsets.only(bottom: bottomInset + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label ?? 'Total',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Text(
                      '৳ ${total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2)}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          'No parsed expenses yet. Try: bus vara 20 tk',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.outlineVariant
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.secondaryContainer,
                                  child: Icon(
                                    categoryIcon(e.category),
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.cleanedItem,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      Text(
                                        e.category?.toUpperCase() ?? 'OTHER',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium,
                                      ),
                                      Text(
                                        e.rawText,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '৳ ${e.amount.toStringAsFixed(e.amount.truncateToDouble() == e.amount ? 0 : 2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}


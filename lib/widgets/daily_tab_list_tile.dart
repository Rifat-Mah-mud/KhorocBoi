import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_tab.dart';
import '../theme/app_theme.dart';

class DailyTabListTile extends StatelessWidget {
  const DailyTabListTile({
    super.key,
    required this.tab,
    required this.onTap,
    this.sameDayCount = 1,
    this.onDelete,
  });

  final DailyTab tab;
  final VoidCallback onTap;
  final int sameDayCount;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final moneyFmt = NumberFormat('#,##0', 'en_US');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateTitle = tab.displayTitle(sameDayCount: sameDayCount);

    return Material(
      color: isDark ? AppColors.darkSurfaceLowest : AppColors.surfaceLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F3D3E).withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer.withValues(alpha: 0.5),
                ),
                child: const Icon(Icons.today, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.headline(sameDayCount: sameDayCount),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (tab.hasCustomTitle) ...[
                      const SizedBox(height: 2),
                      Text(
                        dateTitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${tab.transactionCount} transaction${tab.transactionCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Text(
                '৳ ${moneyFmt.format(tab.total)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.error.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

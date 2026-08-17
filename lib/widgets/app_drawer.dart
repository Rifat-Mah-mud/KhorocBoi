import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_tab.dart';
import '../providers/app_providers.dart';
import '../providers/theme_provider.dart';
import '../screens/analytics_screen.dart';
import '../screens/backup_screen.dart';
import '../screens/daily_tab_screen.dart';
import '../theme/app_brand.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(tabsProvider);
    final grouped = <String, List<DailyTab>>{};
    final monthFmt = DateFormat('MMMM yyyy');

    for (final tab in tabs) {
      final label = monthFmt.format(tab.date);
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matchDate = DateFormat('yyyy-MM-dd')
                .format(tab.date)
                .contains(q) ||
            DateFormat('d MMM yyyy').format(tab.date).toLowerCase().contains(q) ||
            DateFormat('MMMM').format(tab.date).toLowerCase().contains(q);
        if (!matchDate) continue;
      }
      grouped.putIfAbsent(label, () => []).add(tab);
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  const AppLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppBrand.workspaceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.lushGreen,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                  const _ThemeModeToggle(),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Material(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AnalyticsScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insights,
                          color: AppColors.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Analytics & Insights',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Cloud Sync'),
                subtitle: Text(
                  ref.watch(backupStateProvider).isConnected
                      ? 'Connected · sync history'
                      : 'Set email to sync history',
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by date…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.white
                      : AppColors.darkSurfaceLowest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.lushBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.lushBorder),
                  ),
                ),
              ),
            ),
            Expanded(
              child: grouped.isEmpty
                  ? Center(
                      child: Text(
                        'No tabs yet',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final month in grouped.keys) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Text(
                              month,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.lushGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          for (final tab in grouped[month]!)
                            Builder(
                              builder: (context) {
                                final count = grouped[month]!
                                    .where((t) =>
                                        t.date.year == tab.date.year &&
                                        t.date.month == tab.date.month &&
                                        t.date.day == tab.date.day)
                                    .length;
                                final dateText = tab.displayTitle(
                                  sameDayCount: count,
                                  pattern: 'd MMM',
                                );
                                return ListTile(
                              leading: const Icon(
                                Icons.calendar_today_outlined,
                                size: 20,
                              ),
                              title: Text(
                                tab.headline(
                                  sameDayCount: count,
                                  pattern: 'd MMM',
                                ),
                              ),
                              subtitle: Text(
                                tab.hasCustomTitle
                                    ? '$dateText · ${tab.transactionCount} items · ৳ ${NumberFormat('#,##0').format(tab.total)}'
                                    : '${tab.transactionCount} items · ৳ ${NumberFormat('#,##0').format(tab.total)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                              ),
                              trailing: IconButton(
                                tooltip: 'Delete',
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error.withValues(alpha: 0.85),
                                ),
                                onPressed: () async {
                                  final label = tab.headline(
                                    sameDayCount: count,
                                    pattern: 'd MMM yyyy',
                                  );
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete history?'),
                                      content: Text(
                                        'Delete all notes and expenses for $label?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('No'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.error,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Yes'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  await ref
                                      .read(tabControllerProvider.notifier)
                                      .deleteTab(tab.id);
                                },
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DailyTabScreen(tabId: tab.id),
                                  ),
                                );
                              },
                            );
                              },
                            ),
                        ],
                      ],
                    ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: DevelopedByLabel(compact: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeToggle extends ConsumerWidget {
  const _ThemeModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceLowest : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.lushBorder.withValues(alpha: isDark ? 0.4 : 1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeIconButton(
            icon: Icons.light_mode_outlined,
            tooltip: 'Light mode',
            selected: !isDark,
            selectedColor: AppColors.lushGreen,
            onPressed: () => ref
                .read(themeModeProvider.notifier)
                .setMode(ThemeMode.light),
          ),
          _ThemeIconButton(
            icon: Icons.dark_mode_outlined,
            tooltip: 'Dark mode',
            selected: isDark,
            selectedColor: scheme.primary,
            onPressed: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeIconButton extends StatelessWidget {
  const _ThemeIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.selectedColor,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? selectedColor.withValues(alpha: 0.16) : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: selected
                  ? selectedColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

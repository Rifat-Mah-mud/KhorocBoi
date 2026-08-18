import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'daily_tab_screen.dart';

class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recycled = ref.watch(recycledTabsProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Recycle Bin')),
      body: recycled.isEmpty
          ? Center(
              child: Text(
                'No deleted tabs',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: recycled.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = recycled[index];
                final tab = item.tab;
                final daysLeft =
                    item.deletedAt.add(const Duration(days: 30)).difference(now).inDays + 1;
                final title = tab.hasCustomTitle
                    ? tab.customTitle.trim()
                    : tab.displayTitle(pattern: 'd MMM yyyy');
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text(title),
                    subtitle: Text(
                      'Deleted ${DateFormat('d MMM yyyy').format(item.deletedAt)} · $daysLeft day(s) left',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'restore') {
                          final restored = await ref
                              .read(tabControllerProvider.notifier)
                              .restoreTab(item.id);
                          if (context.mounted && restored != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DailyTabScreen(tabId: restored.id),
                              ),
                            );
                          }
                          return;
                        }
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete permanently?'),
                            content: const Text(
                              'This will remove the tab forever from recycle bin.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref
                              .read(tabControllerProvider.notifier)
                              .permanentlyDeleteTab(item.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'restore',
                          child: Text('Restore'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete permanently'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

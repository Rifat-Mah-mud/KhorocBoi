import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_tab.dart';
import '../providers/app_providers.dart';
import '../theme/app_brand.dart';
import '../theme/app_theme.dart';
import '../widgets/analytics_pinned_card.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_logo.dart';
import '../widgets/daily_tab_list_tile.dart';
import 'analytics_screen.dart';
import 'daily_tab_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _fabMenuOpen = false;
  bool _pickingExisting = false;

  void _closeFabMenu() {
    setState(() {
      _fabMenuOpen = false;
      _pickingExisting = false;
    });
  }

  Future<void> _openTab(DailyTab tab) async {
    _closeFabMenu();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DailyTabScreen(tabId: tab.id)),
    );
  }

  Future<void> _createFirstToday() async {
    final tab = await ref.read(tabControllerProvider.notifier).createToday();
    if (!mounted) return;
    await _openTab(tab);
  }

  Future<void> _onFabPressed() async {
    final hasToday = ref.read(tabControllerProvider.notifier).hasTodayTab;
    if (!hasToday) {
      await _createFirstToday();
      return;
    }
    setState(() {
      if (_fabMenuOpen) {
        _fabMenuOpen = false;
        _pickingExisting = false;
      } else {
        _fabMenuOpen = true;
        _pickingExisting = false;
      }
    });
  }

  Future<void> _createNewToday() async {
    final tab =
        await ref.read(tabControllerProvider.notifier).createAnotherToday();
    if (!mounted) return;
    await _openTab(tab);
  }

  void _onExistingPressed() {
    final today = ref.read(tabControllerProvider.notifier).todayTabs();
    if (today.length <= 1) {
      if (today.isEmpty) {
        _createFirstToday();
        return;
      }
      _openTab(today.first);
      return;
    }
    setState(() => _pickingExisting = true);
  }

  Future<void> _confirmDelete(DailyTab tab, int sameDayCount) async {
    final label = tab.headline(sameDayCount: sameDayCount);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to recycle bin?'),
        content: Text(
          'Move all notes and expenses for $label to recycle bin for 30 days?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(tabControllerProvider.notifier).deleteTab(tab.id);
  }

  int _sameDayCount(List<DailyTab> tabs, DailyTab tab) {
    final key =
        '${tab.date.year}-${tab.date.month}-${tab.date.day}';
    return tabs
        .where((t) => '${t.date.year}-${t.date.month}-${t.date.day}' == key)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(tabsProvider);
    final monthTotal = ref.watch(monthTotalProvider);
    final now = DateTime.now();
    final todayTabs = tabs
        .where((t) =>
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day)
        .toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));

    ref.listen(backupStateProvider, (prev, next) {
      if (prev?.dataRevision != next.dataRevision) {
        ref.read(tabsVersionProvider.notifier).state++;
      }
    });

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: 10),
            Text(
              AppBrand.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).appBarTheme.foregroundColor ??
                        AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_fabMenuOpen && !_pickingExisting) ...[
            _FabMiniOption(
              label: 'New',
              icon: Icons.note_add_outlined,
              onTap: _createNewToday,
            ),
            const SizedBox(height: 8),
            _FabMiniOption(
              label: 'Existing',
              icon: Icons.history,
              onTap: _onExistingPressed,
            ),
            const SizedBox(height: 10),
          ],
          if (_fabMenuOpen && _pickingExisting) ...[
            for (final tab in todayTabs) ...[
              _FabMiniOption(
                label: tab.hasCustomTitle
                    ? tab.customTitle.trim()
                    : tab.tabLabel,
                icon: Icons.folder_open_outlined,
                onTap: () => _openTab(tab),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 2),
          ],
          FloatingActionButton(
            onPressed: _onFabPressed,
            child: Icon(_fabMenuOpen ? Icons.close : Icons.add, size: 28),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: _fabMenuOpen ? _closeFabMenu : null,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: AnalyticsPinnedCard(
                    monthTotal: monthTotal,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (tabs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppLogo(size: 96),
                        const SizedBox(height: 24),
                        Text(
                          'Ready to track your first expense?',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start building your financial workspace by adding your daily spending.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _createFirstToday,
                          icon: const Icon(Icons.add),
                          label: const Text('Create New Tab'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Recent History',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: tabs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final count = _sameDayCount(tabs, tab);
                      return DailyTabListTile(
                        tab: tab,
                        sameDayCount: count,
                        onTap: () => _openTab(tab),
                        onDelete: () => _confirmDelete(tab, count),
                      );
                    },
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

class _FabMiniOption extends StatelessWidget {
  const _FabMiniOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryContainer,
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

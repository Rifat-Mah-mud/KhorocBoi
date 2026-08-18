import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/spending_summary_bar.dart';

class DailyTabScreen extends ConsumerStatefulWidget {
  const DailyTabScreen({super.key, required this.tabId});

  final String tabId;

  @override
  ConsumerState<DailyTabScreen> createState() => _DailyTabScreenState();
}

class _DailyTabScreenState extends ConsumerState<DailyTabScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _controller;
  late final TextEditingController _titleController;
  Timer? _debounce;
  Timer? _titleDebounce;
  bool _expanded = false;
  bool _showSaved = false;
  bool _hydrated = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController();
    _titleController = TextEditingController();
    _controller.addListener(_onNotesChanged);
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _titleDebounce?.cancel();
    _controller.removeListener(_onNotesChanged);
    _titleController.removeListener(_onTitleChanged);
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` also fires when the keyboard hides or a route pops — saving
    // there rebuilds the tree mid-transition and looks like a freeze.
    if (state == AppLifecycleState.paused) {
      unawaited(_saveNow());
    }
  }

  void _hydrateIfNeeded(String notes, String customTitle) {
    if (_hydrated) return;
    _hydrated = true;
    _controller.text = notes;
    _controller.selection = TextSelection.collapsed(offset: notes.length);
    _titleController.text = customTitle;
  }

  void _onNotesChanged() {
    if (_leaving) return;
    _scheduleSave(faster: _controller.text.endsWith('\n'));
  }

  void _onTitleChanged() {
    if (_leaving) return;
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 400), _saveTitleNow);
  }

  void _scheduleSave({bool faster = false}) {
    _debounce?.cancel();
    _debounce = Timer(
      Duration(milliseconds: faster ? 200 : 700),
      _saveNow,
    );
  }

  Future<void> _saveTitleNow() async {
    if (_leaving) return;
    _titleDebounce?.cancel();
    await ref.read(tabControllerProvider.notifier).saveTabTitle(
          tabId: widget.tabId,
          customTitle: _titleController.text,
        );
    _flashSavedIndicator();
  }

  Future<void> _saveNow() async {
    if (_leaving) return;
    _debounce?.cancel();
    await ref.read(tabControllerProvider.notifier).autoSaveTab(
          tabId: widget.tabId,
          notesText: _controller.text,
          customTitle: _titleController.text,
        );
    _flashSavedIndicator();
  }

  void _flashSavedIndicator() {
    if (!mounted || _leaving) return;
    setState(() => _showSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_leaving) setState(() => _showSaved = false);
    });
  }

  void _handleBack() {
    if (_leaving) return;
    _leaving = true;
    _debounce?.cancel();
    _titleDebounce?.cancel();

    final notes = _controller.text;
    final title = _titleController.text;
    final controller = ref.read(tabControllerProvider.notifier);

    Navigator.of(context).pop();
    unawaited(
      controller.autoSaveTab(
        tabId: widget.tabId,
        notesText: notes,
        customTitle: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(tabByIdProvider(widget.tabId));
    if (tab == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tab')),
        body: const Center(child: Text('Tab not found')),
      );
    }

    _hydrateIfNeeded(tab.notesText, tab.customTitle);

    final sameDayCount = ref.watch(tabsProvider).where((t) {
      return t.date.year == tab.date.year &&
          t.date.month == tab.date.month &&
          t.date.day == tab.date.day;
    }).length;
    final dateLabel = tab.displayTitle(
      sameDayCount: sameDayCount,
      pattern: 'MMM d, yyyy',
    );

    final now = DateTime.now();
    final isToday = tab.date.year == now.year &&
        tab.date.month == now.month &&
        tab.date.day == now.day;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: dateLabel,
                  hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _titleController,
                builder: (context, value, _) {
                  if (value.text.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  );
                },
              ),
            ],
          ),
          actions: [
            AnimatedOpacity(
              opacity: _showSaved ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    Text(
                      'Saved',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        "Try 'bus vara 20 tk' or 'banana 20 tk apple 30 tk'…",
                    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                  ),
                ),
              ),
            ),
            SpendingSummaryBar(
              total: tab.total,
              entries: tab.entries,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
              label: isToday ? "Today's Total" : 'Total',
            ),
          ],
        ),
      ),
    );
  }
}

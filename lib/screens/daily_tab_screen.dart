import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _expanded = false;
  bool _showSaved = false;
  bool _hydrated = false;

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
    _controller.removeListener(_onNotesChanged);
    _titleController.removeListener(_onTitleChanged);
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveNow();
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
    _scheduleSave(faster: _controller.text.endsWith('\n'));
  }

  void _onTitleChanged() {
    setState(() {});
    _scheduleSave();
  }

  void _scheduleSave({bool faster = false}) {
    _debounce?.cancel();
    _debounce = Timer(
      Duration(milliseconds: faster ? 200 : 700),
      _saveNow,
    );
  }

  Future<void> _saveNow() async {
    _debounce?.cancel();
    await ref.read(tabControllerProvider.notifier).autoSaveTab(
          tabId: widget.tabId,
          notesText: _controller.text,
          customTitle: _titleController.text,
        );
    if (!mounted) return;
    setState(() => _showSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSaved = false);
    });
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
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final bengali = GoogleFonts.notoSansBengali();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: hasTitle ? 72 : kToolbarHeight,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _saveNow();
            if (context.mounted) Navigator.of(context).pop();
          },
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
                    fontFamilyFallback: [bengali.fontFamily!],
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
            if (hasTitle)
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamilyFallback: [bengali.fontFamily!],
                    ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText:
                      "Try 'bus vara 20 tk' or 'banana 20 tk apple 30 tk'…",
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                        fontFamilyFallback: [bengali.fontFamily!],
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
          ),
        ],
      ),
    );
  }
}

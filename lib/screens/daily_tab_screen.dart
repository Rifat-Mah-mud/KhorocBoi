import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
  Timer? _debounce;
  bool _expanded = false;
  bool _showSaved = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveNow();
    }
  }

  void _hydrateIfNeeded(String notes) {
    if (_hydrated) return;
    _hydrated = true;
    _controller.text = notes;
    _controller.selection = TextSelection.collapsed(offset: notes.length);
  }

  void _onTextChanged() {
    final text = _controller.text;
    // Immediate local reparse for reactive total (via notifier save sync path).
    _debounce?.cancel();

    // Faster save on newline.
    final delay = text.endsWith('\n')
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 700);

    _debounce = Timer(delay, _saveNow);
  }

  Future<void> _saveNow() async {
    _debounce?.cancel();
    await ref.read(tabControllerProvider.notifier).autoSaveTab(
          tabId: widget.tabId,
          notesText: _controller.text,
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

    _hydrateIfNeeded(tab.notesText);

    final title = DateFormat('MMM d, yyyy').format(tab.date);
    final bengali = GoogleFonts.notoSansBengali();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _saveNow();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        title: Text(title),
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

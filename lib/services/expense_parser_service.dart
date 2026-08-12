import 'ai_service.dart';
import 'dictionary_service.dart';
import '../models/dictionary_entry.dart';

/// Hybrid expense line parser:
/// 1) regex amount extraction (always local)
/// 2) dictionary lookup for item name
/// 3) AI fallback for unknown terms, then cache
///
/// A single line may contain multiple expenses, e.g.
/// `banana 20 tk apple 30 tk` → two entries (20 + 30).
class ExpenseParserService {
  ExpenseParserService({
    required DictionaryService dictionary,
    required AiService aiService,
  })  : _dictionary = dictionary,
        _aiService = aiService;

  final DictionaryService _dictionary;
  final AiService _aiService;

  /// Matches amounts like: 20, 20tk, 20 tk, 20taka, 50/-, 1500, 1,200.50, ৳50
  static final RegExp amountPattern = RegExp(
    r'(?:৳\s*)?(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:tk|taka|৳|\/\-)?',
    caseSensitive: false,
  );

  /// Currency / filler tokens stripped from item text.
  static final Set<String> _noiseTokens = {
    'tk',
    'taka',
    '৳',
    '/-',
    'tk.',
    'taka.',
  };

  /// Split one free-form line into segments, one per amount.
  ///
  /// Example: `banana 20 tk apple 30 tk`
  /// → `['banana 20 tk', 'apple 30 tk']`
  static List<String> splitExpenseSegments(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return const [];

    final matches = amountPattern.allMatches(trimmed).toList();
    if (matches.isEmpty) return const [];

    final segments = <String>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final start = i == 0 ? 0 : matches[i - 1].end;
      final segment = trimmed.substring(start, match.end).trim();
      if (segment.isEmpty) continue;
      // Skip orphan amounts with no item text (e.g. trailing " 40").
      final phrase = extractItemPhrase(segment);
      if (phrase.isEmpty && i > 0) continue;
      segments.add(segment);
    }
    return segments;
  }

  /// Extract numeric amount from a free-form line. Returns null if none found.
  /// Prefer the last numeric match within a single segment
  /// (common: "bus vara 20 tk").
  static double? extractAmount(String line) {
    final matches = amountPattern.allMatches(line);
    if (matches.isEmpty) return null;

    for (final match in matches.toList().reversed) {
      final raw = match.group(1);
      if (raw == null) continue;
      final value = double.tryParse(raw.replaceAll(',', ''));
      if (value != null) return value;
    }
    return null;
  }

  /// Remove amount + currency tokens; return remaining item phrase tokens.
  static String extractItemPhrase(String line) {
    var text = line.trim();
    if (text.isEmpty) return '';

    // Remove amount+currency spans.
    text = text.replaceAll(amountPattern, ' ');
    final tokens = text
        .split(RegExp(r'\s+'))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty && !_noiseTokens.contains(t))
        .where((t) => !RegExp(r'^[\d.,]+$').hasMatch(t))
        .toList();

    return tokens.join(' ').trim();
  }

  ParsedExpense? _parseSingleSegmentSync(
    String segment, {
    DateTime? timestamp,
  }) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) return null;

    final amount = extractAmount(trimmed);
    if (amount == null) return null;

    final phrase = extractItemPhrase(trimmed);
    final tokens = phrase.isEmpty ? <String>[] : phrase.split(' ');

    final resolved = _resolveTokens(tokens);
    final cleaned =
        resolved.english.isEmpty ? 'Expense' : _titleCase(resolved.english);
    final category = resolved.category ?? _dictionary.inferCategory(cleaned);

    return ParsedExpense(
      item: cleaned,
      amount: amount,
      originalText: trimmed,
      timestamp: timestamp ?? DateTime.now(),
      category: category,
      usedAiFallback: false,
    );
  }

  /// Sync parse of one line (may yield multiple expenses). Dictionary only.
  List<ParsedExpense> parseLineSync(String line, {DateTime? timestamp}) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return const [];

    final segments = splitExpenseSegments(trimmed);
    if (segments.isEmpty) return const [];

    final results = <ParsedExpense>[];
    for (final segment in segments) {
      final parsed = _parseSingleSegmentSync(segment, timestamp: timestamp);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  /// Translate tokens greedily (longest phrase first), join English parts.
  ({String english, String? category, bool fullyKnown}) _resolveTokens(
    List<String> tokens,
  ) {
    if (tokens.isEmpty) {
      return (english: '', category: null, fullyKnown: true);
    }

    // Prefer full-phrase hit first.
    final full = _dictionary.lookup(tokens.join(' '));
    if (full != null) {
      return (
        english: full.english,
        category: full.category,
        fullyKnown: true,
      );
    }

    final parts = <String>[];
    String? category;
    var fullyKnown = true;
    var i = 0;
    while (i < tokens.length) {
      var matched = false;
      for (var len = tokens.length - i; len >= 1; len--) {
        final slice = tokens.sublist(i, i + len).join(' ');
        final hit = _dictionary.lookup(slice);
        if (hit != null) {
          parts.add(hit.english);
          category ??= hit.category;
          i += len;
          matched = true;
          break;
        }
      }
      if (!matched) {
        parts.add(tokens[i]);
        fullyKnown = false;
        i += 1;
      }
    }

    return (
      english: parts.join(' '),
      category: category,
      fullyKnown: fullyKnown,
    );
  }

  Future<ParsedExpense> _enrichWithAi(ParsedExpense sync) async {
    final phrase = extractItemPhrase(sync.originalText);
    if (phrase.isEmpty) return sync;

    final tokens = phrase.split(' ');
    final resolved = _resolveTokens(tokens);
    if (resolved.fullyKnown) return sync;

    final parts = <String>[];
    String? category = resolved.category;
    var usedAi = false;
    var i = 0;
    while (i < tokens.length) {
      var matched = false;
      for (var len = tokens.length - i; len >= 1; len--) {
        final slice = tokens.sublist(i, i + len).join(' ');
        final hit = _dictionary.lookup(slice);
        if (hit != null) {
          parts.add(hit.english);
          category ??= hit.category;
          i += len;
          matched = true;
          break;
        }
      }
      if (!matched) {
        final unknown = tokens[i];
        final ai = await _aiService.translateTerm(unknown);
        if (ai != null && ai.isNotEmpty) {
          final cat = _dictionary.inferCategory(ai);
          await _dictionary.cacheTranslation(unknown, ai, category: cat);
          parts.add(ai);
          category ??= cat;
          usedAi = true;
        } else {
          parts.add(unknown);
        }
        i += 1;
      }
    }

    final cleaned = _titleCase(parts.join(' '));
    return ParsedExpense(
      item: cleaned,
      amount: sync.amount,
      originalText: sync.originalText,
      timestamp: sync.timestamp,
      category: category ?? _dictionary.inferCategory(cleaned),
      usedAiFallback: usedAi,
    );
  }

  /// Async parse of one line (may yield multiple expenses) with AI fallback.
  Future<List<ParsedExpense>> parseLine(
    String line, {
    DateTime? timestamp,
  }) async {
    final syncList = parseLineSync(line, timestamp: timestamp);
    if (syncList.isEmpty) return const [];

    final results = <ParsedExpense>[];
    for (final sync in syncList) {
      results.add(await _enrichWithAi(sync));
    }
    return results;
  }

  /// Parse multi-line notes; supports multiple expenses per line.
  Future<List<ParsedExpense>> parseNotes(String notes) async {
    final lines = notes.split('\n');
    final results = <ParsedExpense>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      results.addAll(await parseLine(line));
    }
    return results;
  }

  /// Sync multi-line parse (dictionary only) — used for instant UI updates.
  List<ParsedExpense> parseNotesSync(String notes) {
    final lines = notes.split('\n');
    final results = <ParsedExpense>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      results.addAll(parseLineSync(line));
    }
    return results;
  }

  static String _titleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
        .join(' ');
  }
}

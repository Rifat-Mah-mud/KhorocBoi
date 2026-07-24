import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/dictionary_entry.dart';

/// Local Bangla/Banglish → English dictionary with progressive AI learning cache.
class DictionaryService {
  static const _cacheBoxName = 'learned_dictionary';

  final Map<String, DictionaryEntry> _words = {};
  Box<String>? _cacheBox;
  bool _initialized = false;
  bool _persistCache = true;

  /// When true, [seedForTest] skips asset + Hive loading.
  DictionaryService({bool persistCache = true}) : _persistCache = persistCache;

  bool get isInitialized => _initialized;

  /// Test helper: inject seed words without Flutter assets / Hive.
  void seedForTest(Map<String, DictionaryEntry> words) {
    _words
      ..clear()
      ..addAll({
        for (final e in words.entries) e.key.toLowerCase().trim(): e.value,
      });
    _initialized = true;
    _persistCache = false;
  }

  Future<void> init() async {
    if (_initialized) return;

    final raw = await rootBundle.loadString('assets/data/dictionary.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final words = json['words'] as Map<String, dynamic>;

    for (final entry in words.entries) {
      _words[entry.key.toLowerCase().trim()] =
          DictionaryEntry.fromJson(entry.value as Map<String, dynamic>);
    }

    if (_persistCache) {
      _cacheBox = await Hive.openBox<String>(_cacheBoxName);
      for (final key in _cacheBox!.keys) {
        final cached = _cacheBox!.get(key);
        if (cached == null) continue;
        try {
          final map = jsonDecode(cached) as Map<String, dynamic>;
          _words[key.toString().toLowerCase()] = DictionaryEntry.fromJson(map);
        } catch (_) {
          // Skip corrupt cache rows.
        }
      }
    }

    _initialized = true;
  }

  DictionaryEntry? lookup(String term) {
    final key = term.toLowerCase().trim();
    if (key.isEmpty) return null;
    return _words[key];
  }

  /// Longest-phrase-first match against remaining item tokens.
  DictionaryEntry? lookupPhrase(List<String> tokens) {
    if (tokens.isEmpty) return null;

    for (var len = tokens.length; len >= 1; len--) {
      for (var start = 0; start <= tokens.length - len; start++) {
        final phrase = tokens.sublist(start, start + len).join(' ');
        final hit = lookup(phrase);
        if (hit != null) return hit;
      }
    }
    return null;
  }

  Future<void> cacheTranslation(
    String term,
    String english, {
    String category = 'other',
  }) async {
    final key = term.toLowerCase().trim();
    if (key.isEmpty || english.trim().isEmpty) return;

    final entry = DictionaryEntry(
      english: english.trim(),
      category: category,
    );
    _words[key] = entry;

    if (!_persistCache) return;

    final box = _cacheBox ?? await Hive.openBox<String>(_cacheBoxName);
    _cacheBox = box;
    await box.put(key, jsonEncode(entry.toJson()));
  }

  /// Infer category from cleaned English item using secondary mapping.
  String inferCategory(String cleanedItem) {
    final lower = cleanedItem.toLowerCase();
    final entry = lookup(lower);
    if (entry != null) return entry.category;

    const transport = [
      'bus',
      'cng',
      'rickshaw',
      'uber',
      'pathao',
      'train',
      'metro',
      'taxi',
      'fare',
      'auto',
    ];
    const food = [
      'rice',
      'egg',
      'chicken',
      'fish',
      'lunch',
      'dinner',
      'breakfast',
      'meal',
      'grocery',
      'vegetable',
      'guava',
      'biryani',
      'milk',
    ];
    const snacks = [
      'tea',
      'coffee',
      'fritter',
      'samosa',
      'fuchka',
      'biscuit',
      'chips',
      'water',
      'snack',
      'chocolate',
    ];

    if (transport.any(lower.contains)) return 'transport';
    if (food.any(lower.contains)) return 'food';
    if (snacks.any(lower.contains)) return 'snacks';
    return 'other';
  }

  Map<String, DictionaryEntry> get allWords => Map.unmodifiable(_words);
}

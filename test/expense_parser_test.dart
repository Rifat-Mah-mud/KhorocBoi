import 'package:flutter_test/flutter_test.dart';
import 'package:khoroboi/models/dictionary_entry.dart';
import 'package:khoroboi/services/ai_service.dart';
import 'package:khoroboi/services/dictionary_service.dart';
import 'package:khoroboi/services/expense_parser_service.dart';

ExpenseParserService buildParser() {
  final dictionary = DictionaryService(persistCache: false);
  dictionary.seedForTest({
    'vara': const DictionaryEntry(english: 'fare', category: 'transport'),
    'bhara': const DictionaryEntry(english: 'fare', category: 'transport'),
    'bus': const DictionaryEntry(english: 'bus', category: 'transport'),
    'cng': const DictionaryEntry(english: 'CNG', category: 'transport'),
    'piyara': const DictionaryEntry(english: 'guava', category: 'food'),
    'piyaju':
        const DictionaryEntry(english: 'lentil fritters', category: 'snacks'),
    'cha': const DictionaryEntry(english: 'tea', category: 'snacks'),
    'cini': const DictionaryEntry(english: 'sugar', category: 'food'),
    'chal': const DictionaryEntry(english: 'rice', category: 'food'),
    'dim': const DictionaryEntry(english: 'egg', category: 'food'),
  });
  return ExpenseParserService(
    dictionary: dictionary,
    aiService: AiService(),
  );
}

void main() {
  group('amount extraction', () {
    test('extracts plain number', () {
      expect(ExpenseParserService.extractAmount('bus 20'), 20);
    });

    test('extracts number with tk / taka suffix', () {
      expect(ExpenseParserService.extractAmount('bus vara 20 tk'), 20);
      expect(ExpenseParserService.extractAmount('piyaju 50tk'), 50);
      expect(ExpenseParserService.extractAmount('lunch 150 taka'), 150);
    });

    test('extracts 50/- style', () {
      expect(ExpenseParserService.extractAmount('cng 50/-'), 50);
    });

    test('extracts comma thousands', () {
      expect(ExpenseParserService.extractAmount('rent 12,500'), 12500);
    });

    test('extracts four or more digits without commas', () {
      expect(ExpenseParserService.extractAmount('lunch 1500'), 1500);
      expect(ExpenseParserService.extractAmount('rent 1000 tk'), 1000);
      expect(ExpenseParserService.extractAmount('item 12345'), 12345);
      expect(ExpenseParserService.extractAmount('bill 12500.50'), 12500.50);
      expect(ExpenseParserService.extractAmount('phone 250000'), 250000);
      expect(ExpenseParserService.extractAmount('laptop 1250000 tk'), 1250000);
    });

    test('returns null when no amount', () {
      expect(ExpenseParserService.extractAmount('just text'), isNull);
    });
  });

  group('item phrase extraction', () {
    test('strips amount and currency', () {
      expect(
        ExpenseParserService.extractItemPhrase('bus vara 20 tk'),
        'bus vara',
      );
      expect(ExpenseParserService.extractItemPhrase('piyara 50'), 'piyara');
      expect(
        ExpenseParserService.extractItemPhrase('cng vara 50'),
        'cng vara',
      );
    });
  });

  group('dictionary lookup parse', () {
    test('maps bus vara → Bus Fare', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('bus vara 20 tk');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 20);
      expect(parsed.originalText, 'bus vara 20 tk');
      expect(parsed.item.toLowerCase(), 'bus fare');
      expect(parsed.category, 'transport');
    });

    test('maps piyara → Guava', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('piyara 50');
      expect(parsed!.item.toLowerCase(), 'guava');
      expect(parsed.amount, 50);
      expect(parsed.category, 'food');
    });

    test('maps piyaju → Lentil Fritters', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('piyaju 50 tk');
      expect(parsed!.item.toLowerCase(), 'lentil fritters');
      expect(parsed.category, 'snacks');
    });

    test('maps cng vara → CNG Fare', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('cng vara 50');
      expect(parsed!.amount, 50);
      expect(parsed.item.toLowerCase(), 'cng fare');
      expect(parsed.category, 'transport');
    });

    test('unknown word keeps title-cased phrase without blocking', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('xyzabc 40 tk');
      expect(parsed!.amount, 40);
      expect(parsed.item.toLowerCase(), 'xyzabc');
      expect(parsed.originalText, 'xyzabc 40 tk');
    });
  });

  group('multi-line notes', () {
    test('parses each line independently and skips invalid', () {
      final parser = buildParser();
      const notes = 'bus vara 20 tk\npiyara 50\n\ninvalid line\ncng 50/-';
      final results = parser.parseNotesSync(notes);
      expect(results.length, 3);
      expect(results.map((e) => e.amount).toList(), [20, 50, 50]);
    });
  });
}

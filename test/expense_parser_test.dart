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
    'banana': const DictionaryEntry(english: 'banana', category: 'food'),
    'apple': const DictionaryEntry(english: 'apple', category: 'food'),
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

    test('skips single-digit quantities without currency', () {
      expect(ExpenseParserService.extractAmount('2 peice apple'), isNull);
      expect(ExpenseParserService.extractAmount('lighter 5'), isNull);
      expect(ExpenseParserService.extractAmount('5 peice'), isNull);
    });

    test('keeps single-digit amount when marked as money', () {
      expect(ExpenseParserService.extractAmount('lighter 5 tk'), 5);
      expect(ExpenseParserService.extractAmount('tea 5taka'), 5);
      expect(ExpenseParserService.extractAmount('item 5/-'), 5);
      expect(ExpenseParserService.extractAmount('৳5 snack'), 5);
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

  group('same-line multiple expenses', () {
    test('splits banana 20 tk apple 30 tk into two segments', () {
      expect(
        ExpenseParserService.splitExpenseSegments('banana 20 tk apple 30 tk'),
        ['banana 20 tk', 'apple 30 tk'],
      );
    });

    test('parses both amounts and items on one line', () {
      final parser = buildParser();
      final parsed =
          parser.parseLineSync('banana 20 tk apple 30 tk');
      expect(parsed.length, 2);
      expect(parsed.map((e) => e.amount).toList(), [20, 30]);
      expect(parsed[0].item.toLowerCase(), 'banana');
      expect(parsed[1].item.toLowerCase(), 'apple');
      expect(parsed.fold<double>(0, (s, e) => s + e.amount), 50);
    });

    test('parses mixed single-line multi without currency on second', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('cha 10 tk dim 40');
      expect(parsed.length, 2);
      expect(parsed.map((e) => e.amount).toList(), [10, 40]);
    });

    test('single expense line still returns one entry', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('bus vara 20 tk');
      expect(parsed.length, 1);
      expect(parsed.first.amount, 20);
    });

    test('skips quantity digits: 2 peice apple 30 tk and 5 peice 10 tk', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync(
        '2 peice apple 30 tk and 5 peice 10 tk',
      );
      expect(parsed.length, 2);
      expect(parsed.map((e) => e.amount).toList(), [30, 10]);
      expect(parsed.fold<double>(0, (s, e) => s + e.amount), 40);
    });
  });

  group('dictionary lookup parse', () {
    test('maps bus vara → Bus Fare', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('bus vara 20 tk');
      expect(parsed, isNotEmpty);
      expect(parsed.first.amount, 20);
      expect(parsed.first.originalText, 'bus vara 20 tk');
      expect(parsed.first.item.toLowerCase(), 'bus fare');
      expect(parsed.first.category, 'transport');
    });

    test('maps piyara → Guava', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('piyara 50');
      expect(parsed.first.item.toLowerCase(), 'guava');
      expect(parsed.first.amount, 50);
      expect(parsed.first.category, 'food');
    });

    test('maps piyaju → Lentil Fritters', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('piyaju 50 tk');
      expect(parsed.first.item.toLowerCase(), 'lentil fritters');
      expect(parsed.first.amount, 50);
      expect(parsed.first.category, 'snacks');
    });

    test('maps cng vara → CNG Fare', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('cng vara 50');
      expect(parsed.first.amount, 50);
      expect(parsed.first.item.toLowerCase(), 'cng fare');
      expect(parsed.first.category, 'transport');
    });

    test('unknown word keeps title-cased phrase without blocking', () {
      final parser = buildParser();
      final parsed = parser.parseLineSync('xyzabc 40 tk');
      expect(parsed.first.amount, 40);
      expect(parsed.first.item.toLowerCase(), 'xyzabc');
      expect(parsed.first.originalText, 'xyzabc 40 tk');
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

    test('parses multi-item line plus other lines', () {
      final parser = buildParser();
      const notes = 'banana 20 tk apple 30 tk\ncng 50';
      final results = parser.parseNotesSync(notes);
      expect(results.length, 3);
      expect(results.map((e) => e.amount).toList(), [20, 30, 50]);
      expect(results.fold<double>(0, (s, e) => s + e.amount), 100);
    });
  });
}

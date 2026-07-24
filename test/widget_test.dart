import 'package:flutter_test/flutter_test.dart';
import 'package:khoroboi/services/expense_parser_service.dart';

void main() {
  test('smoke: amount extractor is available', () {
    expect(ExpenseParserService.extractAmount('tea 10 tk'), 10);
  });
}

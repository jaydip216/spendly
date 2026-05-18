import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/models/expense.dart';

void main() {
  group('Expense model', () {
    test('can be created with notes set to a string', () {
      final expense = Expense()..notes = 'Morning coffee';
      expect(expense.notes, equals('Morning coffee'));
    });

    test('notes defaults to null', () {
      final expense = Expense();
      expect(expense.notes, isNull);
    });

    test('ExpenseSource.manual exists', () {
      expect(ExpenseSource.values, contains(ExpenseSource.manual));
    });

    test('ExpenseSource.sms still exists', () {
      expect(ExpenseSource.values, contains(ExpenseSource.sms));
    });
  });
}

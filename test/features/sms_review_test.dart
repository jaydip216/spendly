import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/providers/providers.dart';
import 'package:spendly/core/repositories/expense_repository.dart';
import 'package:spendly/features/settings/sms_review_screen.dart';

class _Repository implements ExpenseRepository {
  List<Expense> removed = [];
  @override
  Future<int> removeReviewedSms(List<Expense> entries) async {
    removed = entries;
    return entries.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'review excludes valid/manual entries and requires confirmation',
    (tester) async {
      final bad = Expense()
        ..id = 1
        ..merchant = 'Incorrect OTP'
        ..rawSms = 'OTP for Rs.500 purchase';
      final good = Expense()
        ..id = 2
        ..merchant = 'Valid spend'
        ..rawSms = 'Rs.500 spent at SHOP';
      final manual = Expense()
        ..id = 3
        ..merchant = 'Manual spend'
        ..source = ExpenseSource.manual
        ..rawSms = 'OTP';
      final repository = _Repository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allExpensesProvider.overrideWith(
              (ref) => Stream.value([bad, good, manual]),
            ),
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: SmsReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Incorrect OTP'), findsOneWidget);
      expect(find.text('Valid spend'), findsNothing);
      expect(find.text('Manual spend'), findsNothing);
      expect(repository.removed, isEmpty);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove 1 selected entries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.removed, isEmpty);
      await tester.tap(find.text('Remove 1 selected entries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove entries'));
      await tester.pumpAndSettle();
      expect(repository.removed.map((entry) => entry.id), [1]);
    },
  );
}

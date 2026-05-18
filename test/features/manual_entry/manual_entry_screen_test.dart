import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/providers/providers.dart';
import 'package:spendly/core/repositories/expense_repository.dart';
import 'package:spendly/features/manual_entry/manual_entry_screen.dart';

// ignore: subtype_of_sealed_class
class FakeExpenseRepository implements ExpenseRepository {
  final List<Expense> savedExpenses = [];

  @override
  Future<void> saveExpense(Expense expense) async {
    savedExpenses.add(expense);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not implemented');
}

Widget _buildTestWidget(FakeExpenseRepository fakeRepo) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(fakeRepo),
    ],
    child: const MaterialApp(
      home: ManualEntryScreen(),
    ),
  );
}

void main() {
  group('ManualEntryScreen', () {
    testWidgets('shows validation error when merchant is empty', (tester) async {
      final fakeRepo = FakeExpenseRepository();
      await tester.pumpWidget(_buildTestWidget(fakeRepo));

      // Fill amount but leave merchant empty
      await tester.enterText(find.byKey(const Key('amount_field')), '100');
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pump();

      expect(find.text('Merchant is required'), findsOneWidget);
    });

    testWidgets('shows validation error when amount is 0', (tester) async {
      final fakeRepo = FakeExpenseRepository();
      await tester.pumpWidget(_buildTestWidget(fakeRepo));

      await tester.enterText(find.byKey(const Key('amount_field')), '0');
      await tester.enterText(find.byKey(const Key('merchant_field')), 'Swiggy');
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pump();

      expect(find.text('Enter a valid amount greater than 0'), findsOneWidget);
    });

    testWidgets('shows validation error when amount is empty', (tester) async {
      final fakeRepo = FakeExpenseRepository();
      await tester.pumpWidget(_buildTestWidget(fakeRepo));

      await tester.enterText(find.byKey(const Key('merchant_field')), 'Swiggy');
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pump();

      expect(find.text('Amount is required'), findsOneWidget);
    });

    testWidgets('calls saveExpense on valid submission', (tester) async {
      final fakeRepo = FakeExpenseRepository();
      await tester.pumpWidget(_buildTestWidget(fakeRepo));

      await tester.enterText(find.byKey(const Key('amount_field')), '250.50');
      await tester.enterText(
          find.byKey(const Key('merchant_field')), 'Amazon');
      await tester.tap(find.byKey(const Key('submit_button')));
      await tester.pump();

      expect(fakeRepo.savedExpenses, hasLength(1));
      expect(fakeRepo.savedExpenses.first.amount, 250.50);
      expect(fakeRepo.savedExpenses.first.merchant, 'Amazon');
      expect(fakeRepo.savedExpenses.first.source, ExpenseSource.manual);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/providers/providers.dart';
import 'package:spendly/features/analytics/analytics_screen.dart';

void main() {
  group('Analytics Helper Functions', () {
    test('groupByMerchant with 7 merchants returns 6 entries (5 + Others)', () {
      final expenses = List.generate(7, (i) {
        return Expense()
          ..merchant = 'Merchant $i'
          ..amount = 100.0 * (i + 1)
          ..transactionType = TransactionType.debit;
      });

      final result = groupByMerchant(expenses);

      expect(result.length, 6);
      expect(result.containsKey('Others'), isTrue);
      // The lowest 2 amounts are Merchant 0 (100) and Merchant 1 (200)
      expect(result['Others'], 300.0);
    });

    test('groupByMerchant with 2 merchants returns 2 entries (no Others)', () {
      final expenses = [
        Expense()..merchant = 'M1'..amount = 100.0..transactionType = TransactionType.debit,
        Expense()..merchant = 'M2'..amount = 200.0..transactionType = TransactionType.debit,
      ];

      final result = groupByMerchant(expenses);

      expect(result.length, 2);
      expect(result.containsKey('Others'), isFalse);
    });

    test('groupByMonth returns 12 entries for 12 months', () {
      final expenses = [
        Expense()..amount = 100.0..timestamp = DateTime.now()..transactionType = TransactionType.debit,
      ];

      final result = groupByMonth(expenses);

      expect(result.length, 12);
    });

    test('empty list returns empty map for merchant and 12 zeros for month', () {
      final expenses = <Expense>[];

      final merchantResult = groupByMerchant(expenses);
      expect(merchantResult.isEmpty, isTrue);

      final monthResult = groupByMonth(expenses);
      expect(monthResult.length, 12);
      expect(monthResult.values.every((v) => v == 0.0), isTrue);
    });
  });

  group('AnalyticsScreen Widget', () {
    testWidgets('Empty expenses shows "No data to display"', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          allExpensesProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AnalyticsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No data to display'), findsOneWidget);
    });
  });
}

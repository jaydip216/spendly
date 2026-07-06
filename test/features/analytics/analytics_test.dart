import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/providers/providers.dart';
import 'package:spendly/features/analytics/analytics_screen.dart';

Expense _debit({
  String merchant = 'M',
  String category = 'Other',
  double amount = 100,
  DateTime? timestamp,
}) {
  return Expense()
    ..merchant = merchant
    ..category = category
    ..amount = amount
    ..transactionType = TransactionType.debit
    ..timestamp = timestamp ?? DateTime.now();
}

void main() {
  group('groupByCategory', () {
    test('sums debits per category, descending', () {
      final result = groupByCategory([
        _debit(category: 'Food', amount: 100),
        _debit(category: 'Food', amount: 50),
        _debit(category: 'Transport', amount: 400),
        Expense()
          ..category = 'Food'
          ..amount = 999
          ..transactionType = TransactionType.credit,
      ]);

      expect(result.keys.toList(), ['Transport', 'Food']);
      expect(result['Food'], 150);
      expect(result['Transport'], 400);
    });

    test('treats empty category as Other', () {
      final result = groupByCategory([_debit(category: '', amount: 10)]);
      expect(result, {'Other': 10.0});
    });
  });

  group('groupByDay', () {
    test('zero-fills all days of the month and sums per day', () {
      final month = DateTime(2026, 2); // 28 days
      final result = groupByDay([
        _debit(amount: 10, timestamp: DateTime(2026, 2, 1, 9)),
        _debit(amount: 20, timestamp: DateTime(2026, 2, 1, 21)),
        _debit(amount: 5, timestamp: DateTime(2026, 2, 28)),
        _debit(amount: 999, timestamp: DateTime(2026, 3, 1)), // other month
      ], month);

      expect(result.length, 28);
      expect(result[1], 30);
      expect(result[28], 5);
      expect(result[15], 0);
    });
  });

  group('topMerchants', () {
    test('returns top merchants by debit total, descending', () {
      final result = topMerchants([
        _debit(merchant: 'A', amount: 100),
        _debit(merchant: 'B', amount: 300),
        _debit(merchant: 'A', amount: 250),
        _debit(merchant: 'C', amount: 50),
      ], limit: 2);

      expect(result.length, 2);
      expect(result[0].key, 'A');
      expect(result[0].value, 350);
      expect(result[1].key, 'B');
    });

    test('empty input yields empty list', () {
      expect(topMerchants([]), isEmpty);
    });
  });

  group('groupByMonth', () {
    test('returns 12 entries for 12 months', () {
      final result = groupByMonth([_debit()]);
      expect(result.length, 12);
    });

    test('empty list returns 12 zeros', () {
      final result = groupByMonth([]);
      expect(result.length, 12);
      expect(result.values.every((v) => v == 0.0), isTrue);
    });
  });

  group('AnalyticsScreen Widget', () {
    testWidgets('Empty month shows empty state', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          allExpensesProvider.overrideWith((ref) => Stream.value([])),
          monthlyExpensesProvider.overrideWith((ref) => Stream.value([])),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AnalyticsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No spending recorded this month.'), findsOneWidget);
    });

    testWidgets('shows category breakdown for month expenses',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final expenses = [
        _debit(
          merchant: 'Swiggy',
          category: 'Food',
          amount: 500,
          timestamp: DateTime(now.year, now.month, 2),
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          allExpensesProvider.overrideWith((ref) => Stream.value(expenses)),
          monthlyExpensesProvider.overrideWith(
            (ref) => Stream.value(expenses),
          ),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AnalyticsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Spend by category'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);

      // Sections further down are lazily built; scroll them into view.
      await tester.scrollUntilVisible(
        find.text('Top merchants'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Top merchants'), findsOneWidget);
      expect(find.text('Swiggy'), findsOneWidget);
    });
  });
}

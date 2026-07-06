import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/providers/providers.dart';

Expense _expense({
  required double amount,
  required DateTime timestamp,
  TransactionType type = TransactionType.debit,
}) {
  return Expense()
    ..amount = amount
    ..merchant = 'M'
    ..transactionType = type
    ..timestamp = timestamp;
}

void main() {
  group('totalSpentProvider', () {
    test('defaults to current month debits only', () async {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 10, 12);
      final lastMonth = DateTime(now.year, now.month - 1, 10);

      final container = ProviderContainer(
        overrides: [
          allExpensesProvider.overrideWith(
            (ref) => Stream.value([
              _expense(amount: 100, timestamp: thisMonth),
              _expense(amount: 50, timestamp: thisMonth),
              _expense(
                amount: 999,
                timestamp: thisMonth,
                type: TransactionType.credit,
              ),
              _expense(amount: 777, timestamp: lastMonth),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the stream to emit.
      await container.read(allExpensesProvider.future);
      final totals = container.read(totalSpentProvider).value!;

      expect(totals.total, 150);
      expect(totals.count, 2);
    });

    test('custom range includes end date and overrides month default',
        () async {
      final container = ProviderContainer(
        overrides: [
          allExpensesProvider.overrideWith(
            (ref) => Stream.value([
              _expense(amount: 10, timestamp: DateTime(2026, 1, 5)),
              _expense(amount: 20, timestamp: DateTime(2026, 1, 31, 18)),
              _expense(amount: 40, timestamp: DateTime(2026, 2, 1, 0, 30)),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(allExpensesProvider.future);
      container.read(spendRangeProvider.notifier).state = DateTimeRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31), // midnight end must still include 31st
      );

      final totals = container.read(totalSpentProvider).value!;
      expect(totals.total, 30);
      expect(totals.count, 2);
    });
  });
}

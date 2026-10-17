import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/repositories/expense_repository.dart';

void main() {
  late Isar isar;
  late ExpenseRepository repo;

  setUp(() async {
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [ExpenseSchema],
      directory: '',
      name: 'test_${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = ExpenseRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Expense makeExpense({
    required String merchant,
    required double amount,
    TransactionType type = TransactionType.debit,
    ExpenseSource source = ExpenseSource.sms,
    DateTime? timestamp,
  }) {
    return Expense()
      ..merchant = merchant
      ..amount = amount
      ..transactionType = type
      ..source = source
      ..timestamp = timestamp ?? DateTime.now()
      ..dedupeKey = 'key_${DateTime.now().microsecondsSinceEpoch}';
  }

  test(
    'review cleanup removes selected SMS only and guards changed messages',
    () async {
      final invalid = makeExpense(merchant: 'OTP', amount: 500)
        ..rawSms = 'OTP for INR 500';
      final manual = makeExpense(
        merchant: 'Cash',
        amount: 100,
        source: ExpenseSource.manual,
      )..rawSms = 'manual';
      final changed = makeExpense(merchant: 'Changed', amount: 200)
        ..rawSms = 'old message';
      final kept = makeExpense(merchant: 'Keep', amount: 300)
        ..rawSms = 'Rs.300 spent';
      await repo.saveAll([invalid, manual, changed, kept]);
      final snapshots = await repo.getAllExpenses();
      changed.rawSms = 'Rs.200 spent';
      await repo.saveExpense(changed);
      final selected = snapshots.where((entry) => entry.id != kept.id).toList();
      expect(await repo.removeReviewedSms(selected), 1);
      expect(
        (await repo.getAllExpenses()).map((entry) => entry.id),
        unorderedEquals([manual.id, changed.id, kept.id]),
      );
    },
  );

  group('searchAndFilter', () {
    test('search finds partial merchant match (case-insensitive)', () async {
      await repo.saveExpense(makeExpense(merchant: 'Amazon', amount: 500));
      await repo.saveExpense(makeExpense(merchant: 'Swiggy', amount: 200));
      await repo.saveExpense(
        makeExpense(merchant: 'amazon prime', amount: 300),
      );

      final results = await repo.searchAndFilter(query: 'ama');
      expect(results.length, 2);
      expect(
        results.every((e) => e.merchant.toLowerCase().contains('ama')),
        isTrue,
      );
    });

    test('filter by transaction type returns only matching type', () async {
      await repo.saveExpense(
        makeExpense(merchant: 'A', amount: 100, type: TransactionType.debit),
      );
      await repo.saveExpense(
        makeExpense(merchant: 'B', amount: 200, type: TransactionType.debit),
      );
      await repo.saveExpense(
        makeExpense(merchant: 'C', amount: 300, type: TransactionType.credit),
      );

      final results = await repo.searchAndFilter(
        transactionType: TransactionType.debit,
      );
      expect(results.length, 2);
      expect(
        results.every((e) => e.transactionType == TransactionType.debit),
        isTrue,
      );
    });

    test('filter by date range', () async {
      await repo.saveExpense(
        makeExpense(
          merchant: 'A',
          amount: 100,
          timestamp: DateTime(2025, 1, 15),
        ),
      );
      await repo.saveExpense(
        makeExpense(
          merchant: 'B',
          amount: 200,
          timestamp: DateTime(2025, 2, 15),
        ),
      );
      await repo.saveExpense(
        makeExpense(
          merchant: 'C',
          amount: 300,
          timestamp: DateTime(2025, 3, 15),
        ),
      );

      final results = await repo.searchAndFilter(
        dateRange: DateTimeRange(
          start: DateTime(2025, 1, 1),
          end: DateTime(2025, 1, 31),
        ),
      );
      expect(results.length, 1);
      expect(results.first.merchant, 'A');
    });

    test('date range includes expenses on the end date', () async {
      await repo.saveExpense(
        makeExpense(
          merchant: 'EndDay',
          amount: 100,
          timestamp: DateTime(2025, 1, 31, 12, 0),
        ),
      );
      await repo.saveExpense(
        makeExpense(
          merchant: 'NextDay',
          amount: 200,
          timestamp: DateTime(2025, 2, 1, 0, 30),
        ),
      );

      // Picker-style range with end at midnight.
      final results = await repo.searchAndFilter(
        dateRange: DateTimeRange(
          start: DateTime(2025, 1, 1),
          end: DateTime(2025, 1, 31),
        ),
      );
      expect(results.length, 1);
      expect(results.first.merchant, 'EndDay');
    });

    test('filter by amount range', () async {
      await repo.saveExpense(makeExpense(merchant: 'A', amount: 50));
      await repo.saveExpense(makeExpense(merchant: 'B', amount: 150));
      await repo.saveExpense(makeExpense(merchant: 'C', amount: 500));

      final results = await repo.searchAndFilter(
        minAmount: 100,
        maxAmount: 200,
      );
      expect(results.length, 1);
      expect(results.first.merchant, 'B');
    });

    test('filter by source', () async {
      await repo.saveExpense(
        makeExpense(merchant: 'A', amount: 100, source: ExpenseSource.sms),
      );
      await repo.saveExpense(
        makeExpense(merchant: 'B', amount: 200, source: ExpenseSource.manual),
      );

      final results = await repo.searchAndFilter(source: ExpenseSource.manual);
      expect(results.length, 1);
      expect(results.first.merchant, 'B');
    });

    test('combined search + filter uses AND logic', () async {
      await repo.saveExpense(
        makeExpense(
          merchant: 'Amazon',
          amount: 100,
          type: TransactionType.debit,
        ),
      );
      await repo.saveExpense(
        makeExpense(
          merchant: 'Amazon',
          amount: 200,
          type: TransactionType.credit,
        ),
      );
      await repo.saveExpense(
        makeExpense(
          merchant: 'Swiggy',
          amount: 300,
          type: TransactionType.debit,
        ),
      );

      final results = await repo.searchAndFilter(
        query: 'amazon',
        transactionType: TransactionType.debit,
      );
      expect(results.length, 1);
      expect(results.first.merchant, 'Amazon');
      expect(results.first.amount, 100);
    });

    test('returns all when no filters applied', () async {
      await repo.saveExpense(makeExpense(merchant: 'A', amount: 100));
      await repo.saveExpense(makeExpense(merchant: 'B', amount: 200));

      final results = await repo.searchAndFilter();
      expect(results.length, 2);
    });
  });

  group('clearAll and saveAll', () {
    test('clearAll removes all expenses', () async {
      await repo.saveExpense(makeExpense(merchant: 'A', amount: 100));
      await repo.saveExpense(makeExpense(merchant: 'B', amount: 200));

      await repo.clearAll();
      final all = await repo.getAllExpenses();
      expect(all, isEmpty);
    });

    test('saveAll inserts multiple expenses', () async {
      final expenses = [
        makeExpense(merchant: 'A', amount: 100),
        makeExpense(merchant: 'B', amount: 200),
      ];

      await repo.saveAll(expenses);
      final all = await repo.getAllExpenses();
      expect(all.length, 2);
    });

    test('duplicate dedupeKey replaces instead of duplicating', () async {
      final first = makeExpense(merchant: 'First', amount: 100)
        ..dedupeKey = 'same-key';
      final second = makeExpense(merchant: 'Second', amount: 100)
        ..dedupeKey = 'same-key';

      await repo.saveExpense(first);
      await repo.saveExpense(second);

      final all = await repo.getAllExpenses();
      expect(all.length, 1);
      expect(all.first.merchant, 'Second');
    });

    test('replaceAll swaps existing data atomically', () async {
      await repo.saveExpense(makeExpense(merchant: 'Old', amount: 100));

      await repo.replaceAll([
        makeExpense(merchant: 'New1', amount: 10),
        makeExpense(merchant: 'New2', amount: 20),
      ]);

      final all = await repo.getAllExpenses();
      expect(all.length, 2);
      expect(all.any((e) => e.merchant == 'Old'), isFalse);
    });
  });
}

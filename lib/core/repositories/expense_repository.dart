import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this._isar);

  final Isar _isar;

  Stream<List<Expense>> watchAllExpenses() {
    return _isar.expenses.where().sortByTimestampDesc().watch(fireImmediately: true);
  }

  Future<List<Expense>> getAllExpenses() {
    return _isar.expenses.where().sortByTimestampDesc().findAll();
  }

  Stream<List<Expense>> watchMonthlyExpenses(DateTime month) {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 1);
    return _isar.expenses
        .filter()
        .timestampGreaterThan(start, include: true)
        .and()
        .timestampLessThan(end, include: false)
        .sortByTimestampDesc()
        .watch(fireImmediately: true);
  }

  Future<List<Expense>> getMonthlyExpenses(DateTime month) {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 1);
    return _isar.expenses
        .filter()
        .timestampGreaterThan(start, include: true)
        .and()
        .timestampLessThan(end, include: false)
        .sortByTimestampDesc()
        .findAll();
  }

  Future<bool> existsByDedupeKey(String key) async {
    final expense = await _isar.expenses.filter().dedupeKeyEqualTo(key).findFirst();
    return expense != null;
  }

  Future<void> saveExpense(Expense expense) async {
    await _isar.writeTxn(() async {
      await _isar.expenses.put(expense);
    });
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.expenses.clear();
    });
  }

  Future<void> saveAll(List<Expense> expenses) async {
    await _isar.writeTxn(() async {
      await _isar.expenses.putAll(expenses);
    });
  }

  /// Atomically replaces all expenses: existing data is only cleared if the
  /// whole write succeeds.
  Future<void> replaceAll(List<Expense> expenses) async {
    await _isar.writeTxn(() async {
      await _isar.expenses.clear();
      await _isar.expenses.putAll(expenses);
    });
  }

  Future<List<Expense>> searchAndFilter({
    String? query,
    DateTimeRange? dateRange,
    TransactionType? transactionType,
    double? minAmount,
    double? maxAmount,
    ExpenseSource? source,
  }) async {
    final all = await getAllExpenses();

    return all.where((expense) {
      if (query != null && query.isNotEmpty) {
        if (!expense.merchant.toLowerCase().contains(query.toLowerCase())) {
          return false;
        }
      }

      if (dateRange != null) {
        // End date is inclusive for the whole day, even when the picker
        // returns it at midnight.
        final endExclusive = DateTime(
          dateRange.end.year,
          dateRange.end.month,
          dateRange.end.day + 1,
        );
        if (expense.timestamp.isBefore(dateRange.start) ||
            !expense.timestamp.isBefore(endExclusive)) {
          return false;
        }
      }

      if (transactionType != null && expense.transactionType != transactionType) {
        return false;
      }

      if (minAmount != null && expense.amount < minAmount) {
        return false;
      }

      if (maxAmount != null && expense.amount > maxAmount) {
        return false;
      }

      if (source != null && expense.source != source) {
        return false;
      }

      return true;
    }).toList();
  }
}

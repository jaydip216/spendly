import 'dart:convert';

import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/repositories/expense_repository.dart';

class BackupService {
  BackupService(this._repository);
  final ExpenseRepository _repository;

  static const int currentSchemaVersion = 1;

  /// Export all expenses to JSON string
  Future<String> exportToJson() async {
    final expenses = await _repository.getAllExpenses();
    final data = {
      'schemaVersion': currentSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'expenses': expenses.map((e) => _expenseToMap(e)).toList(),
    };
    return jsonEncode(data);
  }

  /// Import expenses from JSON string. REPLACES all existing data.
  Future<void> importFromJson(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final version = data['schemaVersion'] as int?;
    if (version == null || version > currentSchemaVersion) {
      throw FormatException('Unsupported schema version: $version');
    }
    // Parse the entire payload before touching the database so a malformed
    // backup cannot wipe existing data.
    final expenseList = (data['expenses'] as List)
        .map((e) => _mapToExpense(e as Map<String, dynamic>))
        .toList();
    await _repository.replaceAll(expenseList);
  }

  Map<String, dynamic> _expenseToMap(Expense e) {
    return {
      'amount': e.amount,
      'merchant': e.merchant,
      'timestamp': e.timestamp.toIso8601String(),
      'transactionType': e.transactionType.name,
      'source': e.source.name,
      'notes': e.notes,
      'sender': e.sender,
      'rawSms': e.rawSms,
      'currency': e.currency,
      'upiId': e.upiId,
      'cardLastFour': e.cardLastFour,
      'bankName': e.bankName,
      'dedupeKey': e.dedupeKey,
      'createdAt': e.createdAt.toIso8601String(),
    };
  }

  Expense _mapToExpense(Map<String, dynamic> map) {
    return Expense()
      ..amount = (map['amount'] as num).toDouble()
      ..merchant = map['merchant'] as String? ?? ''
      ..timestamp = DateTime.parse(map['timestamp'] as String)
      ..transactionType = TransactionType.values.firstWhere(
        (t) => t.name == map['transactionType'],
        orElse: () => TransactionType.debit,
      )
      ..source = ExpenseSource.values.firstWhere(
        (s) => s.name == map['source'],
        orElse: () => ExpenseSource.sms,
      )
      ..notes = map['notes'] as String?
      ..sender = map['sender'] as String? ?? ''
      ..rawSms = map['rawSms'] as String? ?? ''
      ..currency = map['currency'] as String? ?? 'INR'
      ..upiId = map['upiId'] as String?
      ..cardLastFour = map['cardLastFour'] as String?
      ..bankName = map['bankName'] as String?
      ..dedupeKey = map['dedupeKey'] as String? ?? ''
      ..createdAt = map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now();
  }
}

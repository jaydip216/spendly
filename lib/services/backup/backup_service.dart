import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:spendly/core/models/category.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/repositories/expense_repository.dart';
import 'package:spendly/services/categorization/category_rules.dart';

class BackupService {
  BackupService(this._isar, this._repository);

  final Isar _isar;
  final ExpenseRepository _repository;

  /// v1: expenses only. v2: adds categories + per-expense category.
  static const int currentSchemaVersion = 2;

  /// Export all expenses and categories to JSON string
  Future<String> exportToJson() async {
    final expenses = await _repository.getAllExpenses();
    final categories = await _isar.categorys.where().findAll();
    final data = {
      'schemaVersion': currentSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => _categoryToMap(c)).toList(),
      'expenses': expenses.map((e) => _expenseToMap(e)).toList(),
    };
    return jsonEncode(data);
  }

  /// Import expenses and categories from JSON string. REPLACES all existing
  /// data atomically: nothing is cleared unless the whole payload parsed.
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

    // v1 backups carry no categories: seed the defaults and auto-categorize.
    final List<Category> categoryList;
    if (data['categories'] is List) {
      categoryList = (data['categories'] as List)
          .map((c) => _mapToCategory(c as Map<String, dynamic>))
          .toList();
    } else {
      categoryList = [
        for (final def in CategoryRules.defaultCategories)
          Category()
            ..name = def.name
            ..colorValue = def.colorValue
            ..isDefault = true,
      ];
    }

    // Old backups may carry empty dedupe keys; synthesize unique ones so
    // the unique dedupeKey index doesn't collapse them into a single row.
    final importedAtMs = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < expenseList.length; i++) {
      if (expenseList[i].dedupeKey.isEmpty) {
        expenseList[i].dedupeKey = 'imported_${importedAtMs}_$i';
      }
    }

    await _isar.writeTxn(() async {
      await _isar.expenses.clear();
      await _isar.categorys.clear();
      await _isar.categorys.putAll(categoryList);
      await _isar.expenses.putAll(expenseList);
    });
  }

  Map<String, dynamic> _categoryToMap(Category c) {
    return {
      'name': c.name,
      'colorValue': c.colorValue,
      'isDefault': c.isDefault,
    };
  }

  Category _mapToCategory(Map<String, dynamic> map) {
    return Category()
      ..name = map['name'] as String? ?? ''
      ..colorValue = map['colorValue'] as int? ?? 0xFF9E9E9E
      ..isDefault = map['isDefault'] as bool? ?? false;
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
      'category': e.category,
      'dedupeKey': e.dedupeKey,
      'createdAt': e.createdAt.toIso8601String(),
    };
  }

  Expense _mapToExpense(Map<String, dynamic> map) {
    final merchant = map['merchant'] as String? ?? '';
    final upiId = map['upiId'] as String?;
    final rawSms = map['rawSms'] as String? ?? '';
    final storedCategory = map['category'] as String? ?? '';

    return Expense()
      ..amount = (map['amount'] as num).toDouble()
      ..merchant = merchant
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
      ..rawSms = rawSms
      ..currency = map['currency'] as String? ?? 'INR'
      ..upiId = upiId
      ..cardLastFour = map['cardLastFour'] as String?
      ..bankName = map['bankName'] as String?
      // v1 backups have no category: auto-categorize on the way in.
      ..category = storedCategory.isNotEmpty
          ? storedCategory
          : CategoryRules.categorize(
              merchant: merchant,
              upiId: upiId,
              rawText: rawSms,
            )
      ..dedupeKey = map['dedupeKey'] as String? ?? ''
      ..createdAt = map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now();
  }
}

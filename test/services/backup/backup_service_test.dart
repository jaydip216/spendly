import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/repositories/expense_repository.dart';
import 'package:spendly/services/backup/backup_service.dart';

void main() {
  late Isar isar;
  late ExpenseRepository repo;
  late BackupService backupService;

  setUp(() async {
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [ExpenseSchema],
      directory: '',
      name: 'backup_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = ExpenseRepository(isar);
    backupService = BackupService(repo);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Expense makeExpense({
    String merchant = 'TestMerchant',
    double amount = 100.0,
    TransactionType type = TransactionType.debit,
    ExpenseSource source = ExpenseSource.sms,
    DateTime? timestamp,
    String? notes,
    String? upiId,
    String? cardLastFour,
    String? bankName,
  }) {
    return Expense()
      ..merchant = merchant
      ..amount = amount
      ..transactionType = type
      ..source = source
      ..timestamp = timestamp ?? DateTime(2025, 6, 15, 10, 30)
      ..sender = 'HDFC-Bank'
      ..rawSms = 'Rs.$amount debited from $merchant'
      ..currency = 'INR'
      ..upiId = upiId
      ..cardLastFour = cardLastFour
      ..bankName = bankName
      ..dedupeKey = 'key_${DateTime.now().microsecondsSinceEpoch}'
      ..notes = notes
      ..createdAt = DateTime(2025, 6, 15, 10, 31);
  }

  group('exportToJson', () {
    test('produces valid JSON with schemaVersion=1', () async {
      await repo.saveExpense(makeExpense());

      final json = await backupService.exportToJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['schemaVersion'], 1);
      expect(decoded['exportedAt'], isA<String>());
      expect(decoded['expenses'], isA<List>());
    });

    test('includes all expense fields', () async {
      final expense = makeExpense(
        merchant: 'Amazon',
        amount: 499.0,
        type: TransactionType.debit,
        source: ExpenseSource.manual,
        notes: 'Prime subscription',
        upiId: 'amazon@upi',
        cardLastFour: '1234',
        bankName: 'HDFC',
      );
      await repo.saveExpense(expense);

      final json = await backupService.exportToJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final expMap = (decoded['expenses'] as List).first as Map<String, dynamic>;

      expect(expMap['merchant'], 'Amazon');
      expect(expMap['amount'], 499.0);
      expect(expMap['transactionType'], 'debit');
      expect(expMap['source'], 'manual');
      expect(expMap['notes'], 'Prime subscription');
      expect(expMap['upiId'], 'amazon@upi');
      expect(expMap['cardLastFour'], '1234');
      expect(expMap['bankName'], 'HDFC');
      expect(expMap['currency'], 'INR');
      expect(expMap['sender'], 'HDFC-Bank');
      expect(expMap['timestamp'], isA<String>());
      expect(expMap['createdAt'], isA<String>());
      expect(expMap['dedupeKey'], isA<String>());
    });

    test('exports empty list when no expenses', () async {
      final json = await backupService.exportToJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['expenses'], isEmpty);
    });
  });

  group('importFromJson', () {
    test('round-trip preserves all fields', () async {
      final original = makeExpense(
        merchant: 'Swiggy',
        amount: 250.0,
        type: TransactionType.credit,
        source: ExpenseSource.sms,
        notes: 'Lunch',
        upiId: 'swiggy@upi',
        cardLastFour: '5678',
        bankName: 'SBI',
      );
      await repo.saveExpense(original);

      final json = await backupService.exportToJson();
      await backupService.importFromJson(json);

      final restored = await repo.getAllExpenses();
      expect(restored.length, 1);
      final r = restored.first;
      expect(r.merchant, 'Swiggy');
      expect(r.amount, 250.0);
      expect(r.transactionType, TransactionType.credit);
      expect(r.source, ExpenseSource.sms);
      expect(r.notes, 'Lunch');
      expect(r.upiId, 'swiggy@upi');
      expect(r.cardLastFour, '5678');
      expect(r.bankName, 'SBI');
      expect(r.currency, 'INR');
      expect(r.sender, 'HDFC-Bank');
    });

    test('import REPLACES existing data, not merges', () async {
      // Save initial data
      await repo.saveExpense(makeExpense(merchant: 'OldMerchant', amount: 999.0));
      expect((await repo.getAllExpenses()).length, 1);

      // Create a backup with different data
      await repo.clearAll();
      await repo.saveExpense(makeExpense(merchant: 'NewMerchant', amount: 111.0));
      final json = await backupService.exportToJson();

      // Add more data before import
      await repo.saveExpense(makeExpense(merchant: 'ExtraMerchant', amount: 222.0));
      expect((await repo.getAllExpenses()).length, 2);

      // Import should replace all
      await backupService.importFromJson(json);
      final result = await repo.getAllExpenses();
      expect(result.length, 1);
      expect(result.first.merchant, 'NewMerchant');
    });

    test('throws FormatException for unsupported schema version', () async {
      final badJson = jsonEncode({
        'schemaVersion': 999,
        'exportedAt': DateTime.now().toIso8601String(),
        'expenses': [],
      });

      expect(
        () => backupService.importFromJson(badJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when schemaVersion is null', () async {
      final badJson = jsonEncode({
        'exportedAt': DateTime.now().toIso8601String(),
        'expenses': [],
      });

      expect(
        () => backupService.importFromJson(badJson),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

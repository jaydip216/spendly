import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/spendly_app.dart';
import 'core/database/isar_service.dart';
import 'core/providers/providers.dart';
import 'core/repositories/category_repository.dart';
import 'core/repositories/expense_repository.dart';
import 'services/backup/backup_service.dart';
import 'services/backup/google_drive_service.dart';
import 'services/categorization/category_rules.dart';
import 'services/parser/transaction_parser.dart';
import 'services/sms/sms_ingestion_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isar = await openSpendlyIsar();
  final repository = ExpenseRepository(isar);
  final categoryRepository = CategoryRepository(isar);
  await categoryRepository.seedDefaults();
  await _backfillCategoriesOnce(prefs, repository);
  final parser = TransactionParser();
  final smsIngestionService = SmsIngestionService(
    repository: repository,
    parser: parser,
  );
  final backupService = BackupService(isar, repository);
  final googleDriveService = GoogleDriveService(backupService);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarProvider.overrideWithValue(isar),
        expenseRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(categoryRepository),
        transactionParserProvider.overrideWithValue(parser),
        smsIngestionServiceProvider.overrideWithValue(smsIngestionService),
        backupServiceProvider.overrideWithValue(backupService),
        googleDriveServiceProvider.overrideWithValue(googleDriveService),
      ],
      child: const SpendlyApp(),
    ),
  );
}

/// One-time retroactive categorization of expenses saved before the category
/// field existed (they deserialize with an empty category).
Future<void> _backfillCategoriesOnce(
  SharedPreferences prefs,
  ExpenseRepository repository,
) async {
  if (prefs.getBool(categoriesBackfillDoneKey) ?? false) {
    return;
  }

  final expenses = await repository.getAllExpenses();
  final needingCategory =
      expenses.where((e) => e.category.isEmpty).toList();
  for (final expense in needingCategory) {
    expense.category = CategoryRules.categorize(
      merchant: expense.merchant,
      upiId: expense.upiId,
      rawText: expense.rawSms,
    );
  }
  if (needingCategory.isNotEmpty) {
    await repository.saveAll(needingCategory);
  }
  await prefs.setBool(categoriesBackfillDoneKey, true);
}

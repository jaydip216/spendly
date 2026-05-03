import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/spendly_app.dart';
import 'core/database/isar_service.dart';
import 'core/providers/providers.dart';
import 'core/repositories/expense_repository.dart';
import 'services/parser/transaction_parser.dart';
import 'services/sms/sms_ingestion_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isar = await openSpendlyIsar();
  final repository = ExpenseRepository(isar);
  final parser = TransactionParser();
  final smsIngestionService = SmsIngestionService(
    repository: repository,
    parser: parser,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarProvider.overrideWithValue(isar),
        expenseRepositoryProvider.overrideWithValue(repository),
        transactionParserProvider.overrideWithValue(parser),
        smsIngestionServiceProvider.overrideWithValue(smsIngestionService),
      ],
      child: const SpendlyApp(),
    ),
  );
}

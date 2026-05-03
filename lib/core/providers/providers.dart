import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import '../../services/parser/transaction_parser.dart';
import '../../services/sms/sms_ingestion_service.dart';

const onboardingSeenKey = 'onboarding_seen';
const initialSmsSyncDoneKey = 'initial_sms_sync_done';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main'),
);

final isarProvider = Provider<Isar>(
  (ref) => throw UnimplementedError('isarProvider must be overridden in main'),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => throw UnimplementedError('expenseRepositoryProvider must be overridden in main'),
);

final transactionParserProvider = Provider<TransactionParser>(
  (ref) => throw UnimplementedError('transactionParserProvider must be overridden in main'),
);

final smsIngestionServiceProvider = Provider<SmsIngestionService>(
  (ref) => throw UnimplementedError('smsIngestionServiceProvider must be overridden in main'),
);

final allExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchAllExpenses();
});

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthlyExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  final month = ref.watch(selectedMonthProvider);
  return repo.watchMonthlyExpenses(month);
});

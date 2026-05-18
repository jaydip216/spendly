import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import '../../services/backup/backup_service.dart';
import '../../services/backup/google_drive_service.dart';
import '../../services/parser/transaction_parser.dart';
import '../../services/sms/sms_ingestion_service.dart';

const onboardingSeenKey = 'onboarding_seen';
const initialSmsSyncDoneKey = 'initial_sms_sync_done';
const themeModePreferenceKey = 'theme_mode';
const lastBackupTimestampKey = 'last_backup_timestamp';

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs)
    : super(_decodeThemeMode(_prefs.getString(themeModePreferenceKey)));

  final SharedPreferences _prefs;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) {
      return;
    }

    state = mode;
    await _prefs.setString(themeModePreferenceKey, _encodeThemeMode(mode));
  }

  static ThemeMode _decodeThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main',
  ),
);

final isarProvider = Provider<Isar>(
  (ref) => throw UnimplementedError('isarProvider must be overridden in main'),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => throw UnimplementedError(
    'expenseRepositoryProvider must be overridden in main',
  ),
);

final transactionParserProvider = Provider<TransactionParser>(
  (ref) => throw UnimplementedError(
    'transactionParserProvider must be overridden in main',
  ),
);

final smsIngestionServiceProvider = Provider<SmsIngestionService>(
  (ref) => throw UnimplementedError(
    'smsIngestionServiceProvider must be overridden in main',
  ),
);

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ThemeModeController(prefs);
  },
);

final allExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchAllExpenses();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final filterTransactionTypeProvider = StateProvider<TransactionType?>((ref) => null);

final filterSourceProvider = StateProvider<ExpenseSource?>((ref) => null);

final filterMinAmountProvider = StateProvider<double?>((ref) => null);

final filterMaxAmountProvider = StateProvider<double?>((ref) => null);

final filterDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final filteredExpensesProvider = FutureProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  final type = ref.watch(filterTransactionTypeProvider);
  final source = ref.watch(filterSourceProvider);
  final minAmount = ref.watch(filterMinAmountProvider);
  final maxAmount = ref.watch(filterMaxAmountProvider);
  final dateRange = ref.watch(filterDateRangeProvider);
  return repo.searchAndFilter(
    query: query.isEmpty ? null : query,
    transactionType: type,
    source: source,
    minAmount: minAmount,
    maxAmount: maxAmount,
    dateRange: dateRange,
  );
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

final backupServiceProvider = Provider<BackupService>(
  (ref) => throw UnimplementedError(
    'backupServiceProvider must be overridden in main',
  ),
);

final googleDriveServiceProvider = Provider<GoogleDriveService>(
  (ref) => throw UnimplementedError(
    'googleDriveServiceProvider must be overridden in main',
  ),
);

final lastBackupProvider = Provider<DateTime?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final ms = prefs.getInt(lastBackupTimestampKey);
  if (ms == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms);
});

final backupNudgeDismissedProvider = StateProvider<bool>((ref) => false);

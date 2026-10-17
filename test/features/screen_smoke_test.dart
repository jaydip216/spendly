import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendly/app/theme/spendly_theme.dart';
import 'package:spendly/core/models/category.dart' as models;
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/providers/providers.dart';
import 'package:spendly/features/analytics/analytics_screen.dart';
import 'package:spendly/features/home/home_screen.dart';
import 'package:spendly/features/settings/settings_screen.dart';
import 'package:spendly/features/spends/spends_screen.dart';

/// Renders each tab at a phone viewport with realistic data and asserts the
/// frame builds clean — no overflows, no missing ancestors. Cheap insurance
/// for a layout built almost entirely out of hand-placed rules and figures.

models.Category _category(String name, int color) => models.Category()
  ..name = name
  ..colorValue = color;

Expense _expense({
  required String merchant,
  required String category,
  required double amount,
  required DateTime timestamp,
  String? upiId,
  String? cardLastFour,
  String? bankName,
}) {
  return Expense()
    ..merchant = merchant
    ..category = category
    ..amount = amount
    ..timestamp = timestamp
    ..sender = 'HDFCBK'
    ..rawSms = 'Rs.$amount debited at $merchant'
    ..upiId = upiId
    ..cardLastFour = cardLastFour
    ..bankName = bankName
    ..transactionType = TransactionType.debit
    ..source = ExpenseSource.sms;
}

void main() {
  const viewport = Size(412, 892);

  late List<Expense> expenses;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_seen': true,
      'initial_sms_sync_done': true,
    });
    prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    expenses = [
      _expense(
        merchant: 'Rent — a merchant name long enough to need truncating',
        category: 'Other',
        amount: 2400000.55,
        timestamp: thisMonth.add(const Duration(days: 1)),
        bankName: 'HDFC',
        cardLastFour: '4821',
      ),
      _expense(
        merchant: 'Amazon',
        category: 'Shopping',
        amount: 4299,
        timestamp: thisMonth.add(const Duration(days: 2)),
        cardLastFour: '4821',
      ),
      _expense(
        merchant: 'Swiggy',
        category: 'Food',
        amount: 486,
        timestamp: thisMonth.add(const Duration(days: 2, hours: 3)),
        upiId: 'swiggy@okicici',
      ),
      _expense(
        merchant: 'Blinkit',
        category: 'Groceries',
        amount: 318,
        timestamp: DateTime(now.year, now.month - 1, 14),
        upiId: 'blinkit@okhdfcbank',
      ),
      _expense(
        merchant: 'Indian Oil',
        category: 'Transport',
        amount: 2500,
        timestamp: DateTime(now.year, now.month - 2, 9),
      ),
    ];
  });

  Widget subject(Widget screen, {Brightness brightness = Brightness.light}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allExpensesProvider.overrideWith((ref) => Stream.value(expenses)),
        monthlyExpensesProvider.overrideWith(
          (ref) => Stream.value(
            expenses.where((e) {
              final month = ref.watch(selectedMonthProvider);
              return e.timestamp.year == month.year &&
                  e.timestamp.month == month.month;
            }).toList(),
          ),
        ),
        categoriesProvider.overrideWith(
          (ref) => Stream.value([
            _category('Food', 0xFFB68235),
            _category('Groceries', 0xFF5A6B5D),
            _category('Transport', 0xFF37474F),
            _category('Shopping', 0xFF7D5411),
            _category('Other', 0xFF8A8177),
          ]),
        ),
      ],
      child: MaterialApp(theme: buildSpendlyTheme(brightness), home: screen),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(subject(screen));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('Home renders the month, its meters and recent spends', (
    tester,
  ) async {
    await pumpAt(tester, const HomeScreen());

    expect(find.text('Spendly'), findsOneWidget);
    expect(find.byKey(const Key('home_month_total')), findsOneWidget);
    expect(find.text('Where it went'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('Spends renders grouped rows', (tester) async {
    await pumpAt(tester, const SpendsScreen());

    expect(find.text('All spends'), findsOneWidget);
    expect(find.text('Swiggy'), findsOneWidget);
  });

  testWidgets('Insights renders trend, donut and breakdowns', (tester) async {
    await pumpAt(tester, const AnalyticsScreen());

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('ACROSS THE MONTHS'), findsOneWidget);
    expect(find.text('BY CATEGORY'), findsOneWidget);
  });

  testWidgets('Settings renders every group', (tester) async {
    await pumpAt(tester, const SettingsScreen());

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
  });

  for (final entry in <String, Widget>{
    'Home': const HomeScreen(),
    'Spends': const SpendsScreen(),
    'Insights': const AnalyticsScreen(),
    'Settings': const SettingsScreen(),
  }.entries) {
    testWidgets('${entry.key} in the dark theme builds clean', (tester) async {
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        subject(entry.value, brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

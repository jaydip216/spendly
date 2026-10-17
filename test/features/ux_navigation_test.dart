import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendly/app/spendly_app.dart';
import 'package:spendly/app/theme/spendly_theme.dart';
import 'package:spendly/app/widgets/classical.dart';
import 'package:spendly/core/providers/providers.dart';
import 'package:spendly/features/home/widgets/month_picker.dart';
import 'package:spendly/services/sms/sms_ingestion_service.dart';

// ignore: subtype_of_sealed_class
class _FakeSmsIngestionService implements SmsIngestionService {
  @override
  Future<void> start() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not implemented');
}

void main() {
  testWidgets('compact controls keep a 48dp touch target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildSpendlyTheme(Brightness.light),
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconAction(
                  key: const Key('small_icon'),
                  icon: Icons.chevron_left,
                  size: 28,
                  onPressed: () => taps++,
                ),
                PillChip(
                  key: const Key('chip'),
                  label: 'Food',
                  selected: false,
                  onTap: () => taps++,
                ),
                ClassicalButton(
                  key: const Key('button'),
                  label: 'Reset',
                  height: 40,
                  onPressed: () => taps++,
                ),
                const MonthSwitcher(compact: true),
              ],
            ),
          ),
        ),
      ),
    );

    for (final key in const [Key('small_icon'), Key('chip'), Key('button')]) {
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(key));
    }
    expect(
      tester.getSize(find.byKey(const Key('month_label'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(taps, 3);
  });

  testWidgets('Android Back follows tab history', (tester) async {
    SharedPreferences.setMockInitialValues({onboardingSeenKey: true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          smsIngestionServiceProvider.overrideWithValue(
            _FakeSmsIngestionService(),
          ),
          allExpensesProvider.overrideWith((ref) => Stream.value(const [])),
          monthlyExpensesProvider.overrideWith((ref) => Stream.value(const [])),
          categoriesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const SpendlyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spends'));
    await tester.pumpAndSettle();
    expect(find.text('All spends'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR DATA'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('All spends'), findsOneWidget);
  });
}

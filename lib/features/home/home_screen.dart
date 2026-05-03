import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../../services/sms/sms_ingestion_service.dart';
import '../expenses/widgets/expense_card.dart';
import '../onboarding/transparency_screen.dart';
import 'monthly_view_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final seenOnboarding = prefs.getBool(onboardingSeenKey) ?? false;

    if (seenOnboarding) {
      final SmsIngestionService ingestion = ref.read(
        smsIngestionServiceProvider,
      );
      await ingestion.start();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _ready = true;
    });
  }

  Future<void> _syncInbox() async {
    await ref.read(smsIngestionServiceProvider).ingestHistoricalInbox();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('SMS sync completed.')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final prefs = ref.watch(sharedPreferencesProvider);
    final seenOnboarding = prefs.getBool(onboardingSeenKey) ?? false;

    if (!seenOnboarding) {
      return TransparencyScreen(
        onCompleted: () async {
          if (mounted) {
            setState(() {});
          }
        },
      );
    }

    final expensesAsync = ref.watch(allExpensesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spendly',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Track every rupee from SMS',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const TabBar(
                  tabs: [
                    Tab(text: 'All Expenses'),
                    Tab(text: 'Monthly'),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            const _ThemeModeButton(),
            IconButton(
              tooltip: 'Sync existing SMS',
              onPressed: _syncInbox,
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primaryContainer.withAlpha(90),
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
          child: TabBarView(
            children: [
              expensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const _EmptyExpensesState();
                  }

                  final debitTotal = expenses
                      .where(
                        (item) => item.transactionType == TransactionType.debit,
                      )
                      .fold<double>(0, (sum, item) => sum + item.amount);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(
                      children: [
                        _DashboardOverview(
                          totalSpent: debitTotal,
                          count: expenses.length,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: expenses.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return ExpenseCard(expense: expenses[index]);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Failed to load expenses: $error')),
              ),
              const MonthlyViewScreen(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyExpensesState extends StatelessWidget {
  const _EmptyExpensesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.sms_rounded,
                  size: 34,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No expenses yet',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Spendly auto-detects debit transactions from your SMS inbox and keeps everything on device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({required this.totalSpent, required this.count});

  final double totalSpent;
  final int count;

  @override
  Widget build(BuildContext context) {
    final amountFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
      locale: 'en_IN',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Total spend',
                value: amountFormat.format(totalSpent),
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: 'Transactions',
                value: '$count',
                icon: Icons.receipt_long_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeButton extends ConsumerWidget {
  const _ThemeModeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme mode',
      icon: Icon(_modeIcon(mode)),
      onSelected: (mode) {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: ThemeMode.system, child: Text('System')),
        const PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
        const PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
      ],
    );
  }

  IconData _modeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_6_rounded;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      final SmsIngestionService ingestion = ref.read(smsIngestionServiceProvider);
      await ingestion.start();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
          title: const Text('Spendly'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All Expenses'),
              Tab(text: 'Monthly'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Sync existing SMS',
              onPressed: () async {
                await ref.read(smsIngestionServiceProvider).ingestHistoricalInbox();
              },
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const _EmptyExpensesState();
                }
                return ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    return ExpenseCard(expense: expenses[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load expenses: $error')),
            ),
            const MonthlyViewScreen(),
          ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.sms, size: 48),
            SizedBox(height: 12),
            Text(
              'No expenses yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Spendly will auto-register expenses from SMS once transaction alerts are received.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

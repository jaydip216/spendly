import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/providers/providers.dart';
import 'package:spendly/core/repositories/expense_repository.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

// ignore: subtype_of_sealed_class
class FakeExpenseRepository implements ExpenseRepository {
  final List<Expense> _expenses = [];

  void seedExpenses(List<Expense> expenses) {
    _expenses
      ..clear()
      ..addAll(expenses);
  }

  @override
  Stream<List<Expense>> watchAllExpenses() =>
      Stream.value(List.from(_expenses));

  @override
  Future<List<Expense>> getAllExpenses() async => List.from(_expenses);

  @override
  Future<List<Expense>> searchAndFilter({
    String? query,
    DateTimeRange? dateRange,
    TransactionType? transactionType,
    double? minAmount,
    double? maxAmount,
    ExpenseSource? source,
  }) async {
    return _expenses.where((e) {
      if (query != null && query.isNotEmpty) {
        if (!e.merchant.toLowerCase().contains(query.toLowerCase())) {
          return false;
        }
      }
      if (transactionType != null && e.transactionType != transactionType) {
        return false;
      }
      if (source != null && e.source != source) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<bool> existsByDedupeKey(String key) async => false;

  @override
  Future<void> saveExpense(Expense expense) async {}

  @override
  Future<int> removeReviewedSms(List<Expense> reviewed) async => 0;

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> saveAll(List<Expense> expenses) async {}

  @override
  Future<void> replaceAll(List<Expense> expenses) async {
    _expenses
      ..clear()
      ..addAll(expenses);
  }

  @override
  Stream<List<Expense>> watchMonthlyExpenses(DateTime month) =>
      Stream.value([]);

  @override
  Future<List<Expense>> getMonthlyExpenses(DateTime month) async => [];
}

// ---------------------------------------------------------------------------
// Standalone test widget that mirrors the search/filter UI
// ---------------------------------------------------------------------------

class _SearchFilterTestWidget extends ConsumerStatefulWidget {
  const _SearchFilterTestWidget();

  @override
  ConsumerState<_SearchFilterTestWidget> createState() =>
      _SearchFilterTestWidgetState();
}

class _SearchFilterTestWidgetState
    extends ConsumerState<_SearchFilterTestWidget> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final typeFilter = ref.watch(filterTransactionTypeProvider);
    final sourceFilter = ref.watch(filterSourceProvider);

    final isFiltering =
        query.isNotEmpty || typeFilter != null || sourceFilter != null;

    final expensesAsync = isFiltering
        ? ref.watch(filteredExpensesProvider)
        : ref.watch(allExpensesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              key: const Key('search_bar'),
              controller: _searchController,
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
              decoration: InputDecoration(
                hintText: 'Search by merchant…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    key: const Key('filter_chip_Debit'),
                    label: const Text('Debit'),
                    selected: typeFilter == TransactionType.debit,
                    onSelected: (selected) {
                      ref.read(filterTransactionTypeProvider.notifier).state =
                          selected ? TransactionType.debit : null;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    key: const Key('filter_chip_Credit'),
                    label: const Text('Credit'),
                    selected: typeFilter == TransactionType.credit,
                    onSelected: (selected) {
                      ref.read(filterTransactionTypeProvider.notifier).state =
                          selected ? TransactionType.credit : null;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    key: const Key('filter_chip_SMS'),
                    label: const Text('SMS'),
                    selected: sourceFilter == ExpenseSource.sms,
                    onSelected: (selected) {
                      ref.read(filterSourceProvider.notifier).state = selected
                          ? ExpenseSource.sms
                          : null;
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    key: const Key('filter_chip_Manual'),
                    label: const Text('Manual'),
                    selected: sourceFilter == ExpenseSource.manual,
                    onSelected: (selected) {
                      ref.read(filterSourceProvider.notifier).state = selected
                          ? ExpenseSource.manual
                          : null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: expensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const Center(
                      key: Key('no_results'),
                      child: Text('No results found'),
                    );
                  }
                  return ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (context, index) =>
                        Text(expenses[index].merchant),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildTestWidget(FakeExpenseRepository fakeRepo) {
  return ProviderScope(
    overrides: [expenseRepositoryProvider.overrideWithValue(fakeRepo)],
    child: const MaterialApp(home: _SearchFilterTestWidget()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('All Expenses search and filter', () {
    late FakeExpenseRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeExpenseRepository();
    });

    testWidgets('search bar exists and can receive input', (tester) async {
      await tester.pumpWidget(_buildTestWidget(fakeRepo));
      await tester.pump();

      expect(find.byKey(const Key('search_bar')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search_bar')), 'Swiggy');
      expect(find.text('Swiggy'), findsOneWidget);
    });

    testWidgets('filter chips exist: Debit, Credit, SMS, Manual', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(fakeRepo));
      await tester.pump();

      expect(find.byKey(const Key('filter_chip_Debit')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_Credit')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_SMS')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_Manual')), findsOneWidget);
    });

    testWidgets('no-results widget shown when search yields empty', (
      tester,
    ) async {
      final expense = Expense()
        ..merchant = 'Swiggy'
        ..amount = 100
        ..transactionType = TransactionType.debit
        ..source = ExpenseSource.sms
        ..timestamp = DateTime.now()
        ..createdAt = DateTime.now()
        ..dedupeKey = 'test-key-1';
      fakeRepo.seedExpenses([expense]);

      await tester.pumpWidget(_buildTestWidget(fakeRepo));
      await tester.pump();

      // Enter a query that matches nothing
      await tester.enterText(
        find.byKey(const Key('search_bar')),
        'xyznonexistent',
      );
      // Trigger provider update (no debounce in test widget — direct state update)
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('no_results')), findsOneWidget);
    });
  });
}

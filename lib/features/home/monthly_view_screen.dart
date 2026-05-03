import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../expenses/widgets/expense_card.dart';

class MonthlyViewScreen extends ConsumerWidget {
  const MonthlyViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthlyExpensesAsync = ref.watch(monthlyExpensesProvider);
    final monthFormat = DateFormat('MMMM yyyy');
    final amountFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
      locale: 'en_IN',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected month',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          monthFormat.format(selectedMonth),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickMonth(context, ref, selectedMonth),
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: monthlyExpensesAsync.when(
              data: (expenses) {
                final total = _monthlyTotal(expenses);

                if (expenses.isEmpty) {
                  return Center(
                    child: Text(
                      'No expenses found for this month.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }

                return Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.pie_chart_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Total spent: ${amountFormat.format(total)}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: expenses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return ExpenseCard(expense: expenses[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Unable to load month data: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedMonth,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020, 1),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Choose Month',
    );

    if (picked == null) {
      return;
    }

    ref.read(selectedMonthProvider.notifier).state = DateTime(
      picked.year,
      picked.month,
    );
  }

  double _monthlyTotal(List<Expense> expenses) {
    return expenses
        .where((e) => e.transactionType == TransactionType.debit)
        .fold<double>(0, (sum, e) => sum + e.amount);
  }
}

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  monthFormat.format(selectedMonth),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickMonth(context, ref, selectedMonth),
                icon: const Icon(Icons.calendar_month),
                label: const Text('Select month'),
              ),
            ],
          ),
        ),
        Expanded(
          child: monthlyExpensesAsync.when(
            data: (expenses) {
              final total = _monthlyTotal(expenses);

              if (expenses.isEmpty) {
                return const Center(
                  child: Text('No expenses found for this month.'),
                );
              }

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                    child: Text(
                      'Total spent: ₹${total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        return ExpenseCard(expense: expenses[index]);
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Unable to load month data: $error')),
          ),
        ),
      ],
    );
  }

  Future<void> _pickMonth(BuildContext context, WidgetRef ref, DateTime selectedMonth) async {
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

    ref.read(selectedMonthProvider.notifier).state = DateTime(picked.year, picked.month);
  }

  double _monthlyTotal(List<Expense> expenses) {
    return expenses
        .where((e) => e.transactionType == TransactionType.debit)
        .fold<double>(0, (sum, e) => sum + e.amount);
  }
}

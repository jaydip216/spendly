import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/expense.dart';
import '../../../core/providers/providers.dart';

/// Bottom sheet with full transaction details and a category picker.
Future<void> showExpenseDetailSheet(BuildContext context, Expense expense) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ExpenseDetailSheet(expense: expense),
  );
}

class ExpenseDetailSheet extends ConsumerWidget {
  const ExpenseDetailSheet({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
      locale: 'en_IN',
    );
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final scheme = Theme.of(context).colorScheme;
    final isDebit = expense.transactionType == TransactionType.debit;
    final categoriesAsync = ref.watch(categoriesProvider);
    final currentCategory =
        expense.category.isEmpty ? 'Other' : expense.category;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    expense.merchant.isEmpty
                        ? 'Unknown merchant'
                        : expense.merchant,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  amountFormat.format(expense.amount),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDebit ? scheme.error : scheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(expense.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Text(
              'Category',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (categories) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in categories)
                    ChoiceChip(
                      key: Key('category_chip_${category.name}'),
                      label: Text(category.name),
                      selected: category.name == currentCategory,
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: Color(category.colorValue),
                      ),
                      onSelected: (selected) async {
                        if (!selected) return;
                        expense.category = category.name;
                        await ref
                            .read(expenseRepositoryProvider)
                            .saveExpense(expense);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                ],
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Failed to load categories: $error'),
            ),
            const SizedBox(height: 20),
            _DetailRow(label: 'Type', value: isDebit ? 'Debit' : 'Credit'),
            _DetailRow(
              label: 'Source',
              value: expense.source == ExpenseSource.sms ? 'SMS' : 'Manual',
            ),
            if (expense.sender.isNotEmpty)
              _DetailRow(label: 'Sender', value: expense.sender),
            if (expense.bankName != null)
              _DetailRow(label: 'Bank', value: expense.bankName!),
            if (expense.upiId != null)
              _DetailRow(label: 'UPI', value: expense.upiId!),
            if (expense.cardLastFour != null)
              _DetailRow(label: 'Card', value: '••••${expense.cardLastFour}'),
            if (expense.notes != null && expense.notes!.isNotEmpty)
              _DetailRow(label: 'Notes', value: expense.notes!),
            if (expense.rawSms.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Original SMS',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: scheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      expense.rawSms,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

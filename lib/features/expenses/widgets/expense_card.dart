import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/expense.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final amountFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
      locale: 'en_IN',
    );
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final isDebit = expense.transactionType == TransactionType.debit;
    final scheme = Theme.of(context).colorScheme;
    final merchant = expense.merchant.isEmpty
        ? 'Unknown merchant'
        : expense.merchant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  amountFormat.format(expense.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDebit ? scheme.error : scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${expense.sender} • ${dateFormat.format(expense.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TagChip(
                  label: isDebit ? 'DEBIT' : 'CREDIT',
                  foreground: isDebit
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer,
                  background: isDebit
                      ? scheme.errorContainer
                      : scheme.primaryContainer,
                ),
                if (expense.upiId != null)
                  _TagChip(
                    label: 'UPI ${expense.upiId}',
                    foreground: scheme.onSecondaryContainer,
                    background: scheme.secondaryContainer,
                  ),
                if (expense.cardLastFour != null)
                  _TagChip(
                    label: 'Card ••••${expense.cardLastFour}',
                    foreground: scheme.onSurface,
                    background: scheme.surfaceContainerHighest,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: background,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

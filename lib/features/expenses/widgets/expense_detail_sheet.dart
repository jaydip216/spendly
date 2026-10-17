import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/expense_presentation.dart';
import '../../../app/format.dart';
import '../../../app/theme/spendly_theme.dart';
import '../../../app/widgets/classical.dart';
import '../../../core/models/expense.dart';
import '../../../core/providers/providers.dart';

/// Full detail for one entry, with the text it was parsed from and a category
/// picker. Everything else the parser extracted is listed underneath, so it is
/// always possible to see why Spendly recorded what it did.
Future<void> showExpenseDetailSheet(BuildContext context, Expense expense) {
  return showClassicalSheet<void>(
    context: context,
    expand: true,
    builder: (context) => ExpenseDetailSheet(expense: expense),
  );
}

class ExpenseDetailSheet extends ConsumerWidget {
  const ExpenseDetailSheet({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final media = MediaQuery.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currentCategory = expense.displayCategory;
    final isDebit = expense.transactionType == TransactionType.debit;

    return SizedBox(
      height: media.size.height * 0.82,
      child: Column(
        children: [
          const Center(child: SheetHandle()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        expense.displayMerchant,
                        style: tokens.heading(
                          30,
                          height: 1.08,
                          letterSpacingEm: -0.02,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      rupeesWithSymbol(expense.amount, decimals: true),
                      style: tokens.figure(
                        26,
                        color: isDebit ? tokens.ink : tokens.accentDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${fullTimestamp.format(expense.timestamp)} · '
                  '${expense.paymentMethod}'
                  '${expense.accountLabel == null ? '' : ' · ${expense.accountLabel}'}',
                  style: tokens.body(12.5, color: tokens.muted(0.55)),
                ),
                const SizedBox(height: 22),

                if (expense.rawSms.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: tokens.ink.withValues(alpha: 0.03),
                      border: Border.all(color: tokens.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(
                          expense.sender.isEmpty
                              ? 'Original message'
                              : 'Original message · ${expense.sender}',
                        ),
                        const SizedBox(height: 7),
                        Text(
                          expense.rawSms,
                          style: tokens.body(
                            12.5,
                            color: tokens.muted(0.72),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                const SectionLabel('Category'),
                const SizedBox(height: 10),
                categoriesAsync.when(
                  loading: () => const SizedBox(
                    height: 34,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Text(
                    'Failed to load categories: $error',
                    style: tokens.body(12.5, color: tokens.danger),
                  ),
                  data: (categories) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in categories)
                        PillChip(
                          key: Key('category_chip_${category.name}'),
                          label: category.name,
                          swatch: Color(category.colorValue),
                          selected: category.name == currentCategory,
                          onTap: () async {
                            if (category.name == currentCategory) return;
                            expense.category = category.name;
                            await ref
                                .read(expenseRepositoryProvider)
                                .saveExpense(expense);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const SectionLabel('What Spendly read'),
                const SizedBox(height: 4),
                _DetailRow(
                  label: 'Direction',
                  value: isDebit ? 'Debit' : 'Credit',
                ),
                _DetailRow(
                  label: 'Source',
                  value: expense.source == ExpenseSource.sms
                      ? 'Read from SMS'
                      : 'Added by hand',
                ),
                if (expense.sender.isNotEmpty)
                  _DetailRow(label: 'Sender', value: expense.sender),
                if (expense.bankName != null)
                  _DetailRow(label: 'Bank', value: expense.bankName!),
                if (expense.upiId != null)
                  _DetailRow(label: 'UPI id', value: expense.upiId!),
                if (expense.cardLastFour != null)
                  _DetailRow(
                    label: 'Card',
                    value: '••••${expense.cardLastFour}',
                  ),
                if (expense.notes != null && expense.notes!.isNotEmpty)
                  _DetailRow(label: 'Note', value: expense.notes!),
                const SizedBox(height: 16),
                Text(
                  'Category changes stick — a re-scan never overwrites a field '
                  'you have set yourself.',
                  style: tokens.body(11.5, color: tokens.muted(0.48)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: tokens.body(12.5, color: tokens.muted(0.52), height: 1.35),
            ),
          ),
          Expanded(child: Text(value, style: tokens.body(13.5, height: 1.35))),
        ],
      ),
    );
  }
}

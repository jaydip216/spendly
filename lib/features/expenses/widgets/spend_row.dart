import 'package:flutter/material.dart';

import '../../../app/expense_presentation.dart';
import '../../../app/format.dart';
import '../../../app/theme/spendly_theme.dart';
import '../../../app/widgets/classical.dart';
import '../../../core/models/expense.dart';
import 'expense_detail_sheet.dart';

/// The comfortable spend row: circled initial, merchant over a grey detail
/// line, amount set in the serif with the payment method beneath. Separated by
/// a hairline rather than wrapped in a card.
class SpendRow extends StatelessWidget {
  const SpendRow({
    super.key,
    required this.expense,
    this.showMethod = true,
    this.subtitle,
    this.onTap,
  });

  final Expense expense;
  final bool showMethod;

  /// Overrides the default "Category · Account · Date" line.
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final isCredit = expense.transactionType == TransactionType.credit;

    return InkWell(
      onTap: onTap ?? () => showExpenseDetailSheet(context, expense),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.divider)),
        ),
        child: Row(
          children: [
            InitialAvatar(expense.initial),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expense.displayMerchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.body(14, height: 1.3),
                        ),
                      ),
                      if (isCredit) ...[
                        const SizedBox(width: 6),
                        Text('◆', style: tokens.body(10, color: tokens.accent)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? expense.subtitleLine(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.body(
                      11.5,
                      color: tokens.muted(0.52),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isCredit
                      ? '+${rupeesWithSymbol(expense.amount)}'
                      : rupeesWithSymbol(expense.amount),
                  style: tokens.figure(
                    16,
                    color: isCredit ? tokens.accentDeep : tokens.ink,
                  ),
                ),
                if (showMethod) ...[
                  const SizedBox(height: 1),
                  Text(
                    expense.paymentMethod,
                    style: tokens.body(
                      10.5,
                      color: tokens.muted(0.42),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

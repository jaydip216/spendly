import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/expense.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.expense,
  });

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final amountFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final isDebit = expense.transactionType == TransactionType.debit;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(
          expense.merchant.isEmpty ? 'Unknown merchant' : expense.merchant,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${expense.sender} • ${dateFormat.format(expense.timestamp)}'),
            if (expense.upiId != null) Text('UPI: ${expense.upiId}'),
            if (expense.cardLastFour != null) Text('Card: ****${expense.cardLastFour}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amountFormat.format(expense.amount),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDebit ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isDebit ? 'DEBIT' : 'CREDIT',
                style: TextStyle(
                  color: isDebit ? Colors.red.shade800 : Colors.green.shade800,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

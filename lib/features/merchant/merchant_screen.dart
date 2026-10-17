import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/expense_presentation.dart';
import '../../app/format.dart';
import '../../app/theme/spendly_theme.dart';
import '../../app/widgets/classical.dart';
import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../expenses/widgets/spend_row.dart';

/// Everything Spendly holds about one merchant, across all months.
class MerchantScreen extends ConsumerWidget {
  const MerchantScreen({super.key, required this.merchant});

  final String merchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final allAsync = ref.watch(allExpensesProvider);

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            EmptyState(title: 'Could not load spends', message: '$error'),
        data: (all) {
          final matches = all
              .where(
                (e) =>
                    (e.merchant.isEmpty ? 'Unknown' : e.merchant) == merchant,
              )
              .toList();
          final debits = matches
              .where((e) => e.transactionType == TransactionType.debit)
              .toList();

          if (matches.isEmpty) {
            return EmptyState(
              title: merchant,
              message: 'No spends recorded for this merchant any more.',
            );
          }

          final total = debits.fold<double>(0, (sum, e) => sum + e.amount);
          final average = debits.isEmpty ? 0.0 : total / debits.length;
          final categories = <String>{
            for (final expense in matches) expense.displayCategory,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            children: [
              Text(
                merchant,
                style: tokens.heading(36, height: 1.08, letterSpacingEm: -0.02),
              ),
              const SizedBox(height: 8),
              Text(
                '${matches.length} entr${matches.length == 1 ? 'y' : 'ies'} · '
                '${categories.join(', ')}',
                style: tokens.body(12.5, color: tokens.muted(0.55)),
              ),
              const SizedBox(height: 22),
              MetricStrip(
                metrics: [
                  (value: rupeesWithSymbol(total), label: 'All time'),
                  (value: rupeesWithSymbol(average), label: 'Average'),
                  (value: '${debits.length}', label: 'Spends'),
                ],
              ),
              const SizedBox(height: 22),
              const SectionLabel('Every spend here'),
              const SizedBox(height: 4),
              for (final expense in matches)
                SpendRow(
                  expense: expense,
                  subtitle:
                      '${fullTimestamp.format(expense.timestamp)}'
                      '${expense.accountLabel == null ? '' : ' · ${expense.accountLabel}'}',
                ),
            ],
          );
        },
      ),
    );
  }
}

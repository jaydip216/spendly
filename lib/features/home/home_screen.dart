import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/format.dart';
import '../../app/theme/spendly_theme.dart';
import '../../app/widgets/classical.dart';
import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../analytics/analytics_screen.dart' show groupByCategory;
import '../expenses/widgets/spend_row.dart';
import 'widgets/month_picker.dart';

/// The month, stated once and plainly: what went out, at what daily rate,
/// where it went, and the last few entries.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final monthlyAsync = ref.watch(monthlyExpensesProvider);
    final summaries = ref.watch(monthSummariesProvider).valueOrNull ?? const [];

    return TabPage(
      child: Column(
        children: [
          const _HomeHeader(),
          Expanded(
            child: monthlyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                title: 'Could not read this month',
                message: '$error',
              ),
              data: (expenses) {
                final debits = expenses
                    .where((e) => e.transactionType == TransactionType.debit)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  children: [
                    const MonthSwitcher(),
                    const Rule(),
                    if (debits.isEmpty)
                      _EmptyMonth(month: month, summaries: summaries)
                    else ...[
                      _MonthTotal(
                        debits: debits,
                        month: month,
                        summaries: summaries,
                      ),
                      const SizedBox(height: 24),
                      _MonthMetrics(debits: debits, month: month),
                      const SizedBox(height: 26),
                      SectionHeading(
                        'Where it went',
                        actionLabel: 'All insights',
                        onAction: () => context.go('/insights'),
                      ),
                      const SizedBox(height: 12),
                      _CategoryMeters(debits: debits),
                      const SizedBox(height: 28),
                      SectionHeading(
                        'Recent',
                        actionLabel: 'See all',
                        onAction: () => context.go('/spends'),
                      ),
                      const SizedBox(height: 4),
                      for (final expense in expenses.take(6))
                        SpendRow(expense: expense, showMethod: false),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final lastBackup = ref.watch(lastBackupProvider);
    final staleBackup =
        lastBackup == null || DateTime.now().difference(lastBackup).inDays > 7;

    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.only(left: 22, right: 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Spendly',
                style: tokens.heading(
                  21,
                  weight: FontWeight.w600,
                  letterSpacingEm: 0.01,
                ),
              ),
            ),
            IconAction(
              icon: Icons.add,
              tooltip: 'Add a spend by hand',
              onPressed: () => context.push('/manual-entry'),
            ),
            IconAction(
              icon: Icons.cloud_outlined,
              tooltip: staleBackup ? 'Backup is out of date' : 'Backup',
              showDot: staleBackup,
              onPressed: () => context.push('/backup'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ₹ set small and light, the figure set large — the one number the screen
/// exists for, with the month-on-month change stated in words underneath.
class _MonthTotal extends StatelessWidget {
  const _MonthTotal({
    required this.debits,
    required this.month,
    required this.summaries,
  });

  final List<Expense> debits;
  final DateTime month;
  final List<({DateTime month, double total, int count})> summaries;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final total = debits.fold<double>(0, (sum, e) => sum + e.amount);

    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        children: [
          Text('TOTAL SPENT', style: tokens.metricLabel(size: 11)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹',
                style: tokens.figure(
                  30,
                  color: tokens.muted(0.5),
                  letterSpacingEm: -0.03,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    rupees(total),
                    key: const Key('home_month_total'),
                    style: tokens.figure(60, height: 1, letterSpacingEm: -0.03),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _deltaSentence(total),
            textAlign: TextAlign.center,
            style: tokens.body(12.5, color: tokens.muted(0.6)),
          ),
        ],
      ),
    );
  }

  String _deltaSentence(double total) {
    final previousMonth = DateTime(month.year, month.month - 1);
    final previous = summaries
        .where(
          (s) =>
              s.month.year == previousMonth.year &&
              s.month.month == previousMonth.month,
        )
        .firstOrNull;

    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final tail = isCurrentMonth ? ' — only ${now.day} days in' : '';

    if (previous == null || previous.total == 0) {
      return isCurrentMonth
          ? '${now.day} days into the month'
          : 'Nothing recorded in ${monthShort.format(previousMonth)}';
    }

    final change = (total - previous.total) / previous.total * 100;
    final sign = change < 0 ? '−' : '+';
    return '$sign${change.abs().round()}% vs '
        '${monthShort.format(previousMonth)}$tail';
  }
}

class _MonthMetrics extends StatelessWidget {
  const _MonthMetrics({required this.debits, required this.month});

  final List<Expense> debits;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final total = debits.fold<double>(0, (sum, e) => sum + e.amount);
    final now = DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    final elapsed = isCurrentMonth ? now.day : daysInMonth;
    final perDay = elapsed == 0 ? 0.0 : total / elapsed;

    return MetricStrip(
      metrics: [
        (value: rupeesWithSymbol(perDay), label: 'Per day'),
        (
          value: isCurrentMonth ? '${daysInMonth - now.day}' : '$daysInMonth',
          label: isCurrentMonth ? 'Days left' : 'Days',
        ),
        (value: '${debits.length}', label: 'Spends'),
      ],
    );
  }
}

class _CategoryMeters extends StatelessWidget {
  const _CategoryMeters({required this.debits});

  final List<Expense> debits;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final totals = groupByCategory(debits);
    final grandTotal = totals.values.fold<double>(0, (sum, v) => sum + v);
    final top = totals.entries.take(5).toList();

    return Column(
      children: [
        for (var i = 0; i < top.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == top.length - 1 ? 0 : 13),
            child: MeterRow(
              label: top[i].key,
              value: rupeesWithSymbol(top[i].value),
              trailingNote: grandTotal == 0
                  ? null
                  : '${(top[i].value / grandTotal * 100).round()}%',
              fraction: grandTotal == 0 ? 0 : top[i].value / grandTotal,
              color: tokens.seriesAt(i),
            ),
          ),
      ],
    );
  }
}

/// Two flavours of nothing: a month with no entries, and an app with none at
/// all. They read very differently to someone who has just installed Spendly.
class _EmptyMonth extends ConsumerWidget {
  const _EmptyMonth({required this.month, required this.summaries});

  final DateTime month;
  final List<({DateTime month, double total, int count})> summaries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final nearest = summaries.firstOrNull;

    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyState(
          title: 'No spends yet',
          titleSize: 30,
          message:
              'Spendly builds your log from the texts your bank sends after '
              'each payment. Nothing here yet — add one by hand, or check that '
              'SMS access is on in Settings.',
          action: ClassicalButton(
            label: 'Add a spend manually',
            height: 44,
            onPressed: () => context.push('/manual-entry'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Text(
            '₹0',
            style: tokens.figure(
              64,
              color: tokens.ink.withValues(alpha: 0.18),
              height: 1,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Nothing recorded in ${monthShort.format(month)}',
            textAlign: TextAlign.center,
            style: tokens.heading(22),
          ),
          const SizedBox(height: 10),
          Text(
            'No bank texts from this month reached Spendly. Months your phone '
            'still had messages for are listed in the month picker.',
            textAlign: TextAlign.center,
            style: tokens.body(13.5, color: tokens.muted(0.58)),
          ),
          if (nearest != null) ...[
            const SizedBox(height: 18),
            ClassicalButton(
              label: 'Go to ${monthShortYear.format(nearest.month)}',
              variant: ClassicalButtonVariant.ghost,
              onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                  nearest.month,
            ),
          ],
        ],
      ),
    );
  }
}

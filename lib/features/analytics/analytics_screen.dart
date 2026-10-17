import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/expense_presentation.dart';
import '../../app/format.dart';
import '../../app/theme/spendly_theme.dart';
import '../../app/widgets/classical.dart';
import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../home/widgets/month_picker.dart';

// ── Pure aggregation helpers (unit tested) ───────────────────────────────────

/// Debit totals per category. Empty category is treated as 'Other'.
Map<String, double> groupByCategory(List<Expense> expenses) {
  final Map<String, double> totals = {};
  for (final expense in expenses) {
    if (expense.transactionType != TransactionType.debit) continue;
    final category = expense.category.isEmpty ? 'Other' : expense.category;
    totals[category] = (totals[category] ?? 0) + expense.amount;
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
}

/// Debit totals per day-of-month (1..daysInMonth), zero-filled.
Map<int, double> groupByDay(List<Expense> expenses, DateTime month) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final Map<int, double> totals = {
    for (var day = 1; day <= daysInMonth; day++) day: 0.0,
  };
  for (final expense in expenses) {
    if (expense.transactionType != TransactionType.debit) continue;
    if (expense.timestamp.year != month.year ||
        expense.timestamp.month != month.month) {
      continue;
    }
    final day = expense.timestamp.day;
    totals[day] = (totals[day] ?? 0) + expense.amount;
  }
  return totals;
}

/// Top debit merchants by total, descending.
List<MapEntry<String, double>> topMerchants(
  List<Expense> expenses, {
  int limit = 5,
}) {
  final Map<String, double> totals = {};
  for (final expense in expenses) {
    if (expense.transactionType != TransactionType.debit) continue;
    final merchant = expense.merchant.isEmpty ? 'Unknown' : expense.merchant;
    totals[merchant] = (totals[merchant] ?? 0) + expense.amount;
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(limit).toList();
}

/// Debit totals for the last 12 months, zero-filled.
Map<DateTime, double> groupByMonth(List<Expense> expenses) {
  final now = DateTime.now();
  final Map<DateTime, double> monthTotals = {
    for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i): 0.0,
  };

  for (final expense in expenses) {
    if (expense.transactionType != TransactionType.debit) continue;
    final expenseMonth = DateTime(
      expense.timestamp.year,
      expense.timestamp.month,
    );
    if (monthTotals.containsKey(expenseMonth)) {
      monthTotals[expenseMonth] =
          (monthTotals[expenseMonth] ?? 0) + expense.amount;
    }
  }

  return monthTotals;
}

/// Debit totals and counts per payment route (UPI / Card / Bank / Manual),
/// largest total first.
List<({String method, double total, int count})> groupByPaymentMethod(
  List<Expense> expenses,
) {
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final expense in expenses) {
    if (expense.transactionType != TransactionType.debit) continue;
    final method = expense.paymentMethod;
    totals[method] = (totals[method] ?? 0) + expense.amount;
    counts[method] = (counts[method] ?? 0) + 1;
  }
  final entries = [
    for (final entry in totals.entries)
      (method: entry.key, total: entry.value, count: counts[entry.key]!),
  ]..sort((a, b) => b.total.compareTo(a.total));
  return entries;
}

/// Debit totals per weekday, Monday (1) through Sunday (7), zero-filled.
Map<int, double> groupByWeekday(List<Expense> expenses) {
  final totals = <int, double>{for (var day = 1; day <= 7; day++) day: 0.0};
  for (final expense in expenses) {
    if (expense.transactionType != TransactionType.debit) continue;
    totals[expense.timestamp.weekday] =
        (totals[expense.timestamp.weekday] ?? 0) + expense.amount;
  }
  return totals;
}

// ── Screen ───────────────────────────────────────────────────────────────────

/// Everything the month adds up to: the trend it sits in, where it went, how
/// it was paid, which days carry it, and who took the most.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final monthlyAsync = ref.watch(monthlyExpensesProvider);
    final summaries = ref.watch(monthSummariesProvider).valueOrNull ?? const [];

    return TabPage(
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.only(left: 22, right: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Insights',
                      style: tokens.heading(21, weight: FontWeight.w600),
                    ),
                  ),
                  const MonthSwitcher(compact: true),
                ],
              ),
            ),
          ),
          Expanded(
            child: monthlyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                title: 'Could not build insights',
                message: '$error',
              ),
              data: (expenses) {
                final debits = expenses
                    .where((e) => e.transactionType == TransactionType.debit)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  children: [
                    const Rule(),
                    _TrendSection(summaries: summaries),
                    if (debits.isEmpty)
                      const EmptyState(
                        title: 'Nothing to break down',
                        message:
                            'Pick a month with spends in it and the rest of '
                            'this page fills in.',
                      )
                    else ...[
                      const _SectionRule(),
                      _CategorySection(debits: debits),
                      const _SectionRule(),
                      _PaymentSection(debits: debits),
                      const _SectionRule(),
                      _WeekdaySection(debits: debits),
                      const _SectionRule(),
                      _TopMerchantsSection(debits: debits),
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

class _SectionRule extends StatelessWidget {
  const _SectionRule();

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(vertical: 22), child: Rule());
}

/// Five months side by side. Tapping a bar switches the whole page to it.
class _TrendSection extends ConsumerWidget {
  const _TrendSection({required this.summaries});

  final List<({DateTime month, double total, int count})> summaries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final selected = ref.watch(selectedMonthProvider);

    // Newest on the right, capped at five columns.
    final recent = summaries.take(5).toList().reversed.toList();
    if (recent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Text(
          'No months recorded yet.',
          style: tokens.body(13, color: tokens.muted(0.55)),
        ),
      );
    }

    final maxTotal = recent.map((m) => m.total).reduce((a, b) => a > b ? a : b);
    final average =
        recent.fold<double>(0, (sum, m) => sum + m.total) / recent.length;
    final selectedTotal = summaries
        .where(
          (m) =>
              m.month.year == selected.year && m.month.month == selected.month,
        )
        .fold<double>(0, (sum, m) => sum + m.total);

    final String headline;
    if (recent.length == 1) {
      headline = 'The only month Spendly has on file';
    } else if (selectedTotal == 0) {
      headline = 'Nothing recorded this month';
    } else if (selectedTotal < average) {
      headline = 'Below your ${rupeesWithSymbol(average)} average';
    } else {
      headline = 'Above your ${rupeesWithSymbol(average)} average';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 22),
          child: SectionLabel('Across the months'),
        ),
        const SizedBox(height: 5),
        Text(headline, style: tokens.heading(20)),
        const SizedBox(height: 12),
        SizedBox(
          height: 138,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in recent)
                Expanded(
                  child: _TrendBar(
                    entry: entry,
                    maxTotal: maxTotal,
                    selected:
                        entry.month.year == selected.year &&
                        entry.month.month == selected.month,
                    onTap: () =>
                        ref.read(selectedMonthProvider.notifier).state =
                            entry.month,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.entry,
    required this.maxTotal,
    required this.selected,
    required this.onTap,
  });

  final ({DateTime month, double total, int count}) entry;
  final double maxTotal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final ratio = maxTotal == 0 ? 0.0 : entry.total / maxTotal;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              rupeesShort(entry.total),
              style: tokens.body(
                10.5,
                color: selected ? tokens.accentDeep : tokens.muted(0.55),
                height: 1.2,
                tabular: true,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: (96 * ratio).clamp(2.0, 96.0),
              decoration: BoxDecoration(
                color: selected ? tokens.accentSoft : Colors.transparent,
                border: Border.all(
                  color: selected ? tokens.accent : tokens.divider,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              monthShort.format(entry.month).toUpperCase(),
              style: tokens.body(
                11,
                color: selected ? tokens.accentDeep : tokens.muted(0.55),
                height: 1.2,
                letterSpacingEm: 0.06,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.debits});

  final List<Expense> debits;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final totals = groupByCategory(debits);
    final grandTotal = totals.values.fold<double>(0, (sum, v) => sum + v);
    final entries = totals.entries.take(6).toList();
    final top = entries.first;

    return Row(
      children: [
        DonutChart(
          slices: [
            for (var i = 0; i < entries.length; i++)
              (
                fraction: grandTotal == 0 ? 0.0 : entries[i].value / grandTotal,
                color: tokens.seriesAt(i),
              ),
          ],
          centerTop: grandTotal == 0
              ? '0%'
              : '${(top.value / grandTotal * 100).round()}%',
          centerBottom: top.key,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('By category'),
              const SizedBox(height: 9),
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.5),
                  child: Row(
                    children: [
                      Container(width: 9, height: 9, color: tokens.seriesAt(i)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entries[i].key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.body(12.5, height: 1.3),
                        ),
                      ),
                      Text(
                        grandTotal == 0
                            ? '0%'
                            : '${(entries[i].value / grandTotal * 100).round()}%',
                        style: tokens.body(
                          12.5,
                          color: tokens.muted(0.6),
                          height: 1.3,
                          tabular: true,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.debits});

  final List<Expense> debits;

  @override
  Widget build(BuildContext context) {
    final methods = groupByPaymentMethod(debits);
    final maxTotal = methods.isEmpty
        ? 0.0
        : methods.map((m) => m.total).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('How you paid'),
        const SizedBox(height: 14),
        for (final method in methods)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: MeterRow(
              label: method.method,
              labelNote: '${method.count} spend${method.count == 1 ? '' : 's'}',
              value: rupeesWithSymbol(method.total),
              fraction: maxTotal == 0 ? 0 : method.total / maxTotal,
            ),
          ),
      ],
    );
  }
}

class _WeekdaySection extends StatelessWidget {
  const _WeekdaySection({required this.debits});

  final List<Expense> debits;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final totals = groupByWeekday(debits);
    final maxTotal = totals.values.fold<double>(0, (a, b) => a > b ? a : b);
    final grandTotal = totals.values.fold<double>(0, (a, b) => a + b);
    final weekend = (totals[6] ?? 0) + (totals[7] ?? 0);
    final weekendShare = grandTotal == 0 ? 0 : (weekend / grandTotal * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Weekday vs weekend'),
        const SizedBox(height: 6),
        Text(
          weekendShare >= 40
              ? 'Weekends carry ${weekendShare.round()}% of the month'
              : 'Only ${weekendShare.round()}% of it lands at the weekend',
          style: tokens.heading(20),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height:
                              (maxTotal == 0
                                      ? 0.0
                                      : (totals[day] ?? 0) / maxTotal * 68)
                                  .clamp(2.0, 68.0),
                          decoration: BoxDecoration(
                            color: day >= 6
                                ? tokens.accentSoft
                                : Colors.transparent,
                            border: Border.all(color: tokens.accentStrong),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _labels[day - 1],
                          style: tokens.body(
                            10.5,
                            color: tokens.muted(0.55),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopMerchantsSection extends StatelessWidget {
  const _TopMerchantsSection({required this.debits});

  final List<Expense> debits;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final entries = topMerchants(debits);
    final counts = <String, int>{};
    for (final expense in debits) {
      final merchant = expense.merchant.isEmpty ? 'Unknown' : expense.merchant;
      counts[merchant] = (counts[merchant] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Top merchants'),
        const SizedBox(height: 12),
        for (var i = 0; i < entries.length; i++)
          InkWell(
            onTap: () => context.push('/merchant', extra: entries[i].key),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.divider)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${i + 1}',
                      style: tokens.figure(13, color: tokens.accent),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entries[i].key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.body(13.5, height: 1.3),
                    ),
                  ),
                  Text(
                    '×${counts[entries[i].key] ?? 0}',
                    style: tokens.body(
                      11,
                      color: tokens.muted(0.45),
                      height: 1.3,
                      tabular: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    rupeesWithSymbol(entries[i].value),
                    style: tokens.figure(15),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

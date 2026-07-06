import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/category.dart' as models;
import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';

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
    for (var i = 0; i < 12; i++)
      DateTime(now.year, now.month - i): 0.0,
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

// ── Screen ───────────────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthlyAsync = ref.watch(monthlyExpensesProvider);
    final allAsync = ref.watch(allExpensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: monthlyAsync.when(
        data: (monthExpenses) {
          final categoryColors = <String, Color>{
            for (final category
                in categoriesAsync.asData?.value ?? const <models.Category>[])
              category.name: Color(category.colorValue),
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _MonthHeader(selectedMonth: selectedMonth),
              const SizedBox(height: 12),
              _MonthSummaryRow(
                expenses: monthExpenses,
                month: selectedMonth,
              ),
              const SizedBox(height: 20),
              if (monthExpenses
                  .where((e) => e.transactionType == TransactionType.debit)
                  .isEmpty)
                const _EmptyMonthCard()
              else ...[
                _SectionTitle('Spend by category'),
                const SizedBox(height: 12),
                _CategoryBreakdown(
                  totals: groupByCategory(monthExpenses),
                  categoryColors: categoryColors,
                ),
                const SizedBox(height: 24),
                _SectionTitle('Daily spend'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: _DailySpendChart(
                    totals: groupByDay(monthExpenses, selectedMonth),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionTitle('Top merchants'),
                const SizedBox(height: 8),
                _TopMerchantsList(entries: topMerchants(monthExpenses)),
              ],
              const SizedBox(height: 24),
              _SectionTitle('Last 12 months'),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: allAsync.when(
                  data: (all) => _MonthlyTrendChart(totals: groupByMonth(all)),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Error: $error'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _MonthHeader extends ConsumerWidget {
  const _MonthHeader({required this.selectedMonth});

  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final isCurrentMonth = !selectedMonth.isBefore(currentMonth);

    void shiftMonth(int delta) {
      ref.read(selectedMonthProvider.notifier).state = DateTime(
        selectedMonth.year,
        selectedMonth.month + delta,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              key: const Key('analytics_prev_month'),
              tooltip: 'Previous month',
              onPressed: () => shiftMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(selectedMonth),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              key: const Key('analytics_next_month'),
              tooltip: 'Next month',
              onPressed: isCurrentMonth ? null : () => shiftMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSummaryRow extends StatelessWidget {
  const _MonthSummaryRow({required this.expenses, required this.month});

  final List<Expense> expenses;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final debits = expenses
        .where((e) => e.transactionType == TransactionType.debit)
        .toList();
    final total = debits.fold<double>(0, (sum, e) => sum + e.amount);

    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final elapsedDays = isCurrentMonth
        ? now.day
        : DateTime(month.year, month.month + 1, 0).day;
    final avgPerDay = elapsedDays == 0 ? 0.0 : total / elapsedDays;

    final amountFormat = NumberFormat.compactCurrency(
      symbol: '₹',
      locale: 'en_IN',
    );

    Widget metric(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        metric('Spent', amountFormat.format(total)),
        const SizedBox(width: 10),
        metric('Transactions', '${debits.length}'),
        const SizedBox(width: 10),
        metric('Avg / day', amountFormat.format(avgPerDay)),
      ],
    );
  }
}

class _EmptyMonthCard extends StatelessWidget {
  const _EmptyMonthCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No spending recorded this month.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

const _fallbackPalette = <Color>[
  Color(0xFF1565C0),
  Color(0xFFEF6C00),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFFC62828),
  Color(0xFF00838F),
  Color(0xFFAD1457),
  Color(0xFF9E9E9E),
];

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.totals,
    required this.categoryColors,
  });

  final Map<String, double> totals;
  final Map<String, Color> categoryColors;

  Color _colorFor(String category, int index) {
    return categoryColors[category] ??
        _fallbackPalette[index % _fallbackPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = totals.values.fold<double>(0, (sum, v) => sum + v);
    final amountFormat = NumberFormat.compactCurrency(
      symbol: '₹',
      locale: 'en_IN',
    );
    final entries = totals.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 55,
                      sectionsSpace: 2,
                      sections: [
                        for (var i = 0; i < entries.length; i++)
                          PieChartSectionData(
                            value: entries[i].value,
                            color: _colorFor(entries[i].key, i),
                            radius: 32,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        amountFormat.format(grandTotal),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorFor(entries[i].key, i),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entries[i].key,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      amountFormat.format(entries[i].value),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: Text(
                        grandTotal == 0
                            ? '0%'
                            : '${(entries[i].value / grandTotal * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailySpendChart extends StatelessWidget {
  const _DailySpendChart({required this.totals});

  final Map<int, double> totals;

  @override
  Widget build(BuildContext context) {
    final days = totals.keys.toList()..sort();
    double maxY = 0;
    for (final amount in totals.values) {
      if (amount > maxY) maxY = amount;
    }
    if (maxY == 0) maxY = 100;

    final primary = Theme.of(context).colorScheme.primary;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                // Label every 5th day to avoid clutter.
                if (day == 1 || day % 5 == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('$day', style: const TextStyle(fontSize: 9)),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (final day in days)
            BarChartGroupData(
              x: day,
              barRods: [
                BarChartRodData(
                  toY: totals[day] ?? 0,
                  color: primary,
                  width: 5,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(2)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TopMerchantsList extends StatelessWidget {
  const _TopMerchantsList({required this.entries});

  final List<MapEntry<String, double>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final amountFormat = NumberFormat.compactCurrency(
      symbol: '₹',
      locale: 'en_IN',
    );
    final maxAmount = entries.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${i + 1}.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entries[i].key,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          amountFormat.format(entries[i].value),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxAmount == 0
                            ? 0
                            : entries[i].value / maxAmount,
                        minHeight: 5,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({required this.totals});

  final Map<DateTime, double> totals;

  @override
  Widget build(BuildContext context) {
    final sortedMonths = totals.keys.toList()..sort();

    double maxY = 0;
    for (final amount in totals.values) {
      if (amount > maxY) maxY = amount;
    }
    if (maxY == 0) maxY = 100;

    final primary = Theme.of(context).colorScheme.primary;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedMonths.length) {
                  final date = sortedMonths[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MMM').format(date),
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < sortedMonths.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: totals[sortedMonths[i]] ?? 0,
                  color: primary,
                  width: 14,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

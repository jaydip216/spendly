import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/providers/providers.dart';

Map<String, double> groupByMerchant(List<Expense> expenses) {
  final debitExpenses = expenses.where((e) => e.transactionType == TransactionType.debit);
  final Map<String, double> merchantTotals = {};

  for (final expense in debitExpenses) {
    final merchant = expense.merchant.isEmpty ? 'Unknown' : expense.merchant;
    merchantTotals[merchant] = (merchantTotals[merchant] ?? 0) + expense.amount;
  }

  final sortedEntries = merchantTotals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  if (sortedEntries.length <= 5) {
    return Map.fromEntries(sortedEntries);
  }

  final top5 = sortedEntries.take(5);
  final others = sortedEntries.skip(5);
  
  final othersTotal = others.fold(0.0, (sum, entry) => sum + entry.value);
  
  final result = Map.fromEntries(top5);
  result['Others'] = othersTotal;
  
  return result;
}

Map<DateTime, double> groupByMonth(List<Expense> expenses) {
  final debitExpenses = expenses.where((e) => e.transactionType == TransactionType.debit);
  
  final now = DateTime.now();
  final Map<DateTime, double> monthTotals = {};
  
  // Initialize last 12 months with 0.0
  for (int i = 0; i < 12; i++) {
    final month = DateTime(now.year, now.month - i);
    monthTotals[DateTime(month.year, month.month)] = 0.0;
  }

  for (final expense in debitExpenses) {
    final expenseMonth = DateTime(expense.timestamp.year, expense.timestamp.month);
    if (monthTotals.containsKey(expenseMonth)) {
      monthTotals[expenseMonth] = (monthTotals[expenseMonth] ?? 0) + expense.amount;
    }
  }

  return monthTotals;
}

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(allExpensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(child: Text('No data to display'));
          }

          final merchantData = groupByMerchant(expenses);
          final monthlyData = groupByMonth(expenses);
          
          final hasDebitExpenses = merchantData.isNotEmpty;
          
          if (!hasDebitExpenses) {
             return const Center(child: Text('No data to display'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Top Expenses by Merchant',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: _buildPieChart(merchantData),
              ),
              const SizedBox(height: 32),
              const Text(
                'Monthly Spend (Last 12 Months)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: _buildBarChart(monthlyData),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> merchantData) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.grey,
    ];

    int colorIndex = 0;
    final sections = merchantData.entries.map((entry) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        value: entry.value,
        title: entry.key,
        color: color,
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 0,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildBarChart(Map<DateTime, double> monthlyData) {
    final sortedMonths = monthlyData.keys.toList()..sort();
    
    double maxY = 0;
    for (final amount in monthlyData.values) {
      if (amount > maxY) maxY = amount;
    }
    
    if (maxY == 0) maxY = 100; // Default max to avoid empty chart

    final barGroups = List.generate(sortedMonths.length, (index) {
      final date = sortedMonths[index];
      final amount = monthlyData[date] ?? 0;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: amount,
            color: Colors.blue,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index >= 0 && index < sortedMonths.length) {
                  final date = sortedMonths[index];
                  // Simple month label, e.g. 1 for Jan
                  final text = '${date.month}/${date.year.toString().substring(2)}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(text, style: const TextStyle(fontSize: 10)),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }
}

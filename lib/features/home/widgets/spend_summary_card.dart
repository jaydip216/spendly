import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';

/// Total-spent summary. Defaults to the current month; the calendar button
/// lets the user pick a custom date range, and the reset chip returns to the
/// month view.
class SpendSummaryCard extends ConsumerWidget {
  const SpendSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(totalSpentProvider);
    final range = ref.watch(spendRangeProvider);

    final amountFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
      locale: 'en_IN',
    );

    final rangeLabel = range == null
        ? DateFormat('MMMM yyyy').format(DateTime.now())
        : '${DateFormat('d MMM').format(range.start)} – '
            '${DateFormat('d MMM yyyy').format(range.end)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          rangeLabel,
                          key: const Key('spend_summary_range_label'),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (range != null)
                  IconButton(
                    key: const Key('spend_summary_reset'),
                    tooltip: 'Back to current month',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        ref.read(spendRangeProvider.notifier).state = null,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  ),
                IconButton(
                  key: const Key('spend_summary_pick_range'),
                  tooltip: 'Choose date range',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _pickRange(context, ref, range),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            totalsAsync.when(
              data: (totals) => Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Total spent',
                      value: amountFormat.format(totals.total),
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: 'Transactions',
                      value: '${totals.count}',
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('Failed to load totals: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    DateTimeRange? current,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1),
      lastDate: now,
      initialDateRange: current,
      helpText: 'Total spent for range',
    );
    if (picked != null) {
      ref.read(spendRangeProvider.notifier).state = picked;
    }
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/format.dart';
import '../../../app/theme/spendly_theme.dart';
import '../../../app/widgets/classical.dart';
import '../../../core/providers/providers.dart';

/// ‹ AUGUST 2026 ⌄ › — the month control that opens both Home and Insights.
/// Tapping the label opens the sheet of months Spendly actually has data for.
class MonthSwitcher extends ConsumerWidget {
  const MonthSwitcher({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final selected = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final atCurrentMonth = !selected.isBefore(DateTime(now.year, now.month));

    void shift(int delta) {
      ref.read(selectedMonthProvider.notifier).state = DateTime(
        selected.year,
        selected.month + delta,
      );
    }

    final label = InkWell(
      key: const Key('month_label'),
      onTap: () => showMonthSheet(context),
      borderRadius: BorderRadius.circular(4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                monthYear.format(selected).toUpperCase(),
                style: tokens.body(12, height: 1.2, letterSpacingEm: 0.14),
              ),
              const SizedBox(width: 7),
              Icon(Icons.expand_more_rounded, size: 15, color: tokens.ink),
            ],
          ),
        ),
      ),
    );

    if (compact) return label;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconAction(
          key: const Key('prev_month'),
          icon: Icons.chevron_left_rounded,
          size: 28,
          iconSize: 20,
          tooltip: 'Previous month',
          onPressed: () => shift(-1),
        ),
        label,
        IconAction(
          key: const Key('next_month'),
          icon: Icons.chevron_right_rounded,
          size: 28,
          iconSize: 20,
          tooltip: 'Next month',
          color: atCurrentMonth ? tokens.muted(0.25) : null,
          onPressed: atCurrentMonth ? null : () => shift(1),
        ),
      ],
    );
  }
}

Future<void> showMonthSheet(BuildContext context) {
  return showClassicalSheet<void>(
    context: context,
    builder: (context) => const _MonthSheet(),
  );
}

class _MonthSheet extends ConsumerWidget {
  const _MonthSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final selected = ref.watch(selectedMonthProvider);
    final summaries = ref.watch(monthSummariesProvider).valueOrNull ?? const [];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SheetHandle()),
            Text('Jump to a month', style: tokens.heading(21)),
            const SizedBox(height: 4),
            Text(
              'Spendly keeps every month it has found messages for.',
              style: tokens.body(12, color: tokens.muted(0.55)),
            ),
            const SizedBox(height: 14),
            if (summaries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No months recorded yet.',
                  style: tokens.body(13, color: tokens.muted(0.55)),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: summaries.length,
                  itemBuilder: (context, index) {
                    final entry = summaries[index];
                    final isSelected =
                        entry.month.year == selected.year &&
                        entry.month.month == selected.month;
                    return InkWell(
                      onTap: () {
                        ref.read(selectedMonthProvider.notifier).state =
                            entry.month;
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: tokens.divider),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? tokens.accent
                                    : tokens.muted(0.2),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                monthYear.format(entry.month),
                                style: tokens.body(14.5, height: 1.3),
                              ),
                            ),
                            Text(
                              '${entry.count} spend${entry.count == 1 ? '' : 's'}',
                              style: tokens.body(
                                11,
                                color: tokens.muted(0.45),
                                height: 1.3,
                                tabular: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              rupeesWithSymbol(entry.total),
                              style: tokens.figure(16),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

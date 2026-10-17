import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/format.dart';
import '../../../app/theme/spendly_theme.dart';
import '../../../app/widgets/classical.dart';
import '../../../core/models/expense.dart';
import '../../../core/providers/providers.dart';

Future<void> showFilterSheet(BuildContext context) {
  return showClassicalSheet<void>(
    context: context,
    expand: true,
    builder: (context) => const _FilterSheet(),
  );
}

const _minAmountChoices = <double>[500, 1000, 5000];

/// Every filter the stored data can honestly support: month, direction,
/// how the entry got in, category, and a floor on the amount.
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final media = MediaQuery.of(context);
    final months = ref.watch(monthSummariesProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final results = ref.watch(filteredExpensesProvider).valueOrNull ?? const [];

    final dateRange = ref.watch(filterDateRangeProvider);
    final type = ref.watch(filterTransactionTypeProvider);
    final source = ref.watch(filterSourceProvider);
    final category = ref.watch(filterCategoryProvider);
    final minAmount = ref.watch(filterMinAmountProvider);

    final resultTotal = results
        .where((e) => e.transactionType == TransactionType.debit)
        .fold<double>(0, (sum, e) => sum + e.amount);

    return SizedBox(
      height: media.size.height * 0.86,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
            child: Column(
              children: [
                const Center(child: SheetHandle()),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text('Filter spends', style: tokens.heading(21)),
                    ),
                    ClassicalButton(
                      label: 'Reset',
                      variant: ClassicalButtonVariant.ghost,
                      fontSize: 11.5,
                      onPressed: () => clearSpendFilters(ref),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              children: [
                _FilterGroup(
                  label: 'Month',
                  children: [
                    PillChip(
                      label: 'Any month',
                      selected: dateRange == null,
                      onTap: () =>
                          ref.read(filterDateRangeProvider.notifier).state =
                              null,
                    ),
                    for (final entry in months.take(12))
                      PillChip(
                        label: monthShortYear.format(entry.month),
                        selected: _isMonth(dateRange, entry.month),
                        onTap: () =>
                            ref
                                .read(filterDateRangeProvider.notifier)
                                .state = DateTimeRange(
                              start: entry.month,
                              end: DateTime(
                                entry.month.year,
                                entry.month.month + 1,
                                0,
                              ),
                            ),
                      ),
                  ],
                ),
                _FilterGroup(
                  label: 'Direction',
                  children: [
                    PillChip(
                      label: 'Both',
                      selected: type == null,
                      onTap: () =>
                          ref
                                  .read(filterTransactionTypeProvider.notifier)
                                  .state =
                              null,
                    ),
                    PillChip(
                      label: 'Debits',
                      selected: type == TransactionType.debit,
                      onTap: () =>
                          ref
                                  .read(filterTransactionTypeProvider.notifier)
                                  .state =
                              TransactionType.debit,
                    ),
                    PillChip(
                      label: 'Credits',
                      selected: type == TransactionType.credit,
                      onTap: () =>
                          ref
                                  .read(filterTransactionTypeProvider.notifier)
                                  .state =
                              TransactionType.credit,
                    ),
                  ],
                ),
                _FilterGroup(
                  label: 'How it got here',
                  children: [
                    PillChip(
                      label: 'Any way',
                      selected: source == null,
                      onTap: () =>
                          ref.read(filterSourceProvider.notifier).state = null,
                    ),
                    PillChip(
                      label: 'Read from SMS',
                      selected: source == ExpenseSource.sms,
                      onTap: () =>
                          ref.read(filterSourceProvider.notifier).state =
                              ExpenseSource.sms,
                    ),
                    PillChip(
                      label: 'Added by hand',
                      selected: source == ExpenseSource.manual,
                      onTap: () =>
                          ref.read(filterSourceProvider.notifier).state =
                              ExpenseSource.manual,
                    ),
                  ],
                ),
                _FilterGroup(
                  label: 'Category',
                  children: [
                    PillChip(
                      label: 'All categories',
                      selected: category == null,
                      onTap: () =>
                          ref.read(filterCategoryProvider.notifier).state =
                              null,
                    ),
                    for (final item in categories)
                      PillChip(
                        label: item.name,
                        swatch: Color(item.colorValue),
                        selected: category == item.name,
                        onTap: () =>
                            ref.read(filterCategoryProvider.notifier).state =
                                item.name,
                      ),
                  ],
                ),
                _FilterGroup(
                  label: 'Amount at least',
                  children: [
                    PillChip(
                      label: 'Any amount',
                      selected: minAmount == null,
                      onTap: () =>
                          ref.read(filterMinAmountProvider.notifier).state =
                              null,
                    ),
                    for (final floor in _minAmountChoices)
                      PillChip(
                        label: '${rupeesWithSymbol(floor)}+',
                        selected: minAmount == floor,
                        onTap: () =>
                            ref.read(filterMinAmountProvider.notifier).state =
                                floor,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(22, 14, 22, 22 + media.padding.bottom),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.divider)),
            ),
            child: ClassicalButton(
              label:
                  'Show ${results.length} spend${results.length == 1 ? '' : 's'} · '
                  '${rupeesWithSymbol(resultTotal)}',
              height: 46,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  bool _isMonth(DateTimeRange? range, DateTime month) {
    if (range == null) return false;
    return range.start.year == month.year && range.start.month == month.month;
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

/// Resets search and every filter at once — used by the sheet's Reset and by
/// the "nothing matches" state.
void clearSpendFilters(WidgetRef ref) {
  ref.read(searchQueryProvider.notifier).state = '';
  ref.read(filterTransactionTypeProvider.notifier).state = null;
  ref.read(filterSourceProvider.notifier).state = null;
  ref.read(filterCategoryProvider.notifier).state = null;
  ref.read(filterMinAmountProvider.notifier).state = null;
  ref.read(filterMaxAmountProvider.notifier).state = null;
  ref.read(filterDateRangeProvider.notifier).state = null;
}

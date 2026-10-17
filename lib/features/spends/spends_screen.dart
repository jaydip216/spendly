import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/format.dart';
import '../../app/theme/spendly_theme.dart';
import '../../app/widgets/classical.dart';
import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../expenses/widgets/spend_row.dart';
import 'widgets/filter_sheet.dart';

/// Every entry Spendly holds, grouped by day, with search and filters.
class SpendsScreen extends ConsumerStatefulWidget {
  const SpendsScreen({super.key});

  @override
  ConsumerState<SpendsScreen> createState() => _SpendsScreenState();
}

class _SpendsScreenState extends ConsumerState<SpendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _searchOpen = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen) {
      _debounce?.cancel();
      _searchController.clear();
      ref.read(searchQueryProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final isFiltering = ref.watch(isFilteringProvider);
    final activeFilters = ref.watch(activeFilterCountProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final selectedCategory = ref.watch(filterCategoryProvider);

    final expensesAsync = isFiltering
        ? ref.watch(filteredExpensesProvider)
        : ref.watch(allExpensesProvider);

    return TabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.only(left: 22, right: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'All spends',
                      style: tokens.heading(21, weight: FontWeight.w600),
                    ),
                  ),
                  IconAction(
                    key: const Key('toggle_search'),
                    icon: _searchOpen ? Icons.close_rounded : Icons.search,
                    tooltip: 'Search merchants',
                    onPressed: _toggleSearch,
                  ),
                  IconAction(
                    key: const Key('open_filters'),
                    icon: Icons.filter_alt_outlined,
                    tooltip: 'Filter spends',
                    showDot: activeFilters > 0,
                    onPressed: () => showFilterSheet(context),
                  ),
                  IconAction(
                    icon: Icons.add,
                    tooltip: 'Add a spend by hand',
                    onPressed: () => context.push('/manual-entry'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Column(
              children: [
                if (_searchOpen) ...[
                  TextField(
                    key: const Key('search_bar'),
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    style: tokens.body(14),
                    decoration: const InputDecoration(
                      hintText: 'Search merchant or note',
                    ),
                  ),
                  const SizedBox(height: 11),
                ],
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      PillChip(
                        label: 'All',
                        selected: selectedCategory == null,
                        onTap: () =>
                            ref.read(filterCategoryProvider.notifier).state =
                                null,
                      ),
                      for (final category in categories) ...[
                        const SizedBox(width: 7),
                        PillChip(
                          label: category.name,
                          swatch: Color(category.colorValue),
                          selected: selectedCategory == category.name,
                          onTap: () =>
                              ref
                                  .read(filterCategoryProvider.notifier)
                                  .state = selectedCategory == category.name
                              ? null
                              : category.name,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  EmptyState(title: 'Could not load spends', message: '$error'),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return isFiltering
                      ? EmptyState(
                          key: const Key('no_results'),
                          title: 'Nothing matches',
                          message:
                              'Loosen a filter or clear the search to see '
                              'your spends again.',
                          action: ClassicalButton(
                            label: 'Clear filters',
                            onPressed: () {
                              _searchController.clear();
                              clearSpendFilters(ref);
                            },
                          ),
                        )
                      : const EmptyState(
                          title: 'No spends yet',
                          message:
                              'Spendly writes an entry here for every bank '
                              'text it can read.',
                        );
                }

                final debitTotal = expenses
                    .where((e) => e.transactionType == TransactionType.debit)
                    .fold<double>(0, (sum, e) => sum + e.amount);
                final groups = _groupByDay(expenses);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${expenses.length} spend'
                              '${expenses.length == 1 ? '' : 's'}'
                              '${isFiltering ? ' · filtered' : ''}',
                              style: tokens.body(
                                11.5,
                                color: tokens.muted(0.55),
                              ),
                            ),
                          ),
                          Text(
                            rupeesWithSymbol(debitTotal),
                            style: tokens.body(
                              11.5,
                              color: tokens.muted(0.55),
                              tabular: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(0, 10, 0, 7),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: tokens.divider),
                                  ),
                                ),
                                child: Text(
                                  dayHeading(group.day).toUpperCase(),
                                  style: tokens.kicker(),
                                ),
                              ),
                              for (final expense in group.items)
                                SpendRow(expense: expense),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<({DateTime day, List<Expense> items})> _groupByDay(
    List<Expense> expenses,
  ) {
    final sorted = [...expenses]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final groups = <({DateTime day, List<Expense> items})>[];
    for (final expense in sorted) {
      final day = DateTime(
        expense.timestamp.year,
        expense.timestamp.month,
        expense.timestamp.day,
      );
      if (groups.isNotEmpty && groups.last.day == day) {
        groups.last.items.add(expense);
      } else {
        groups.add((day: day, items: [expense]));
      }
    }
    return groups;
  }
}

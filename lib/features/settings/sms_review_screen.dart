import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/format.dart';
import '../../app/theme/spendly_theme.dart';
import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';
import '../../services/parser/transaction_parser.dart';

/// Recheck saved SMS without changing the user's history automatically.
class SmsReviewScreen extends ConsumerStatefulWidget {
  const SmsReviewScreen({super.key});

  @override
  ConsumerState<SmsReviewScreen> createState() => _SmsReviewScreenState();
}

class _SmsReviewScreenState extends ConsumerState<SmsReviewScreen> {
  final _selected = <int>{};
  bool _saving = false;

  Future<void> _remove(List<Expense> entries) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${entries.length} selected entries?'),
        content: const Text(
          'This removes only the selected entries from Spendly. Your inbox '
          'messages stay on your phone. Export a backup first if you want '
          'to keep a copy of these entries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove entries'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final removed = await ref
          .read(expenseRepositoryProvider)
          .removeReviewedSms(entries);
      if (!mounted) return;
      setState(_selected.clear);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$removed entries removed.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove entries. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final parser = TransactionParser();
    return Scaffold(
      appBar: AppBar(title: const Text('Review SMS entries')),
      body: ref
          .watch(allExpensesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('Could not load saved entries.')),
            data: (expenses) {
              final candidates = expenses
                  .where(
                    (entry) =>
                        entry.source == ExpenseSource.sms &&
                        entry.rawSms.trim().isNotEmpty &&
                        parser.parse(
                              sender: entry.sender,
                              body: entry.rawSms,
                              timestamp: entry.timestamp,
                            ) ==
                            null,
                  )
                  .toList();
              final selected = candidates
                  .where((entry) => _selected.contains(entry.id))
                  .toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(
                      'These saved messages no longer qualify as completed expenses. '
                      'They may be OTPs, credits or other non-spending alerts. '
                      'Read each message before selecting it for removal.',
                      style: tokens.body(14),
                    ),
                  ),
                  Expanded(
                    child: candidates.isEmpty
                        ? const Center(
                            child: Text('No suspicious SMS entries found.'),
                          )
                        : ListView.builder(
                            itemCount: candidates.length,
                            itemBuilder: (context, index) {
                              final entry = candidates[index];
                              return ExpansionTile(
                                leading: Checkbox(
                                  value: _selected.contains(entry.id),
                                  onChanged: _saving
                                      ? null
                                      : (value) => setState(() {
                                          if (value == true) {
                                            _selected.add(entry.id);
                                          } else {
                                            _selected.remove(entry.id);
                                          }
                                        }),
                                ),
                                title: Text(
                                  entry.merchant,
                                  style: tokens.body(14),
                                ),
                                subtitle: Text(
                                  '${rupeesWithSymbol(entry.amount, decimals: true)} · ${entry.sender} · ${dayMonthYear.format(entry.timestamp)}',
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: SelectableText(
                                      entry.rawSms,
                                      style: tokens.body(13),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton(
                        onPressed: _saving || selected.isEmpty
                            ? null
                            : () => _remove(selected),
                        child: Text(
                          _saving
                              ? 'Removing…'
                              : 'Remove ${selected.length} selected entries',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

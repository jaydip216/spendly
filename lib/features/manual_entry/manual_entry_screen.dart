import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/format.dart';
import '../../app/theme/spendly_theme.dart';
import '../../app/widgets/classical.dart';
import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';

/// For cash, and for anything the bank did not text about.
class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TransactionType _transactionType = TransactionType.debit;
  String _selectedCategory = 'Other';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final expense = Expense()
      ..amount = double.parse(_amountController.text.trim())
      ..merchant = _merchantController.text.trim()
      ..timestamp = _selectedDate
      ..transactionType = _transactionType
      ..source = ExpenseSource.manual
      ..category = _selectedCategory
      ..notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim()
      ..dedupeKey = 'manual_${DateTime.now().millisecondsSinceEpoch}'
      ..createdAt = DateTime.now();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.saveExpense(expense);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Expense saved successfully')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this expense. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final names = categories.map((c) => c.name).toList();
    if (names.isNotEmpty && !names.contains(_selectedCategory)) {
      _selectedCategory = names.contains('Other') ? 'Other' : names.first;
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Add a spend'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                children: [
                  _Field(
                    label: 'Amount (₹)',
                    child: TextFormField(
                      key: const Key('amount_field'),
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: tokens.figure(26),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Amount is required';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid amount greater than 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  _Field(
                    label: 'Merchant',
                    child: TextFormField(
                      key: const Key('merchant_field'),
                      controller: _merchantController,
                      textCapitalization: TextCapitalization.words,
                      style: tokens.body(14),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Merchant is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  _Field(
                    label: 'Date',
                    child: InkWell(
                      key: const Key('date_picker'),
                      onTap: _pickDate,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: tokens.divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                dayMonthYear.format(_selectedDate),
                                style: tokens.body(14),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: tokens.muted(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _Field(
                    label: 'Direction',
                    child: Wrap(
                      spacing: 8,
                      children: [
                        PillChip(
                          key: const Key('type_chip_debit'),
                          label: 'Money out',
                          selected: _transactionType == TransactionType.debit,
                          onTap: () => setState(
                            () => _transactionType = TransactionType.debit,
                          ),
                        ),
                        PillChip(
                          key: const Key('type_chip_credit'),
                          label: 'Money in',
                          selected: _transactionType == TransactionType.credit,
                          onTap: () => setState(
                            () => _transactionType = TransactionType.credit,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Field(
                    label: 'Category',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in categories)
                          PillChip(
                            key: Key('manual_category_${category.name}'),
                            label: category.name,
                            swatch: Color(category.colorValue),
                            selected: _selectedCategory == category.name,
                            onTap: () => setState(
                              () => _selectedCategory = category.name,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _Field(
                    label: 'Note (optional)',
                    child: TextFormField(
                      key: const Key('notes_field'),
                      controller: _notesController,
                      maxLines: 3,
                      style: tokens.body(14),
                      decoration: const InputDecoration(
                        hintText: 'What was this for?',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.divider)),
              ),
              child: SafeArea(
                top: false,
                child: ClassicalButton(
                  key: const Key('submit_button'),
                  label: 'Save Expense',
                  height: 46,
                  expand: true,
                  busy: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tokens.body(12, color: tokens.muted(0.7), height: 1.3),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';

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
      ..notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim()
      ..dedupeKey =
          'manual_${DateTime.now().millisecondsSinceEpoch}'
      ..createdAt = DateTime.now();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.saveExpense(expense);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved successfully')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd MMM yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amount
              TextFormField(
                key: const Key('amount_field'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 16),

              // Merchant
              TextFormField(
                key: const Key('merchant_field'),
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Merchant is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                key: const Key('date_picker'),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(dateLabel),
                ),
              ),
              const SizedBox(height: 16),

              // Transaction type
              Row(
                children: [
                  const Text('Type: '),
                  const SizedBox(width: 8),
                  ToggleButtons(
                    key: const Key('transaction_type_toggle'),
                    isSelected: [
                      _transactionType == TransactionType.debit,
                      _transactionType == TransactionType.credit,
                    ],
                    onPressed: (index) {
                      setState(() {
                        _transactionType = index == 0
                            ? TransactionType.debit
                            : TransactionType.credit;
                      });
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Debit'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Credit'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes (optional)
              TextFormField(
                key: const Key('notes_field'),
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Submit
              ElevatedButton(
                key: const Key('submit_button'),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

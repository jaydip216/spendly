import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/format.dart';
import '../../app/theme/spendly_theme.dart';
import '../../app/widgets/classical.dart';
import '../../core/models/category.dart';
import '../../core/models/expense.dart';
import '../../core/providers/providers.dart';

/// Warm, low-chroma swatches so the charts stay in the same family as the
/// rest of the system rather than turning into a paint chart.
const _colorChoices = <int>[
  0xFFB68235, // gold
  0xFFA06F24, // deep gold
  0xFF7D5411, // bronze
  0xFFB39A72, // sand
  0xFF8A8177, // stone
  0xFF6D675F, // slate
  0xFF4E342E, // umber
  0xFF37474F, // ink blue
  0xFF5A6B5D, // sage
  0xFF8D2F22, // rust
];

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = SpendlyTokens.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final expenses =
        ref.watch(allExpensesProvider).valueOrNull ?? const <Expense>[];

    final spendByCategory = <String, double>{};
    for (final expense in expenses) {
      if (expense.transactionType != TransactionType.debit) continue;
      final name = expense.category.isEmpty ? 'Other' : expense.category;
      spendByCategory[name] = (spendByCategory[name] ?? 0) + expense.amount;
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Categories'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ClassicalButton(
              key: const Key('add_category_button'),
              label: 'Add',
              variant: ClassicalButtonVariant.ghost,
              fontSize: 12,
              onPressed: () => _showCategoryDialog(context, ref),
            ),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            EmptyState(title: 'Could not load categories', message: '$error'),
        data: (categories) => ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          children: [
            Text(
              'Spendly guesses a category from the merchant name. Rename one, '
              'or move a spend, and every past and future entry follows.',
              style: tokens.body(12.5, color: tokens.muted(0.58)),
            ),
            const SizedBox(height: 18),
            for (final category in categories)
              InkWell(
                onTap: () =>
                    _showCategoryDialog(context, ref, existing: category),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: tokens.divider)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        color: Color(category.colorValue),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: tokens.body(14, height: 1.3),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              category.isDefault
                                  ? 'Built in · auto-assigned from merchant '
                                        'keywords'
                                  : 'Yours · rename, recolour or remove',
                              style: tokens.body(
                                11.5,
                                color: tokens.muted(0.5),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        rupeesWithSymbol(spendByCategory[category.name] ?? 0),
                        style: tokens.figure(15),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: tokens.muted(0.35),
                      ),
                    ],
                  ),
                ),
              ),
            const Rule(),
            const SizedBox(height: 18),
            Text(
              'Deleting a category moves its spends to Other; it never deletes '
              'spends.',
              style: tokens.body(11.5, color: tokens.muted(0.45)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final tokens = SpendlyTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text(
          'Its spends move to Other. Nothing is removed from your log.',
        ),
        actions: [
          ClassicalButton(
            label: 'Keep it',
            variant: ClassicalButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ClassicalButton(
            label: 'Delete',
            foreground: tokens.danger,
            borderColor: tokens.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(categoryRepositoryProvider).delete(category.id);
    }
  }

  Future<void> _showCategoryDialog(
    BuildContext screenContext,
    WidgetRef ref, {
    Category? existing,
  }) async {
    final tokens = SpendlyTokens.of(screenContext);
    final nameController = TextEditingController(text: existing?.name ?? '');
    int selectedColor = existing?.colorValue ?? _colorChoices.first;
    String? nameError;
    final canRename = existing == null || !existing.isDefault;

    final action = await showDialog<String>(
      context: screenContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            existing == null
                ? 'New category'
                : canRename
                ? 'Edit category'
                : existing.name,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canRename) ...[
                Text(
                  'Name',
                  style: tokens.body(12, color: tokens.muted(0.7), height: 1.3),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('category_name_field'),
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: tokens.body(14),
                  decoration: InputDecoration(errorText: nameError),
                  onChanged: (_) {
                    if (nameError != null) setState(() => nameError = null);
                  },
                ),
                const SizedBox(height: 18),
              ],
              Text(
                'Colour',
                style: tokens.body(12, color: tokens.muted(0.7), height: 1.3),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in _colorChoices)
                    InkResponse(
                      onTap: () => setState(() => selectedColor = color),
                      radius: 24,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Color(color),
                              border: Border.all(
                                color: selectedColor == color
                                    ? tokens.ink
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: selectedColor == color
                                ? const Icon(
                                    Icons.check,
                                    size: 15,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (existing != null && !existing.isDefault) ...[
                const SizedBox(height: 20),
                ClassicalButton(
                  label: 'Delete this category',
                  variant: ClassicalButtonVariant.secondary,
                  foreground: tokens.danger,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop('delete'),
                ),
              ],
            ],
          ),
          actions: [
            ClassicalButton(
              label: 'Cancel',
              variant: ClassicalButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            ClassicalButton(
              key: const Key('save_category_button'),
              label: 'Save',
              onPressed: () {
                if (canRename && nameController.text.trim().isEmpty) {
                  setState(() => nameError = 'Enter a category name');
                  return;
                }
                Navigator.of(context).pop('save');
              },
            ),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();

    if (action == 'delete' && existing != null) {
      if (!screenContext.mounted) return;
      await _confirmDelete(screenContext, ref, existing);
      return;
    }
    if (action != 'save') return;

    final repo = ref.read(categoryRepositoryProvider);

    if (existing == null) {
      await repo.put(
        Category()
          ..name = name
          ..colorValue = selectedColor,
      );
      return;
    }

    if (canRename && name.isNotEmpty && name != existing.name) {
      await repo.rename(existing.id, name);
      existing.name = name; // keep local copy in sync for the put below
    }
    if (selectedColor != existing.colorValue) {
      existing.colorValue = selectedColor;
      await repo.put(existing);
    }
  }
}

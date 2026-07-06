import 'package:isar/isar.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../../services/categorization/category_rules.dart';

class CategoryRepository {
  CategoryRepository(this._isar);

  final Isar _isar;

  Stream<List<Category>> watchAll() {
    return _isar.categorys.where().sortByName().watch(fireImmediately: true);
  }

  Future<List<Category>> getAll() {
    return _isar.categorys.where().sortByName().findAll();
  }

  Future<void> put(Category category) async {
    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
    });
  }

  /// Deletes a category and reassigns its expenses to 'Other' atomically.
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      final category = await _isar.categorys.get(id);
      if (category == null) return;

      final orphans = await _isar.expenses
          .filter()
          .categoryEqualTo(category.name)
          .findAll();
      for (final expense in orphans) {
        expense.category = CategoryRules.fallbackCategory;
      }
      await _isar.expenses.putAll(orphans);
      await _isar.categorys.delete(id);
    });
  }

  /// Renames a category and rewrites its expenses atomically.
  Future<void> rename(int id, String newName) async {
    await _isar.writeTxn(() async {
      final category = await _isar.categorys.get(id);
      if (category == null) return;

      final expenses = await _isar.expenses
          .filter()
          .categoryEqualTo(category.name)
          .findAll();
      for (final expense in expenses) {
        expense.category = newName;
      }
      await _isar.expenses.putAll(expenses);

      category.name = newName;
      await _isar.categorys.put(category);
    });
  }

  /// Inserts any default categories that are missing. Idempotent.
  Future<void> seedDefaults() async {
    await _isar.writeTxn(() async {
      for (final def in CategoryRules.defaultCategories) {
        final existing = await _isar.categorys
            .filter()
            .nameEqualTo(def.name, caseSensitive: false)
            .findFirst();
        if (existing == null) {
          await _isar.categorys.put(
            Category()
              ..name = def.name
              ..colorValue = def.colorValue
              ..isDefault = true,
          );
        }
      }
    });
  }
}

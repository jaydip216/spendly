import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:spendly/core/models/category.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/core/repositories/category_repository.dart';
import 'package:spendly/core/repositories/expense_repository.dart';
import 'package:spendly/services/categorization/category_rules.dart';

void main() {
  late Isar isar;
  late CategoryRepository repo;
  late ExpenseRepository expenseRepo;

  setUp(() async {
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [ExpenseSchema, CategorySchema],
      directory: '',
      name: 'category_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = CategoryRepository(isar);
    expenseRepo = ExpenseRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Expense makeExpense(String merchant, String category) {
    return Expense()
      ..merchant = merchant
      ..amount = 100
      ..category = category
      ..dedupeKey = 'key_${DateTime.now().microsecondsSinceEpoch}';
  }

  group('seedDefaults', () {
    test('inserts all default categories', () async {
      await repo.seedDefaults();
      final all = await repo.getAll();
      expect(all.length, CategoryRules.defaultCategories.length);
      expect(all.every((c) => c.isDefault), isTrue);
    });

    test('is idempotent', () async {
      await repo.seedDefaults();
      await repo.seedDefaults();
      final all = await repo.getAll();
      expect(all.length, CategoryRules.defaultCategories.length);
    });

    test('does not recreate a deleted-then-reseeded custom variant', () async {
      await repo.seedDefaults();
      // user-created category shouldn't affect seeding
      await repo.put(Category()..name = 'Travel');
      await repo.seedDefaults();
      final all = await repo.getAll();
      expect(all.length, CategoryRules.defaultCategories.length + 1);
    });
  });

  group('delete', () {
    test('reassigns expenses of deleted category to Other', () async {
      await repo.seedDefaults();
      final travel = Category()..name = 'Travel';
      await repo.put(travel);
      await expenseRepo.saveExpense(makeExpense('Airline', 'Travel'));
      await expenseRepo.saveExpense(makeExpense('Swiggy', 'Food'));

      await repo.delete(travel.id);

      final expenses = await expenseRepo.getAllExpenses();
      final airline = expenses.firstWhere((e) => e.merchant == 'Airline');
      expect(airline.category, 'Other');
      final swiggy = expenses.firstWhere((e) => e.merchant == 'Swiggy');
      expect(swiggy.category, 'Food');

      final categories = await repo.getAll();
      expect(categories.any((c) => c.name == 'Travel'), isFalse);
    });
  });

  group('rename', () {
    test('rewrites matching expenses', () async {
      final snacks = Category()..name = 'Snacks';
      await repo.put(snacks);
      await expenseRepo.saveExpense(makeExpense('Chips Corner', 'Snacks'));

      await repo.rename(snacks.id, 'Munchies');

      final expenses = await expenseRepo.getAllExpenses();
      expect(expenses.first.category, 'Munchies');
      final categories = await repo.getAll();
      expect(categories.any((c) => c.name == 'Munchies'), isTrue);
      expect(categories.any((c) => c.name == 'Snacks'), isFalse);
    });
  });
}

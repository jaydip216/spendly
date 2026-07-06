import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/services/categorization/category_rules.dart';

void main() {
  group('CategoryRules.categorize', () {
    test('matches merchant keywords', () {
      expect(CategoryRules.categorize(merchant: 'Swiggy Instamart'),
          'Groceries');
      expect(CategoryRules.categorize(merchant: 'ZOMATO'), 'Food');
      expect(CategoryRules.categorize(merchant: 'Uber India'), 'Transport');
      expect(CategoryRules.categorize(merchant: 'AMAZON PAY'), 'Shopping');
      expect(CategoryRules.categorize(merchant: 'Netflix'), 'Entertainment');
      expect(CategoryRules.categorize(merchant: 'Apollo Pharmacy'), 'Health');
    });

    test('merchant match is case-insensitive', () {
      expect(CategoryRules.categorize(merchant: 'fLiPkArT'), 'Shopping');
    });

    test('falls back to UPI handle when merchant unknown', () {
      expect(
        CategoryRules.categorize(
          merchant: 'Unknown merchant',
          upiId: 'bigbasket@hdfcbank',
        ),
        'Groceries',
      );
    });

    test('falls back to raw text when merchant and UPI unknown', () {
      expect(
        CategoryRules.categorize(
          merchant: 'XX1234',
          rawText: 'Rs 500 paid towards electricity bill via UPI',
        ),
        'Bills & Utilities',
      );
    });

    test('returns Other when nothing matches', () {
      expect(
        CategoryRules.categorize(merchant: 'Some Random Shop'),
        'Other',
      );
    });

    test('default categories include Other and are unique', () {
      final names =
          CategoryRules.defaultCategories.map((c) => c.name).toList();
      expect(names, contains('Other'));
      expect(names.toSet().length, names.length);
    });
  });
}

/// Pure keyword-based categorization. Static so it works from the SMS
/// background isolate (no Riverpod) and is trivially testable.
class CategoryRules {
  CategoryRules._();

  static const String fallbackCategory = 'Other';

  /// Default categories seeded on first launch. Single source of truth for
  /// both seeding and auto-categorization targets.
  static const List<({String name, int colorValue})> defaultCategories = [
    (name: 'Food', colorValue: 0xFFEF6C00), // orange
    (name: 'Groceries', colorValue: 0xFF2E7D32), // green
    (name: 'Transport', colorValue: 0xFF1565C0), // blue
    (name: 'Shopping', colorValue: 0xFF6A1B9A), // purple
    (name: 'Bills & Utilities', colorValue: 0xFF00838F), // cyan
    (name: 'Entertainment', colorValue: 0xFFC62828), // red
    (name: 'Health', colorValue: 0xFFAD1457), // pink
    (name: 'Other', colorValue: 0xFF9E9E9E), // grey
  ];

  /// Merchant/UPI keyword rules, checked in order. All lowercase.
  static const Map<String, List<String>> _keywordRules = {
    'Groceries': [
      'blinkit',
      'zepto',
      'bigbasket',
      'instamart',
      'grofers',
      'dmart',
      'grocery',
      'kirana',
      'supermarket',
      'reliance fresh',
      'more retail',
    ],
    'Food': [
      'swiggy',
      'zomato',
      'dominos',
      'mcdonald',
      'kfc',
      'pizza',
      'burger',
      'eatsure',
      'restaurant',
      'cafe',
      'biryani',
      'dhaba',
      'bakery',
    ],
    'Transport': [
      'uber',
      'ola',
      'rapido',
      'irctc',
      'redbus',
      'metro',
      'fuel',
      'petrol',
      'diesel',
      'hpcl',
      'iocl',
      'bpcl',
      'indian oil',
      'bharat petroleum',
      'fastag',
      'parking',
    ],
    'Shopping': [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'meesho',
      'nykaa',
      'croma',
      'decathlon',
      'lifestyle',
      'westside',
    ],
    'Bills & Utilities': [
      'electricity',
      'bescom',
      'mseb',
      'jio',
      'airtel',
      'vodafone',
      ' vi ',
      'bsnl',
      'broadband',
      'dth',
      'recharge',
      'gas',
      'water bill',
      'postpaid',
      'tata power',
    ],
    'Entertainment': [
      'netflix',
      'hotstar',
      'prime video',
      'spotify',
      'bookmyshow',
      'youtube',
      'sony liv',
      'zee5',
      'gaming',
      'playstation',
    ],
    'Health': [
      'pharmacy',
      'apollo',
      'pharmeasy',
      '1mg',
      'netmeds',
      'medplus',
      'hospital',
      'clinic',
      'diagnostic',
      'medical',
    ],
  };

  /// Picks a category for a transaction. Checks the merchant first, then the
  /// UPI handle, then the raw SMS text. Returns [fallbackCategory] when
  /// nothing matches.
  static String categorize({
    required String merchant,
    String? upiId,
    String? rawText,
  }) {
    final haystacks = <String>[
      merchant.toLowerCase(),
      if (upiId != null) upiId.toLowerCase(),
      if (rawText != null) rawText.toLowerCase(),
    ];

    for (final haystack in haystacks) {
      if (haystack.isEmpty) continue;
      for (final entry in _keywordRules.entries) {
        for (final keyword in entry.value) {
          if (haystack.contains(keyword)) {
            return entry.key;
          }
        }
      }
    }
    return fallbackCategory;
  }
}

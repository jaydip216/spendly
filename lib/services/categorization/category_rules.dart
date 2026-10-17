/// Pure keyword-based categorization. Static so it works from the SMS
/// background isolate (no Riverpod) and is trivially testable.
class CategoryRules {
  CategoryRules._();

  static const String fallbackCategory = 'Other';

  /// Default categories seeded on first launch. Single source of truth for
  /// both seeding and auto-categorization targets. The colours are the warm,
  /// low-chroma swatches the Classical theme uses everywhere else.
  static const List<({String name, int colorValue})> defaultCategories = [
    (name: 'Food', colorValue: 0xFFB68235), // gold
    (name: 'Groceries', colorValue: 0xFF5A6B5D), // sage
    (name: 'Transport', colorValue: 0xFF37474F), // ink blue
    (name: 'Shopping', colorValue: 0xFF7D5411), // bronze
    (name: 'Bills & Utilities', colorValue: 0xFF6D675F), // slate
    (name: 'Entertainment', colorValue: 0xFF8D2F22), // rust
    (name: 'Health', colorValue: 0xFF4E342E), // umber
    (name: 'Other', colorValue: 0xFF8A8177), // stone
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

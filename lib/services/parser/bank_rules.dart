class BankRules {
  static final Map<String, RegExp> senderToBank = {
    'SBI': RegExp(r'SBI|SBIINB|SBIPSG|SBIUPI', caseSensitive: false),
    'HDFC': RegExp(r'HDFC|HDFCBK|HDFCBN', caseSensitive: false),
    'ICICI': RegExp(r'ICICI|ICICIB', caseSensitive: false),
    'AXIS': RegExp(r'AXIS|AXISBK', caseSensitive: false),
    'KOTAK': RegExp(r'KOTAK|KKBK', caseSensitive: false),
    'YES': RegExp(r'YESBNK|YESBANK', caseSensitive: false),
    'FEDERAL': RegExp(r'FEDBNK|FEDERAL', caseSensitive: false),
    'IDFC': RegExp(r'IDFC|IDFCFB', caseSensitive: false),
    'PAYTM': RegExp(r'PAYTM', caseSensitive: false),
    'PHONEPE': RegExp(r'PHONEPE|PHNPAY', caseSensitive: false),
    'GPay': RegExp(r'GPAY|GOOGLEPAY', caseSensitive: false),
  };

  static final List<String> debitKeywords = [
    'debited',
    'spent',
    'paid',
    'purchase',
    'dr',
  ];

  static final List<String> creditKeywords = [
    'credited',
    'received',
    'refund',
    'cr',
  ];

  static final List<RegExp> nonExpensePatterns = [
    RegExp(
      r'\bestatement\b|\be-statement\b|\bstatement\b',
      caseSensitive: false,
    ),
    RegExp(r'\botp\b|\bone[ -]?time\s+password\b', caseSensitive: false),
    RegExp(
      r'\bupi\b.*\bcollect\s+request\b|\bcollect\s+request\b',
      caseSensitive: false,
    ),
  ];
}

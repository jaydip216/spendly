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
    'withdrawn',
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
    RegExp(
      r'\bo[\s.-]*t[\s.-]*p\b|\botp(?=\d)|'
      r'\bone[\s-]*time[\s-]*(?:password|passcode|code|pin)\b|'
      r'\b(?:verification|authentication|authorization|authorisation|security)\s+(?:code|password|pin)\b',
      caseSensitive: false,
    ),
    // Requests, failed attempts and reversals do not confirm a new spend.
    RegExp(
      r'\b(?:failed|declined|unsuccessful|reversed|refunded|refund|reversal)\b|'
      r'\b(?:will|would|shall)\s+be\s+debited\b|'
      r'\b(?:not|never)\s+(?:been\s+)?debited\b|'
      r'\b(?:to\s+authorize|to\s+authorise|pending\s+approval)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\bupi\b.*\bcollect\s+request\b|\bcollect\s+request\b',
      caseSensitive: false,
    ),
    // Promotional / marketing messages. Deliberately excludes "cashback" and
    // "reward" since genuine debit confirmations often mention them.
    RegExp(
      r'%\s*off\b|\boff\s+up\s?to\b|\bflat\s+(?:INR|Rs\.?|₹)|\bdiscount\b|\boffer(?:s)?\b|\bcoupon\b|\bpromo\s*code\b|\bvoucher\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\bwin\b|\bcongratulations?\b|\blucky\s+draw\b',
      caseSensitive: false,
    ),
    // Dues / reminders — money not spent yet.
    RegExp(
      r'\bemi\s+(?:due|reminder)\b|\bis\s+due\b|\bpayment\s+due\b|\bmin(?:imum)?\s+(?:amount\s+)?due\b|\bdue\s+on\b',
      caseSensitive: false,
    ),
    // Loan / credit-line solicitations.
    RegExp(
      r'\bapply\s+now\b|\bpre-?approved\b|\bloan\s+offer\b|\bavail\s+(?:a\s+)?loan\b|\beligible\s+for\b',
      caseSensitive: false,
    ),
  ];
}

import 'bank_rules.dart';
import 'parsed_transaction.dart';
import '../../core/models/expense.dart';

class TransactionParser {
  static final RegExp _amountRegex = RegExp(
    r'(?:INR|Rs\.?|MRP|Amt|Amount|₹)\s*[:.-]?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _upiRegex = RegExp(
    r'([a-zA-Z0-9._\-]{2,})@([a-zA-Z]{2,})',
    caseSensitive: false,
  );

  static final RegExp _cardRegex = RegExp(
    r'(?:card(?:\s+ending\s+with)?|ending\s+with|a\/c|ac|account|xx|x{2,})[^0-9]{0,12}(\d{4})',
    caseSensitive: false,
  );

  static final RegExp _merchantRegex = RegExp(
    r'(?:at|to|from|for|in favor of|towards)\s+([A-Za-z0-9 .&\-_]{3,40}?)(?=\s+(?:on|via|using|by|from|to|ref|txn|trxn|transaction|upi)\b|[.,]|$)',
    caseSensitive: false,
  );

  ParsedTransaction? parse({
    required String sender,
    required String body,
    required DateTime timestamp,
  }) {
    final String normalized = body.replaceAll('\n', ' ').trim();
    if (_isNonExpenseMessage(normalized)) {
      return null;
    }

    final amount = _parseAmount(normalized);
    if (amount == null || amount <= 0) {
      return null;
    }

    final transactionType = _classify(normalized);
    if (transactionType != TransactionType.debit) {
      return null;
    }

    final upiId = _parseUpi(normalized);
    final cardLastFour = _parseCardLastFour(normalized);
    final merchant = _parseMerchant(normalized);
    final bankName = _parseBankName(sender, normalized);

    return ParsedTransaction(
      amount: amount,
      sender: sender,
      timestamp: timestamp,
      transactionType: TransactionType.debit,
      merchant: merchant,
      upiId: upiId,
      cardLastFour: cardLastFour,
      bankName: bankName,
    );
  }

  double? _parseAmount(String message) {
    final match = _amountRegex.firstMatch(message);
    if (match == null) {
      return null;
    }
    final raw = (match.group(1) ?? '').replaceAll(',', '');
    return double.tryParse(raw);
  }

  String? _parseUpi(String message) {
    final match = _upiRegex.firstMatch(message);
    if (match == null) {
      return null;
    }
    return '${match.group(1)}@${match.group(2)}';
  }

  String? _parseCardLastFour(String message) {
    final match = _cardRegex.firstMatch(message);
    return match?.group(1);
  }

  String? _parseMerchant(String message) {
    final match = _merchantRegex.firstMatch(message);
    if (match == null) {
      return null;
    }
    var candidate = (match.group(1) ?? '').trim();
    candidate = candidate
        .replaceFirst(RegExp(r'^(your|the|a)\s+', caseSensitive: false), '')
        .trim();
    if (candidate.length < 3) {
      return null;
    }
    return candidate;
  }

  String? _parseBankName(String sender, String message) {
    for (final entry in BankRules.senderToBank.entries) {
      if (entry.value.hasMatch(sender) || entry.value.hasMatch(message)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Balance clauses like "Avl Bal Rs 5000 CR" contain "cr"/"dr" markers that
  /// would otherwise pollute classification of the actual transaction.
  static final RegExp _balanceClauseRegex = RegExp(
    r'\b(?:avl|available|avbl|total|closing)\.?\s*bal(?:ance)?\b[^.]*',
    caseSensitive: false,
  );

  TransactionType? _classify(String message) {
    final text = message.replaceAll(_balanceClauseRegex, ' ').toLowerCase();

    // Debit keywords take priority: a genuine debit SMS may also mention a
    // credit ("debited ... credited to beneficiary"), but not vice versa.
    for (final keyword in BankRules.debitKeywords) {
      final pattern = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
      if (pattern.hasMatch(text)) {
        return TransactionType.debit;
      }
    }

    for (final keyword in BankRules.creditKeywords) {
      final pattern = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
      if (pattern.hasMatch(text)) {
        return TransactionType.credit;
      }
    }

    // No explicit keyword: ambiguous message (often promotional), drop it
    // rather than guess.
    return null;
  }

  bool _isNonExpenseMessage(String message) {
    for (final pattern in BankRules.nonExpensePatterns) {
      if (pattern.hasMatch(message)) {
        return true;
      }
    }

    return false;
  }
}

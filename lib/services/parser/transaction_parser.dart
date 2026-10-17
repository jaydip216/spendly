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
    final String normalized = body
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

  /// Remove only the balance value, including decimal amounts and CR/DR.
  /// A transaction can follow a balance on the same line.
  static final RegExp _balanceClauseRegex = RegExp(
    r'\b(?:(?:avl|available|avbl|total|closing)\.?\s*)?bal(?:ance)?'
    r'\b\s*[:=-]?\s*(?:INR|Rs\.?|₹)?\s*[0-9,]+(?:\.[0-9]+)?\s*(?:CR|DR)?\b',
    caseSensitive: false,
  );

  static final RegExp _creditEvent = RegExp(
    r'\b(?:' + BankRules.creditKeywords.map(RegExp.escape).join('|') + r')\b',
    caseSensitive: false,
  );

  static final RegExp _debitEvent = RegExp(
    r'\b(?:' + BankRules.debitKeywords.map(RegExp.escape).join('|') + r')\b',
    caseSensitive: false,
  );

  // "Sent" alone also occurs in OTP and credit notifications. Require an
  // amount immediately before it, or "sent <amount>" followed by a recipient.
  static final RegExp _moneySent = RegExp(
    r'(?:INR|Rs\.?|₹)\s*[0-9,]+(?:\.[0-9]+)?\s+(?:has\s+been\s+)?sent\s+(?:from|to)\b|'
    r'\bsent\s+(?:INR|Rs\.?|₹)\s*[0-9,]+(?:\.[0-9]+)?\s+to\b',
    caseSensitive: false,
  );

  static final RegExp _processedCardPurchase = RegExp(
    r'\btransaction\s+of\b.*\bcard\b.*\bat\b.*\b(?:processed|successful|completed)\b',
    caseSensitive: false,
  );

  TransactionType? _classify(String message) {
    final text = message.replaceAll(_balanceClauseRegex, ' ');
    final debit = _debitEvent.firstMatch(text);
    final credit = _creditEvent.firstMatch(text);

    if (credit != null) {
      // Accept the common outgoing-transfer confirmation only when the debit
      // comes first and the credit explicitly belongs to the beneficiary.
      final beneficiaryCredit = RegExp(
        r'\bcredited\s+to\s+(?:the\s+)?beneficiary\b',
        caseSensitive: false,
      ).hasMatch(text.substring(credit.start));
      if (debit != null && debit.start < credit.start && beneficiaryCredit) {
        return TransactionType.debit;
      }
      return TransactionType.credit;
    }

    if (debit != null ||
        _moneySent.hasMatch(text) ||
        _processedCardPurchase.hasMatch(text)) {
      return TransactionType.debit;
    }
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

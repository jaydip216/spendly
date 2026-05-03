import '../../core/models/expense.dart';

class ParsedTransaction {
  ParsedTransaction({
    required this.amount,
    required this.sender,
    required this.timestamp,
    required this.transactionType,
    this.merchant,
    this.upiId,
    this.cardLastFour,
    this.bankName,
  });

  final double amount;
  final String sender;
  final DateTime timestamp;
  final TransactionType transactionType;
  final String? merchant;
  final String? upiId;
  final String? cardLastFour;
  final String? bankName;
}

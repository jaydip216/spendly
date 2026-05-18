import 'package:isar/isar.dart';

part 'expense.g.dart';

enum TransactionType { debit, credit }

enum ExpenseSource { sms, manual }

@collection
class Expense {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  DateTime timestamp = DateTime.now();

  @Index(type: IndexType.value)
  double amount = 0;

  @Index(type: IndexType.hash)
  String merchant = '';

  @Index(type: IndexType.hash)
  String sender = '';

  String rawSms = '';
  String currency = 'INR';
  String? upiId;
  String? cardLastFour;
  String? bankName;

  @enumerated
  TransactionType transactionType = TransactionType.debit;

  @enumerated
  ExpenseSource source = ExpenseSource.sms;

  DateTime createdAt = DateTime.now();

  @Index(type: IndexType.hash)
  String dedupeKey = '';

  String? notes;
}

// ignore_for_file: avoid_print

import 'package:spendly/services/parser/transaction_parser.dart';

void main() {
  final parser = TransactionParser();
  const sms = 'Rs.60.00 spent on your SBI Credit Card ending with 4815 at MrSHIVANNA on 03-05-26 via UPI (Ref No. 383676481236). Trxn. not done by you? Report at https://sbicard.com/Dispute';

  final parsed = parser.parse(
    sender: 'SBICRD',
    body: sms,
    timestamp: DateTime(2026, 5, 3, 12, 0),
  );

  if (parsed == null) {
    print('PARSE_RESULT=null');
    return;
  }

  print('amount=${parsed.amount}');
  print('merchant=${parsed.merchant}');
  print('cardLastFour=${parsed.cardLastFour}');
  print('upiId=${parsed.upiId}');
  print('bankName=${parsed.bankName}');
  print('type=${parsed.transactionType.name}');
}

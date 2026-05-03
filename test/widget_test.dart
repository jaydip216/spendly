import 'package:flutter_test/flutter_test.dart';

import 'package:spendly/core/models/expense.dart';
import 'package:spendly/services/parser/transaction_parser.dart';

void main() {
  group('TransactionParser', () {
    final parser = TransactionParser();

    test('extracts amount, merchant and card details from card debit SMS', () {
      final parsed = parser.parse(
        sender: 'HDFCBK',
        body:
            'Rs.1,250.00 debited from card xx1234 at AMAZON on 03-05-26. Avl bal Rs.25,000',
        timestamp: DateTime(2026, 5, 3, 10, 45),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1250.00);
      expect(parsed.cardLastFour, '1234');
      expect(parsed.merchant, contains('AMAZON'));
      expect(parsed.transactionType, TransactionType.debit);
    });

    test('extracts UPI id and sender from UPI SMS', () {
      final parsed = parser.parse(
        sender: 'ICICIB',
        body:
            'INR 499.50 is debited from A/c XX0188 to pay abc.store@okhdfcbank UPI Ref 123456',
        timestamp: DateTime(2026, 5, 3, 11, 10),
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 499.50);
      expect(parsed.upiId, 'abc.store@okhdfcbank');
      expect(parsed.sender, 'ICICIB');
      expect(parsed.transactionType, TransactionType.debit);
    });

    test('ignores non-transaction SMS', () {
      final parsed = parser.parse(
        sender: 'AD-SHOP',
        body: 'Limited period sale starts today. Buy now and save big.',
        timestamp: DateTime(2026, 5, 3),
      );

      expect(parsed, isNull);
    });
  });
}

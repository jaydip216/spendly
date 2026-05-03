import 'package:flutter_test/flutter_test.dart';

import 'package:spendly/core/models/expense.dart';
import 'package:spendly/services/parser/transaction_parser.dart';
import 'package:spendly/services/sms/sms_ingestion_service.dart';

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

    test('ignores statement sent messages even when amount exists', () {
      final parsed = parser.parse(
        sender: 'HDFCBK',
        body:
            'Your monthly statement for card XX1234 has been sent. Total due INR 1250.00 by 10 May.',
        timestamp: DateTime(2026, 5, 3),
      );

      expect(parsed, isNull);
    });

    test('ignores OTP sent messages with amount-like text', () {
      final parsed = parser.parse(
        sender: 'ICICIB',
        body:
            'OTP sent to mobile for adding beneficiary. Do not share. Ref amount Rs.5000',
        timestamp: DateTime(2026, 5, 3),
      );

      expect(parsed, isNull);
    });

    test('ignores UPI collect request messages', () {
      final parsed = parser.parse(
        sender: 'UPI',
        body:
            'UPI collect request of Rs.500 from abc@okicici pending approval.',
        timestamp: DateTime(2026, 5, 3),
      );

      expect(parsed, isNull);
    });
  });

  group('SMS dedupe key', () {
    test('uses consistent normalization when merchant is missing', () {
      final timestamp = DateTime(2026, 5, 3, 10, 15, 33);

      final keyWithNullMerchant = buildSmsDedupeKey(
        amount: 499.5,
        sender: 'icicib',
        timestamp: timestamp,
        merchant: null,
      );

      final keyWithEmptyMerchant = buildSmsDedupeKey(
        amount: 499.5,
        sender: 'ICICIB',
        timestamp: timestamp,
        merchant: '   ',
      );

      expect(keyWithNullMerchant, keyWithEmptyMerchant);
      expect(keyWithNullMerchant, contains('|UNKNOWN|'));
    });
  });
}

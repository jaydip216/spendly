import 'misclassification_cases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/core/models/expense.dart';
import 'package:spendly/services/parser/parsed_transaction.dart';
import 'package:spendly/services/parser/transaction_parser.dart';

void main() {
  final parser = TransactionParser();
  final timestamp = DateTime(2026, 5, 3, 10, 0);

  ParsedTransaction? parse(String sender, String body) {
    return parser.parse(sender: sender, body: body, timestamp: timestamp);
  }

  group('OTP and credit regression cases', () {
    for (final body in rejectedMessages) {
      test('rejects $body', () => expect(parse('HDFCBK', body), isNull));
    }
    for (final body in acceptedMessages) {
      test('accepts $body', () {
        final result = parse('HDFCBK', body);
        expect(result, isNotNull);
        expect(result!.amount, 500);
      });
    }
  });

  group('classification', () {
    test('debit with CR balance suffix is parsed as debit, not credit', () {
      final parsed = parse(
        'SBIINB',
        'Rs 500.00 debited from A/c XX1234 to shop@oksbi on 04-05-26. '
            'Avl Bal Rs 5,000.00 CR.',
      );
      expect(parsed, isNotNull);
      expect(parsed!.transactionType, TransactionType.debit);
      expect(parsed.amount, 500.0);
    });

    test('message with both debited and credited is treated as debit', () {
      final parsed = parse(
        'HDFCBK',
        'Rs 250 debited from A/c XX1111 and credited to beneficiary '
            'john@okhdfc. Ref 998877.',
      );
      expect(parsed, isNotNull);
      expect(parsed!.transactionType, TransactionType.debit);
    });

    test('pure credit message is dropped', () {
      final parsed = parse(
        'HDFCBK',
        'INR 75,000.00 credited to your account XX8899 on 01-05-26 '
            'by ACME TECH PVT LTD.',
      );
      expect(parsed, isNull);
    });

    test('refund message is dropped', () {
      final parsed = parse(
        'AXISBK',
        'Rs.450.00 refund received and credited to card xx8877 for order.',
      );
      expect(parsed, isNull);
    });

    test(
      'ambiguous message with amount but no transaction keyword is dropped',
      () {
        final parsed = parse(
          'VM-STORE',
          'Your order worth Rs.999 at MegaStore will arrive tomorrow.',
        );
        expect(parsed, isNull);
      },
    );
  });

  group('promotional filtering', () {
    test('percent-off promo with card context is dropped', () {
      final parsed = parse(
        'VM-AMAZON',
        'Get 50% off up to Rs.100 on your card at Amazon this weekend!',
      );
      expect(parsed, isNull);
    });

    test('offer message is dropped', () {
      final parsed = parse(
        'VK-SHOPPY',
        'Get Rs.500 cashback on shopping above Rs.2999. '
            'Offer valid till midnight. Tap now!',
      );
      expect(parsed, isNull);
    });

    test('EMI due reminder is dropped', () {
      final parsed = parse(
        'HDFCBK',
        'EMI of Rs.4,500 for your loan account XX8899 is due on 10-05-26.',
      );
      expect(parsed, isNull);
    });

    test('pre-approved loan solicitation is dropped', () {
      final parsed = parse(
        'VM-BAJAJF',
        'You are eligible for a pre-approved loan of Rs.2,00,000. Apply now.',
      );
      expect(parsed, isNull);
    });

    test('genuine debit mentioning cashback still parses', () {
      final parsed = parse(
        'PAYTM',
        'Rs.120 paid to CAFE COFFEE DAY via Paytm UPI. '
            'Earn 5% cashback on your next order. Ref 55667788.',
      );
      expect(parsed, isNotNull);
      expect(parsed!.amount, 120.0);
    });
  });

  group('genuine debits still parse', () {
    test('spent on card at merchant', () {
      final parsed = parse(
        'SBICRD',
        'Rs.60.00 spent on your SBI Credit Card ending with 4815 '
            'at MrSHIVANNA on 03-05-26 via UPI (Ref No. 383676481236).',
      );
      expect(parsed, isNotNull);
      expect(parsed!.amount, 60.0);
      expect(parsed.cardLastFour, '4815');
    });

    test('ATM withdrawal parses via withdrawn keyword', () {
      final parsed = parse(
        'SBIINB',
        'Rs.500.00 withdrawn from A/C XX5544 on 03-05-26 at SBI ATM '
            'KORAMANGALA. Avl Bal Rs.8,950.00',
      );
      expect(parsed, isNotNull);
      expect(parsed!.amount, 500.0);
    });

    test('sent via UPI parses', () {
      final parsed = parse(
        'HDFCBK',
        'INR 155.00 sent from A/c XX1001 to merchant.pay@okaxis via UPI '
            'on 03/05/2026. Ref 10998877.',
      );
      expect(parsed, isNotNull);
      expect(parsed!.upiId, 'merchant.pay@okaxis');
    });

    test('transaction processed phrasing parses', () {
      final parsed = parse(
        'ICICIB',
        'A transaction of INR 3,000.00 on ICICI Bank Card xx7421 '
            'at INDIAN OIL has been processed.',
      );
      expect(parsed, isNotNull);
      expect(parsed!.amount, 3000.0);
    });
  });

  group('non-expense hard rejects', () {
    test('OTP message is dropped', () {
      final parsed = parse(
        'ICICIB',
        'OTP sent to mobile for adding beneficiary. Do not share. '
            'Ref amount Rs.5000',
      );
      expect(parsed, isNull);
    });

    test('statement message is dropped', () {
      final parsed = parse(
        'HDFCBK',
        'Your monthly statement for card XX1234 has been sent. '
            'Total due INR 1250.00 by 10 May.',
      );
      expect(parsed, isNull);
    });

    test('UPI collect request is dropped', () {
      final parsed = parse(
        'UPI',
        'UPI collect request of Rs.500 from abc@okicici pending approval.',
      );
      expect(parsed, isNull);
    });
  });
}

// ignore_for_file: avoid_print

import 'package:spendly/services/parser/transaction_parser.dart';

class SmsCase {
  const SmsCase({
    required this.name,
    required this.sender,
    required this.body,
    required this.shouldParse,
    this.amount,
    this.merchantContains,
    this.cardLast4,
    this.upiId,
  });

  final String name;
  final String sender;
  final String body;
  final bool shouldParse;
  final double? amount;
  final String? merchantContains;
  final String? cardLast4;
  final String? upiId;
}

void main() {
  final parser = TransactionParser();

  final cases = <SmsCase>[
    const SmsCase(
      name: 'SBI card spent UPI merchant',
      sender: 'SBICRD',
      body:
          'Rs.60.00 spent on your SBI Credit Card ending with 4815 at MrSHIVANNA on 03-05-26 via UPI (Ref No. 383676481236).',
      shouldParse: true,
      amount: 60.00,
      merchantContains: 'MrSHIVANNA',
      cardLast4: '4815',
    ),
    const SmsCase(
      name: 'HDFC debit card POS',
      sender: 'HDFCBK',
      body:
          'Rs 1,299.00 debited from HDFC Bank Card XX4321 at DMART BELLANDUR on 03-05-26. Avl bal INR 23,000.',
      shouldParse: true,
      amount: 1299.00,
      merchantContains: 'DMART',
      cardLast4: '4321',
    ),
    const SmsCase(
      name: 'ICICI UPI to VPA',
      sender: 'ICICIB',
      body:
          'INR 499.50 is debited from A/c XX0188 to abc.store@okhdfcbank on 03-05-26. UPI Ref 123456789.',
      shouldParse: true,
      amount: 499.50,
      upiId: 'abc.store@okhdfcbank',
    ),
    const SmsCase(
      name: 'Axis ecom transaction',
      sender: 'AXISBK',
      body:
          'INR 2,199.00 spent on Axis Bank Credit Card xx8877 at AMAZON PAY INDIA on 03-05-26.',
      shouldParse: true,
      amount: 2199.00,
      merchantContains: 'AMAZON',
      cardLast4: '8877',
    ),
    const SmsCase(
      name: 'Kotak UPI paid',
      sender: 'KKBKBN',
      body:
          'Rs.350 paid via UPI from A/c XX2244 to john@okicici Ref no 665544332211.',
      shouldParse: true,
      amount: 350.0,
      upiId: 'john@okicici',
      cardLast4: '2244',
    ),
    const SmsCase(
      name: 'PhonePe paid merchant',
      sender: 'PHONEPE',
      body:
          'You have paid Rs.89 to ZOMATO using UPI from HDFC Bank A/c XX1122. UPI Ref: 33221100.',
      shouldParse: true,
      amount: 89.0,
      merchantContains: 'ZOMATO',
      cardLast4: '1122',
    ),
    const SmsCase(
      name: 'Google Pay paid',
      sender: 'GPAY',
      body:
          'Paid ₹245.00 to Swiggy Instamart from your SBI Bank account ending 9034. UPI transaction id 100200300.',
      shouldParse: true,
      amount: 245.0,
      merchantContains: 'Swiggy',
      cardLast4: '9034',
    ),
    const SmsCase(
      name: 'SBI ATM withdrawal',
      sender: 'SBIINB',
      body:
          'Rs.500.00 withdrawn from A/C XX5544 on 03-05-26 at SBI ATM KORAMANGALA. Avl Bal Rs.8,950.00',
      shouldParse: true,
      amount: 500.0,
      merchantContains: 'SBI ATM',
      cardLast4: '5544',
    ),
    const SmsCase(
      name: 'Yes Bank card purchase',
      sender: 'YESBNK',
      body:
          'INR 1,050.75 spent using YES BANK Card XX6677 at RELIANCE FRESH on 03-05-26. Txn ID 987654.',
      shouldParse: true,
      amount: 1050.75,
      merchantContains: 'RELIANCE',
      cardLast4: '6677',
    ),
    const SmsCase(
      name: 'Federal UPI merchant',
      sender: 'FEDBNK',
      body:
          'Rs.730 debited from A/c XX0099 towards UPI payment to BIGBASKET@hdfcbank. Ref 223311.',
      shouldParse: true,
      amount: 730.0,
      upiId: 'BIGBASKET@hdfcbank',
      cardLast4: '0099',
    ),
    const SmsCase(
      name: 'ICICI fuel transaction',
      sender: 'ICICIB',
      body:
          'A transaction of INR 3,000.00 on ICICI Bank Card xx7421 at INDIAN OIL has been processed.',
      shouldParse: true,
      amount: 3000.0,
      merchantContains: 'INDIAN OIL',
      cardLast4: '7421',
    ),
    const SmsCase(
      name: 'HDFC sent via UPI',
      sender: 'HDFCBK',
      body:
          'INR 155.00 sent from A/c XX1001 to merchant.pay@okaxis via UPI on 03/05/2026. Ref 10998877.',
      shouldParse: true,
      amount: 155.0,
      upiId: 'merchant.pay@okaxis',
      cardLast4: '1001',
    ),
    const SmsCase(
      name: 'Salary credited (should ignore)',
      sender: 'HDFCBK',
      body:
          'INR 75,000.00 credited to your salary account XX8899 on 01-05-26 by ACME TECH PVT LTD.',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'Refund credited (should ignore)',
      sender: 'AXISBK',
      body:
          'Rs.450.00 refund received and credited to card xx8877 for AMAZON order on 03-05-26.',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'Promotional message (should ignore)',
      sender: 'VK-SHOPPY',
      body:
          'Get Rs.500 cashback on shopping above Rs.2999. Offer valid till midnight. Tap now!',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'Statement sent with due amount (should ignore)',
      sender: 'HDFCBK',
      body:
          'Your monthly statement for card XX1234 has been sent. Total due INR 1250.00 by 10 May.',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'OTP sent with amount text (should ignore)',
      sender: 'ICICIB',
      body:
          'OTP sent to mobile for adding beneficiary. Do not share. Ref amount Rs.5000',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'UPI collect request (should ignore)',
      sender: 'UPI',
      body: 'UPI collect request of Rs.500 from abc@okicici pending approval.',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'Debit with CR balance suffix (must parse as debit)',
      sender: 'SBIINB',
      body:
          'Rs 500.00 debited from A/c XX1234 to grocery.mart@oksbi on 04-05-26. Avl Bal Rs 5,000.00 CR.',
      shouldParse: true,
      amount: 500.0,
      upiId: 'grocery.mart@oksbi',
    ),
    const SmsCase(
      name: 'Promo percent-off on card (should ignore)',
      sender: 'VM-AMAZON',
      body:
          'Get 50% off up to Rs.100 on your card at Amazon this weekend. Shop now!',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'EMI due reminder (should ignore)',
      sender: 'HDFCBK',
      body:
          'EMI of Rs.4,500 for your HDFC loan account XX8899 is due on 10-05-26. Please maintain balance.',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'Pre-approved loan offer (should ignore)',
      sender: 'VM-BAJAJF',
      body:
          'You are eligible for a pre-approved loan of Rs.2,00,000. Apply now via the app.',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'Ambiguous amount mention, no txn keyword (should ignore)',
      sender: 'VM-STORE',
      body: 'Your order worth Rs.999 at MegaStore will arrive tomorrow.',
      shouldParse: false,
    ),
    const SmsCase(
      name: 'Genuine debit mentioning cashback (must parse)',
      sender: 'PAYTM',
      body:
          'Rs.120 paid to CAFE COFFEE DAY via Paytm UPI. Earn 5% cashback on your next order. Ref 55667788.',
      shouldParse: true,
      amount: 120.0,
      merchantContains: 'CAFE COFFEE DAY',
    ),
  ];

  var passed = 0;
  for (final c in cases) {
    final parsed = parser.parse(
      sender: c.sender,
      body: c.body,
      timestamp: DateTime(2026, 5, 3, 10, 0),
    );

    final ok = _validate(c, parsed);
    if (ok) {
      passed++;
      print('PASS: ${c.name}');
    } else {
      print('FAIL: ${c.name}');
      print('  sender=${c.sender}');
      print('  body=${c.body}');
      if (parsed == null) {
        print('  parsed=null');
      } else {
        print('  parsed.amount=${parsed.amount}');
        print('  parsed.merchant=${parsed.merchant}');
        print('  parsed.cardLast4=${parsed.cardLastFour}');
        print('  parsed.upiId=${parsed.upiId}');
        print('  parsed.bankName=${parsed.bankName}');
      }
    }
  }

  print('----');
  print('Summary: $passed/${cases.length} passed');
}

bool _validate(SmsCase c, dynamic parsed) {
  if (!c.shouldParse) {
    return parsed == null;
  }

  if (parsed == null) {
    return false;
  }

  if (c.amount != null && (parsed.amount - c.amount!).abs() > 0.01) {
    return false;
  }

  if (c.cardLast4 != null && parsed.cardLastFour != c.cardLast4) {
    return false;
  }

  if (c.upiId != null &&
      (parsed.upiId == null ||
          parsed.upiId.toLowerCase() != c.upiId!.toLowerCase())) {
    return false;
  }

  if (c.merchantContains != null) {
    final merchant = parsed.merchant ?? '';
    if (!merchant.toLowerCase().contains(c.merchantContains!.toLowerCase())) {
      return false;
    }
  }

  return true;
}

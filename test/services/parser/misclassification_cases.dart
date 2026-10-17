// Synthetic regression messages; never include real OTPs or account details.
const rejectedMessages = <String>[
  '123456 is your one-time passcode for purchase of INR 999 on card XX1234.',
  'Verification code 123456 sent for transaction of Rs.500 at SHOP.',
  'O.T.P. 123456 for purchase of Rs.999. Do not share.',
  'OTP123456 sent for transaction of INR 500.',
  'O\u200bTP sent for purchase of INR 500.',
  'Rs.500 credited to your account. Sender has sent money via UPI.',
  'Rs.500 credited to your account for purchase at SHOP.',
  'INR 500 received from John who paid via UPI.',
  'Rs.500 refund credited for amount debited on 01-05-26.',
  'Rs.500 debited earlier has been reversed to your account.',
  'Your transaction of INR 500 on card XX1234 at SHOP was declined.',
  'Your account will be debited INR 500 tomorrow.',
  'INR 500 has not been debited from your account.',
  'A transaction of INR 500 on card XX1234 at SHOP is pending approval.',
  'Purchase of INR 500 requested on your card.',
  'INR 500 credited to your account. Avl Bal Rs.100.50 DR.',
  'INR 500 credited to your account after payer account was debited.',
];

const acceptedMessages = <String>[
  'INR 500 spent on your Credit Card XX1234 at SHOP.',
  'Rs.500 debited from A/c XX1234. Avl Bal Rs.100.50 CR.',
  'Rs.500 debited from A/c XX1234 and credited to beneficiary John.',
  'You have paid Rs.500 to SHOP via UPI.',
  'INR 500 sent from A/c XX1234 to shop@okaxis via UPI.',
  'Sent Rs.500 to SHOP via UPI.',
  'A transaction of INR 500 on Bank Card XX1234 at SHOP has been processed.',
];

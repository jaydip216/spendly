import '../core/models/expense.dart';
import 'format.dart';

/// Display-only derivations shared by the rows, the detail sheet and the
/// Insights breakdowns. Nothing here is persisted — the fields it reads
/// (`upiId`, `cardLastFour`, `bankName`, `source`) are what the parser
/// already extracts.
extension ExpensePresentation on Expense {
  String get displayMerchant =>
      merchant.trim().isEmpty ? 'Unknown merchant' : merchant.trim();

  String get displayCategory => category.isEmpty ? 'Other' : category;

  String get initial => initialOf(displayMerchant);

  /// How the money left the account, as far as the SMS revealed.
  String get paymentMethod {
    if (source == ExpenseSource.manual) return 'Manual';
    if (upiId != null && upiId!.isNotEmpty) return 'UPI';
    if (cardLastFour != null && cardLastFour!.isNotEmpty) return 'Card';
    return 'Bank';
  }

  /// "HDFC •4821" when both are known, otherwise whichever half exists.
  String? get accountLabel {
    final bank = bankName?.trim();
    final card = cardLastFour?.trim();
    if (bank != null && bank.isNotEmpty && card != null && card.isNotEmpty) {
      return '$bank •$card';
    }
    if (bank != null && bank.isNotEmpty) return bank;
    if (card != null && card.isNotEmpty) return '•$card';
    return null;
  }

  /// The grey line under the merchant: category, account, date.
  String subtitleLine({bool withDate = true}) {
    final parts = <String>[displayCategory];
    final account = accountLabel;
    if (account != null) parts.add(account);
    if (withDate) parts.add(dayMonthYear.format(timestamp));
    return parts.join(' · ');
  }
}

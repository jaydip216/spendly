import 'package:intl/intl.dart';

final NumberFormat _whole = NumberFormat.decimalPattern('en_IN')
  ..maximumFractionDigits = 0;
final NumberFormat _precise = NumberFormat('#,##,##0.00', 'en_IN');

/// Rupee figure without the symbol — the ₹ is usually a separate, lighter
/// glyph in the layout, so callers place it themselves.
String rupees(double amount, {bool decimals = false}) =>
    decimals ? _precise.format(amount) : _whole.format(amount.round());

/// Rupee figure with the symbol attached, for inline prose and buttons.
String rupeesWithSymbol(double amount, {bool decimals = false}) =>
    '₹${rupees(amount, decimals: decimals)}';

/// Short form for axis labels: ₹38k, ₹1.2L.
String rupeesShort(double amount) {
  final value = amount.abs();
  if (value >= 10000000) return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
  if (value >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
  if (value >= 1000) return '₹${(amount / 1000).round()}k';
  return '₹${amount.round()}';
}

final DateFormat monthYear = DateFormat('MMMM yyyy');
final DateFormat monthShort = DateFormat('MMM');
final DateFormat monthShortYear = DateFormat('MMM yyyy');
final DateFormat dayMonth = DateFormat('d MMMM');
final DateFormat dayMonthYear = DateFormat('d MMM yyyy');
final DateFormat dayMonthTime = DateFormat('d MMM, h:mm a');
final DateFormat fullTimestamp = DateFormat('d MMM yyyy, h:mm a');
final DateFormat clockTime = DateFormat('h:mm a');

/// "Today" / "Yesterday" / "6 August" / "6 Aug 2025" — the sticky headers
/// above each day's spends.
String dayHeading(DateTime day, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final target = _dateOnly(day);
  final difference = today.difference(target).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (target.year == today.year) return dayMonth.format(target);
  return dayMonthYear.format(target);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// First letter of a merchant, for the row avatar.
String initialOf(String merchant) {
  for (final rune in merchant.trim().runes) {
    final character = String.fromCharCode(rune);
    if (RegExp(r'[A-Za-z0-9]').hasMatch(character)) {
      return character.toUpperCase();
    }
  }
  return '?';
}

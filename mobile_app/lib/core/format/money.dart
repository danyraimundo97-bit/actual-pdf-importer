import 'dart:math';

import 'package:intl/intl.dart';

final NumberFormat _formatter = NumberFormat.currency(locale: 'pt_PT', symbol: '€', decimalDigits: 2);

/// Formats integer cents as "−42,37 €" / "+42,37 €" — the sign is always
/// explicit (never colour alone), using a true minus sign rather than a
/// hyphen for outflows.
String formatCents(int cents) {
  final formatted = _formatter.format(cents.abs() / 100);
  return cents < 0 ? '−$formatted' : '+$formatted';
}

/// Formats a level, not a movement: a balance or what's left in a category.
/// Only a minus shows; a plus on "what you have" reads as a gain.
String formatBalance(int cents) {
  final formatted = _formatter.format(cents.abs() / 100);
  return cents < 0 ? '−$formatted' : formatted;
}

/// "4,50", "4.50", "1.234,56", "1,234.56", "12" → cents; null if it isn't
/// a positive amount. The sign comes from the expense/income toggle, so a
/// typed minus is ignored.
int? parseAmountInput(String input) {
  var text = input.trim().replaceAll(RegExp(r'[\s€+\-−]'), '');
  if (text.isEmpty) return null;
  final lastComma = text.lastIndexOf(',');
  final lastDot = text.lastIndexOf('.');
  // Whichever separator comes last is the decimal one, if it has 1-2
  // digits after it; the other is a thousands separator.
  final decimalAt = max(lastComma, lastDot);
  String whole = text;
  String fraction = '';
  if (decimalAt >= 0 && text.length - decimalAt - 1 <= 2) {
    whole = text.substring(0, decimalAt);
    fraction = text.substring(decimalAt + 1);
  }
  // Separators left in the whole part must group thousands: "1.234", not "4,5".
  if (whole.contains(RegExp(r'[.,]')) && !RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(whole)) return null;
  whole = whole.replaceAll(RegExp(r'[.,]'), '');
  if (!RegExp(r'^\d*$').hasMatch(whole) || !RegExp(r'^\d{0,2}$').hasMatch(fraction)) return null;
  if (whole.isEmpty && fraction.isEmpty) return null;
  final cents = int.parse(whole.isEmpty ? '0' : whole) * 100 + int.parse(fraction.padRight(2, '0'));
  return cents > 0 ? cents : null;
}

/// Like [parseAmountInput], but a leading minus makes it negative and an
/// empty field or a zero is 0. Null when it isn't an amount.
int? parseSignedAmountInput(String input) {
  final text = input.trim();
  if (text.isEmpty || RegExp(r'^[-−]?0+([.,]0{1,2})?$').hasMatch(text)) return 0;
  final negative = text.startsWith('-') || text.startsWith('−');
  final cents = parseAmountInput(negative ? text.substring(1) : text);
  if (cents == null) return null;
  return negative ? -cents : cents;
}

/// Cents as a field's starting text: "1234,56", "-40,00", or '' for 0.
String centsToInput(int cents) {
  if (cents == 0) return '';
  final abs = cents.abs();
  return '${cents < 0 ? '-' : ''}${abs ~/ 100},${(abs % 100).toString().padLeft(2, '0')}';
}
